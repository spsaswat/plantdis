/// Model paths and class labels shared by the single-image and batch pipelines.
///
/// These tables previously lived inline in `segment_page.dart`, which made the
/// headless batch pipeline impossible to build without copying them again.
library;

/// Output classes of `assets/models/plants_detector.tflite`, in index order.
const List<String> kSpeciesLabels = [
  'apple',
  'blueberry',
  'cherry',
  'corn',
  'grape',
  'orange',
  'peach',
  'pepper',
  'potato',
  'raspberry',
  'soybean',
  'squash',
  'strawberry',
  'tomato',
];

const String kSpeciesDetectorModelPath = 'assets/models/plants_detector.tflite';

/// Species that have a dedicated disease detector. Anything else falls back to
/// the generic `InferenceService`.
const Map<String, String> kSpeciesDiseaseModelPath = {
  'corn': 'assets/models/corn_disease_detector.tflite',
  'pepper': 'assets/models/pepper_disease_detector.tflite',
  'grape': 'assets/models/grape_disease_detector.tflite',
  'apple': 'assets/models/apple_disease_detector.tflite',
  'potato': 'assets/models/potato_disease_detector.tflite',
  'tomato': 'assets/models/tomato_disease_detector.tflite',
};

/// Output classes of each per-species disease detector, in index order.
const Map<String, List<String>> kDiseaseLabels = {
  'corn': [
    'Corn___Cercospora_leaf_spot_Gray_leaf_spot',
    'Corn___Common_rust',
    'Corn___healthy',
    'Corn___Northern_Leaf_Blight',
  ],
  'pepper': ['Pepper_bacterial_spot', 'Pepper_healthy'],
  'grape': [
    'Grape___Black_rot',
    'Grape___Esca_(Black_Measles)',
    'Grape___healthy',
    'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
  ],
  'apple': [
    'Apple___Apple_scab',
    'Apple___Black_rot',
    'Apple___Cedar_apple_rust',
    'Apple___healthy',
  ],
  'potato': ['Potato___Early_blight', 'Potato___healthy', 'Potato___Late_blight'],
  'tomato': [
    'Tomato___Bacterial_spot',
    'Tomato___Early_blight',
    'Tomato___Late_blight',
    'Tomato___Leaf_Mold',
    'Tomato___Septoria_leaf_spot',
    'Tomato___Spider_mites_Two_spotted_spider_mite',
    'Tomato___Target_Spot',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
    'Tomato___Tomato_mosaic_virus',
    'Tomato___healthy',
  ],
};

/// Whether a dedicated disease detector exists for [species].
bool isSupportedSpecies(String? species) {
  final s = species?.toLowerCase().trim();
  if (s == null || s.isEmpty) return false;
  return kSpeciesDiseaseModelPath.containsKey(s);
}

/// Whether a disease label denotes a healthy leaf.
bool isHealthyDiseaseLabel(String? diseaseName) {
  final d = diseaseName?.toLowerCase();
  if (d == null || d.isEmpty) return false;
  return d.contains('healthy');
}
