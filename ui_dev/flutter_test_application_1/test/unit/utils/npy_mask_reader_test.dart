import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_test_application_1/utils/npy_mask_reader.dart';

/// Builds a `.npy` file exactly the way numpy does: magic, version, a padded
/// ASCII dict header, then raw C-order data.
Uint8List buildNpy({
  required String descr,
  required bool fortranOrder,
  required List<int> shape,
  required List<int> data,
  int version = 1,
}) {
  final shapeText =
      shape.length == 1 ? '${shape.first},' : shape.join(', ');
  var dict =
      "{'descr': '$descr', 'fortran_order': ${fortranOrder ? 'True' : 'False'}, "
      "'shape': ($shapeText), }";

  final prefixLength = version == 1 ? 10 : 12;
  // numpy pads the header with spaces so the data starts on a 64-byte boundary.
  while ((prefixLength + dict.length + 1) % 64 != 0) {
    dict += ' ';
  }
  dict += '\n';

  final out = BytesBuilder();
  out.add([0x93, 0x4E, 0x55, 0x4D, 0x50, 0x59, version, 0]);
  if (version == 1) {
    final len = ByteData(2)..setUint16(0, dict.length, Endian.little);
    out.add(len.buffer.asUint8List());
  } else {
    final len = ByteData(4)..setUint32(0, dict.length, Endian.little);
    out.add(len.buffer.asUint8List());
  }
  out.add(dict.codeUnits);
  out.add(data);
  return out.toBytes();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('npy_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<String> writeNpy(Uint8List bytes, [String name = 'mask.npy']) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// A 6x8 frame with a 2x3 block of set pixels at (x: 2..3, y: 1..3).
  List<int> frameWithBlock({int value = 1}) {
    final frame = List<int>.filled(6 * 8, 0);
    for (var y = 1; y <= 3; y++) {
      for (var x = 2; x <= 3; x++) {
        frame[y * 8 + x] = value;
      }
    }
    return frame;
  }

  group('parseHeader', () {
    test('reads a v1 header', () {
      final header = NpyMaskReader.parseHeader(
        buildNpy(
          descr: '|b1',
          fortranOrder: false,
          shape: [2, 1, 6, 8],
          data: List<int>.filled(2 * 6 * 8, 0),
        ),
      );

      expect(header.descr, '|b1');
      expect(header.fortranOrder, isFalse);
      expect(header.shape, [2, 1, 6, 8]);
      expect(header.dataOffset % 64, 0);
    });

    test('reads a v2 header, which uses a 4-byte length', () {
      final header = NpyMaskReader.parseHeader(
        buildNpy(
          descr: '|u1',
          fortranOrder: false,
          shape: [6, 8],
          data: List<int>.filled(6 * 8, 0),
          version: 2,
        ),
      );

      expect(header.descr, '|u1');
      expect(header.shape, [6, 8]);
    });

    test('rejects bytes that are not a npy array', () {
      expect(
        () => NpyMaskReader.parseHeader(
          Uint8List.fromList(List<int>.filled(64, 7)),
        ),
        throwsA(isA<NpyFormatException>()),
      );
    });
  });

  group('readSamMasks', () {
    test('reads SAM (N, 1, H, W) bool masks into tight bboxes', () async {
      final path = await writeNpy(
        buildNpy(
          descr: '|b1',
          fortranOrder: false,
          shape: [2, 1, 6, 8],
          data: [...frameWithBlock(), ...frameWithBlock()],
        ),
      );

      final result = await NpyMaskReader.readSamMasks(path);

      expect(result.maskWidth, 8);
      expect(result.maskHeight, 6);
      expect(result.masks, hasLength(2));
      expect(result.droppedEmptyCount, 0);

      final mask = result.masks.first;
      expect(mask.left, 2);
      expect(mask.top, 1);
      expect(mask.width, 2);
      expect(mask.height, 3);
      expect(mask.bytes.every((b) => b == 1), isTrue);
      expect(mask.containsImagePixel(2, 1), isTrue);
      expect(mask.containsImagePixel(4, 1), isFalse);
    });

    test('reads (N, H, W) and (H, W) layouts', () async {
      final threeD = await writeNpy(
        buildNpy(
          descr: '|b1',
          fortranOrder: false,
          shape: [1, 6, 8],
          data: frameWithBlock(),
        ),
        'three_d.npy',
      );
      final twoD = await writeNpy(
        buildNpy(
          descr: '|b1',
          fortranOrder: false,
          shape: [6, 8],
          data: frameWithBlock(),
        ),
        'two_d.npy',
      );

      expect((await NpyMaskReader.readSamMasks(threeD)).masks, hasLength(1));
      expect((await NpyMaskReader.readSamMasks(twoD)).masks, hasLength(1));
    });

    test('normalizes uint8 masks stored as 255 down to 1', () async {
      final path = await writeNpy(
        buildNpy(
          descr: '|u1',
          fortranOrder: false,
          shape: [1, 1, 6, 8],
          data: frameWithBlock(value: 255),
        ),
      );

      final mask = (await NpyMaskReader.readSamMasks(path)).masks.single;

      expect(mask.bytes.every((b) => b == 1), isTrue);
      expect(mask.pixelCount, 6);
    });

    test('skips all-zero instances and reports how many', () async {
      final path = await writeNpy(
        buildNpy(
          descr: '|b1',
          fortranOrder: false,
          shape: [3, 1, 6, 8],
          data: [
            ...frameWithBlock(),
            ...List<int>.filled(6 * 8, 0),
            ...frameWithBlock(),
          ],
        ),
      );

      final result = await NpyMaskReader.readSamMasks(path);

      expect(result.masks, hasLength(2));
      expect(result.droppedEmptyCount, 1);
    });

    test('rejects Fortran order', () async {
      final path = await writeNpy(
        buildNpy(
          descr: '|b1',
          fortranOrder: true,
          shape: [1, 6, 8],
          data: frameWithBlock(),
        ),
      );

      await expectLater(
        NpyMaskReader.readSamMasks(path),
        throwsA(isA<NpyFormatException>()),
      );
    });

    test('rejects a float dtype', () async {
      final path = await writeNpy(
        buildNpy(
          descr: '<f4',
          fortranOrder: false,
          shape: [1, 6, 8],
          data: List<int>.filled(6 * 8 * 4, 0),
        ),
      );

      await expectLater(
        NpyMaskReader.readSamMasks(path),
        throwsA(isA<NpyFormatException>()),
      );
    });

    test('rejects an unusable rank', () async {
      final path = await writeNpy(
        buildNpy(
          descr: '|b1',
          fortranOrder: false,
          shape: [2, 2, 1, 6, 8],
          data: List<int>.filled(2 * 2 * 6 * 8, 0),
        ),
      );

      await expectLater(
        NpyMaskReader.readSamMasks(path),
        throwsA(isA<NpyFormatException>()),
      );
    });

    test('rejects a truncated payload', () async {
      final full = buildNpy(
        descr: '|b1',
        fortranOrder: false,
        shape: [2, 1, 6, 8],
        data: [...frameWithBlock(), ...frameWithBlock()],
      );
      final path = await writeNpy(
        Uint8List.sublistView(full, 0, full.length - 10),
      );

      await expectLater(
        NpyMaskReader.readSamMasks(path),
        throwsA(isA<NpyFormatException>()),
      );
    });
  });
}
