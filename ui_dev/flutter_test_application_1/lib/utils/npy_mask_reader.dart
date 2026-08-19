import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/utils/mask_ops.dart';

/// A `.npy` file that cannot be used as SAM masks. [message] is written for
/// end users and shown verbatim in error dialogs.
class NpyFormatException implements Exception {
  const NpyFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Parsed `.npy` preamble: dtype descriptor, memory order, shape, and the file
/// offset where the raw data starts.
class NpyHeader {
  const NpyHeader({
    required this.descr,
    required this.fortranOrder,
    required this.shape,
    required this.dataOffset,
  });

  final String descr;
  final bool fortranOrder;
  final List<int> shape;
  final int dataOffset;
}

/// Result of reading a SAM mask file: per-instance tight-bbox masks plus the
/// mask grid dimensions, which must match the drone image before use.
class SamMaskParseResult {
  const SamMaskParseResult({
    required this.maskWidth,
    required this.maskHeight,
    required this.masks,
    required this.droppedEmptyCount,
  });

  final int maskWidth;
  final int maskHeight;
  final List<LeafMask> masks;

  /// Instances in the file that contained no set pixels.
  final int droppedEmptyCount;
}

/// Reads SAM segmentation masks saved with `np.save(masks.cpu().numpy())`.
///
/// Supported layouts: `(N, 1, H, W)` (SAM's `predict_torch` output), `(N, H, W)`
/// and a single `(H, W)` mask; dtype bool (`|b1`) or uint8 (`|u1`), C order.
abstract final class NpyMaskReader {
  static const int kMaxMasks = 512;

  static const List<int> _magic = [0x93, 0x4E, 0x55, 0x4D, 0x50, 0x59]; // \x93NUMPY

  /// Parses the npy preamble from the first bytes of a file. Pure so tests can
  /// feed handcrafted buffers. [prefixBytes] must contain the whole header;
  /// 64 KB from the start of the file is always enough (numpy pads the header
  /// to a small multiple of 64).
  static NpyHeader parseHeader(Uint8List prefixBytes) {
    if (prefixBytes.length < 10) {
      throw const NpyFormatException('This file is not a .npy array.');
    }
    for (var i = 0; i < _magic.length; i++) {
      if (prefixBytes[i] != _magic[i]) {
        throw const NpyFormatException('This file is not a .npy array.');
      }
    }
    final major = prefixBytes[6];
    final data = ByteData.sublistView(prefixBytes);
    int headerLength;
    int dictStart;
    if (major == 1) {
      headerLength = data.getUint16(8, Endian.little);
      dictStart = 10;
    } else if (major == 2 || major == 3) {
      if (prefixBytes.length < 12) {
        throw const NpyFormatException('This file is not a .npy array.');
      }
      headerLength = data.getUint32(8, Endian.little);
      dictStart = 12;
    } else {
      throw NpyFormatException('Unsupported .npy version $major.');
    }

    final dataOffset = dictStart + headerLength;
    if (prefixBytes.length < dataOffset) {
      throw const NpyFormatException('The .npy header is truncated.');
    }
    final dict = String.fromCharCodes(
      prefixBytes.sublist(dictStart, dataOffset),
    );

    final descrMatch = RegExp("'descr'\\s*:\\s*'([^']+)'").firstMatch(dict);
    final orderMatch =
        RegExp("'fortran_order'\\s*:\\s*(True|False)").firstMatch(dict);
    final shapeMatch = RegExp("'shape'\\s*:\\s*\\(([^)]*)\\)").firstMatch(dict);
    if (descrMatch == null || orderMatch == null || shapeMatch == null) {
      throw const NpyFormatException('Could not read the .npy header.');
    }

    final shape = <int>[
      for (final part in shapeMatch.group(1)!.split(','))
        if (part.trim().isNotEmpty) int.parse(part.trim()),
    ];

    return NpyHeader(
      descr: descrMatch.group(1)!,
      fortranOrder: orderMatch.group(1) == 'True',
      shape: shape,
      dataOffset: dataOffset,
    );
  }

  /// Reads and validates [filePath], returning one tight-bbox [LeafMask] per
  /// non-empty instance. Runs in a background isolate — the file can be
  /// hundreds of MB for a 20 MP drone frame.
  static Future<SamMaskParseResult> readSamMasks(String filePath) {
    return compute(_readSamMasksSync, filePath, debugLabel: 'NpyMaskReader');
  }

  static SamMaskParseResult _readSamMasksSync(String filePath) {
    final file = File(filePath);
    final raf = file.openSync();
    try {
      final prefix = raf.readSync(math.min(raf.lengthSync(), 65536));
      final header = parseHeader(prefix);

      if (header.fortranOrder) {
        throw const NpyFormatException(
          'The mask array is Fortran-ordered. Save it with numpy defaults '
          '(C order) and try again.',
        );
      }
      if (header.descr != '|b1' && header.descr != '|u1') {
        throw NpyFormatException(
          "Unsupported data type '${header.descr}'. Save the masks as bool "
          'or uint8.',
        );
      }

      final shape = header.shape;
      int count, height, width;
      if (shape.length == 4 && shape[1] == 1) {
        count = shape[0];
        height = shape[2];
        width = shape[3];
      } else if (shape.length == 3) {
        count = shape[0];
        height = shape[1];
        width = shape[2];
      } else if (shape.length == 2) {
        count = 1;
        height = shape[0];
        width = shape[1];
      } else {
        throw NpyFormatException(
          'Unexpected mask array shape (${shape.join(', ')}). Expected '
          '(N, 1, H, W), (N, H, W) or (H, W).',
        );
      }

      if (count <= 0 || height <= 0 || width <= 0) {
        throw const NpyFormatException('The mask array is empty.');
      }
      if (count > kMaxMasks) {
        throw NpyFormatException(
          'The file contains $count masks; the maximum supported is $kMaxMasks.',
        );
      }
      final frameSize = height * width;
      if (raf.lengthSync() != header.dataOffset + count * frameSize) {
        throw const NpyFormatException(
          'The file is truncated or is not a mask array.',
        );
      }

      final masks = <LeafMask>[];
      var droppedEmpty = 0;
      // One reusable full-frame buffer keeps peak memory at a single instance
      // (~21 MB for a 20 MP frame) regardless of N.
      final frame = Uint8List(frameSize);
      for (var i = 0; i < count; i++) {
        raf.setPositionSync(header.dataOffset + i * frameSize);
        var read = 0;
        while (read < frameSize) {
          final n = raf.readIntoSync(frame, read, frameSize);
          if (n <= 0) {
            throw const NpyFormatException(
              'The file is truncated or is not a mask array.',
            );
          }
          read += n;
        }

        var minX = width, minY = height, maxX = -1, maxY = -1;
        for (var y = 0; y < height; y++) {
          final row = y * width;
          for (var x = 0; x < width; x++) {
            if (frame[row + x] != 0) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        if (maxX < 0) {
          droppedEmpty++;
          continue;
        }

        final bboxWidth = maxX - minX + 1;
        final bboxHeight = maxY - minY + 1;
        final bytes = Uint8List(bboxWidth * bboxHeight);
        for (var y = 0; y < bboxHeight; y++) {
          final srcRow = (y + minY) * width + minX;
          final dstRow = y * bboxWidth;
          for (var x = 0; x < bboxWidth; x++) {
            // Normalize any nonzero value (bool 1 or uint8 255) to 1.
            bytes[dstRow + x] = frame[srcRow + x] != 0 ? 1 : 0;
          }
        }
        // SAM commonly leaves pinholes along veins and specular highlights,
        // and the odd speck of stray pixels. Reducing each instance to one
        // solid region here keeps the work off the UI isolate.
        masks.add(
          solidifyMask(
            LeafMask(
              left: minX,
              top: minY,
              width: bboxWidth,
              height: bboxHeight,
              bytes: bytes,
            ),
          ),
        );
      }

      return SamMaskParseResult(
        maskWidth: width,
        maskHeight: height,
        masks: masks,
        droppedEmptyCount: droppedEmpty,
      );
    } finally {
      raf.closeSync();
    }
  }
}
