import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_test_application_1/utils/analysis_utils.dart';
import 'package:flutter_test_application_1/utils/npy_mask_reader.dart';

import 'npy_mask_reader_test.dart' show buildNpy;

/// End-to-end check of the local half of the automatic drone flow: a SAM
/// `.npy` file on disk through to the masked leaf image the classifiers see.
///
/// This is where a coordinate-space mistake would show up — the mask is
/// indexed in full-image pixels, the crop is taken from the oriented decode,
/// and the two must line up exactly.
void main() {
  const width = 40;
  const height = 30;
  // A red leaf blob at x 8..15, y 5..12 on a blue background.
  const leafLeft = 8, leafTop = 5, leafRight = 15, leafBottom = 12;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sam_pipeline');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('a SAM mask file yields a masked leaf aligned to the source blob',
      () async {
    // The "drone photo": blue everywhere, red where the leaf is.
    final source = img.Image(width: width, height: height);
    img.fill(source, color: img.ColorRgb8(0, 0, 255));
    for (var y = leafTop; y <= leafBottom; y++) {
      for (var x = leafLeft; x <= leafRight; x++) {
        source.setPixelRgb(x, y, 255, 0, 0);
      }
    }
    final jpeg = Uint8List.fromList(img.encodeJpg(source, quality: 100));

    // The matching SAM mask, saved the way the notebook does: (N, 1, H, W).
    final frame = List<int>.filled(width * height, 0);
    for (var y = leafTop; y <= leafBottom; y++) {
      for (var x = leafLeft; x <= leafRight; x++) {
        frame[y * width + x] = 1;
      }
    }
    final maskPath = '${tempDir.path}${Platform.pathSeparator}mask.npy';
    await File(maskPath).writeAsBytes(
      buildNpy(
        descr: '|b1',
        fortranOrder: false,
        shape: [1, 1, height, width],
        data: frame,
      ),
      flush: true,
    );

    final parsed = await NpyMaskReader.readSamMasks(maskPath);

    // The mask grid must match the image, which is what the picker validates.
    expect(parsed.maskWidth, width);
    expect(parsed.maskHeight, height);

    final mask = parsed.masks.single;
    expect(mask.left, leafLeft);
    expect(mask.top, leafTop);
    expect(mask.width, leafRight - leafLeft + 1);
    expect(mask.height, leafBottom - leafTop + 1);

    // The label handed to the batch pipeline is the bbox in normalized space.
    final label = mask.toNormalizedRect(width, height);
    expect(label.x, closeTo(leafLeft / width, 1e-9));
    expect(label.y, closeTo(leafTop / height, 1e-9));

    // The leaf image is cropped from the oriented decode, exactly as the batch
    // runner does it.
    final oriented = decodeOriented(
      jpeg,
      expectedWidth: width,
      expectedHeight: height,
    );
    expect(oriented.dimensionsMatched, isTrue);

    final leaf = img.decodeJpg(maskedLeafJpeg(oriented.image, mask))!;

    expect(leaf.width, mask.width);
    expect(leaf.height, mask.height);
    // Every pixel is the leaf, so none of the blue background leaked in and
    // nothing was blacked out.
    for (var y = 0; y < leaf.height; y++) {
      for (var x = 0; x < leaf.width; x++) {
        final p = leaf.getPixel(x, y);
        expect(p.r, greaterThan(180), reason: 'lost the leaf at ($x, $y)');
        expect(p.b, lessThan(80), reason: 'background leaked at ($x, $y)');
      }
    }
  });

  test('pinholes in a SAM mask do not reach the masked leaf image', () async {
    final source = img.Image(width: width, height: height);
    img.fill(source, color: img.ColorRgb8(0, 0, 255));
    for (var y = leafTop; y <= leafBottom; y++) {
      for (var x = leafLeft; x <= leafRight; x++) {
        source.setPixelRgb(x, y, 255, 0, 0);
      }
    }

    // A mask over the blob with two dropouts, like SAM missing a vein or a
    // specular highlight.
    final frame = List<int>.filled(width * height, 0);
    for (var y = leafTop; y <= leafBottom; y++) {
      for (var x = leafLeft; x <= leafRight; x++) {
        frame[y * width + x] = 1;
      }
    }
    frame[(leafTop + 2) * width + (leafLeft + 3)] = 0;
    frame[(leafTop + 5) * width + (leafLeft + 4)] = 0;

    final maskPath = '${tempDir.path}${Platform.pathSeparator}holes.npy';
    await File(maskPath).writeAsBytes(
      buildNpy(
        descr: '|b1',
        fortranOrder: false,
        shape: [1, 1, height, width],
        data: frame,
      ),
      flush: true,
    );

    final mask = (await NpyMaskReader.readSamMasks(maskPath)).masks.single;

    // The reader seals them, so the leaf is one solid region.
    expect(mask.pixelCount, mask.width * mask.height);

    final oriented = decodeOriented(
      Uint8List.fromList(img.encodeJpg(source, quality: 100)),
    );
    final leaf = img.decodeJpg(maskedLeafJpeg(oriented.image, mask))!;

    // No black speckles anywhere inside the leaf image.
    for (var y = 0; y < leaf.height; y++) {
      for (var x = 0; x < leaf.width; x++) {
        expect(
          leaf.getPixel(x, y).r,
          greaterThan(180),
          reason: 'hole punched through the leaf at ($x, $y)',
        );
      }
    }
  });

  test('an off-centre mask blacks out the background inside its bbox',
      () async {
    final source = img.Image(width: width, height: height);
    img.fill(source, color: img.ColorRgb8(0, 0, 255));
    for (var y = leafTop; y <= leafBottom; y++) {
      for (var x = leafLeft; x <= leafRight; x++) {
        source.setPixelRgb(x, y, 255, 0, 0);
      }
    }

    // An L: the left half of the red blob, plus a thin arm along its top edge
    // reaching right. The arm widens the bbox past the solid part, so the
    // corner under it is background that must come out black.
    final frame = List<int>.filled(width * height, 0);
    for (var y = leafTop; y <= leafBottom; y++) {
      for (var x = leafLeft; x <= leafLeft + 3; x++) {
        frame[y * width + x] = 1;
      }
    }
    for (var x = leafLeft + 4; x <= leafRight; x++) {
      frame[leafTop * width + x] = 1;
    }

    final maskPath = '${tempDir.path}${Platform.pathSeparator}partial.npy';
    await File(maskPath).writeAsBytes(
      buildNpy(
        descr: '|u1',
        fortranOrder: false,
        shape: [1, height, width],
        data: frame,
      ),
      flush: true,
    );

    final mask = (await NpyMaskReader.readSamMasks(maskPath)).masks.single;
    final oriented = decodeOriented(
      Uint8List.fromList(img.encodeJpg(source, quality: 100)),
    );
    final leaf = img.decodeJpg(maskedLeafJpeg(oriented.image, mask))!;

    // The arm stretches the bbox across the whole blob.
    expect(leaf.width, leafRight - leafLeft + 1);
    // Masked pixels keep the leaf colour...
    expect(leaf.getPixel(0, 3).r, greaterThan(180));
    // ...while the corner under the arm is blacked out, not left blue. The
    // gap opens onto the bottom edge, so hole filling leaves it alone.
    final excluded = leaf.getPixel(5, 3);
    expect(excluded.r, lessThan(60));
    expect(excluded.b, lessThan(60));
  });
}
