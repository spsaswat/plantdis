import 'package:collection/collection.dart';

/// Provides lightweight filtering to determine if user chat messages are related to plant diseases.
///
/// This guard acts as a pre-filter before messages are sent to more expensive LLM services,
/// preventing off-topic questions from being processed and ensuring the chat stays focused
/// on plant diseases, gardening, and related agricultural topics.
class ChatGuard {
  // A single, centralized reply for general out-of-scope messages
  static const String outOfScopeReply =
      "I'm sorry – I can only answer questions related to plant diseases, "
      "crop health, gardening or this application.";

  // More detailed response for clearly off-topic messages
  static const String clearlyOffTopicReply =
      "This appears to be unrelated to plants or agriculture. "
      "I'm specifically designed to help with plant diseases, crop health, "
      "and gardening questions. Please feel free to ask about those topics!";

  // Friendly reminder for borderline cases
  static const String borderlineReply =
      "I'm not sure if this is plant-related. For best results, "
      "please ask about plant diseases, gardening techniques, or crop management. "
      "How can I help with your plants today?";

  // Model-specific responses if needed
  static String getOutOfScopeReply(String modelId, double relevanceScore) {
    // For very low scores, use the clearly off-topic reply
    if (relevanceScore < 0.2) {
      return clearlyOffTopicReply;
    }

    // For borderline cases, use a gentler reminder
    if (relevanceScore < 0.4) {
      return borderlineReply;
    }

    // Model-specific customization if needed
    switch (modelId) {
      case 'gemini-1.5-pro':
        return outOfScopeReply;
      case 'claude-3-haiku':
        return outOfScopeReply;
      case 'gpt-3.5-turbo':
        return outOfScopeReply;
      default:
        return outOfScopeReply;
    }
  }

  // ------------- you can tune these keyword lists anytime -------------

  // Core plant-related keywords
  static final Set<String> _plantKeywords = {
    'plant',
    'plants',
    'leaf',
    'leaves',
    'root',
    'stem',
    'flower',
    'seed',
    'fruit',
    'tree',
    'shrub',
    'vine',
    'crop',
    'garden',
    'grow',
    'growing',
    'growth',
    'prune',
    'pruning',
    'water',
    'soil',
    'fertilizer',
    'fertilize',
    'compost',
    'mulch',
    'potting',
    'transplant',
    'propagate',
    'germinate',
    'seedling',
    'cutting',
    'clone',
    'agriculture',
    'farm',
    'field',
    'harvest',
    'yield',
    'organic',
    'sustainable',
    'heirloom',
    'native',
    'invasive',
    'weed',
  };

  // Disease-related keywords
  static final Set<String> _diseaseKeywords = {
    'disease',
    'blight',
    'rot',
    'wilt',
    'mildew',
    'powdery',
    'downy',
    'rust',
    'spot',
    'scorch',
    'canker',
    'gall',
    'mosaic',
    'yellowing',
    'chlorosis',
    'necrosis',
    'lesion',
    'fungus',
    'fungal',
    'bacterial',
    'virus',
    'viral',
    'pathogen',
    'infection',
    'infect',
    'symptom',
    'treatment',
    'control',
    'prevention',
    'pesticide',
    'fungicide',
    'spray',
    'copper',
    'sulfur',
    'resistant',
    'immunity',
    'susceptible',
    'diagnose',
    'diagnosis',
    'identify',
  };

  // Pest-related keywords
  static final Set<String> _pestKeywords = {
    'pest',
    'insect',
    'bug',
    'beetle',
    'aphid',
    'mite',
    'spider',
    'caterpillar',
    'larva',
    'grub',
    'worm',
    'thrip',
    'scale',
    'mealybug',
    'whitefly',
    'leafminer',
    'borer',
    'weevil',
    'maggot',
    'nematode',
    'snail',
    'slug',
    'rodent',
    'deer',
    'rabbit',
    'bird',
    'damage',
    'chew',
    'eat',
    'bite',
    'suck',
    'pierce',
  };

  // Common plant names (extend as needed)
  static final Set<String> _plantNames = {
    'tomato',
    'potato',
    'pepper',
    'eggplant',
    'cucumber',
    'squash',
    'melon',
    'watermelon',
    'corn',
    'bean',
    'pea',
    'lettuce',
    'spinach',
    'kale',
    'cabbage',
    'broccoli',
    'cauliflower',
    'onion',
    'garlic',
    'carrot',
    'beet',
    'radish',
    'turnip',
    'strawberry',
    'raspberry',
    'blueberry',
    'blackberry',
    'grape',
    'apple',
    'pear',
    'peach',
    'plum',
    'cherry',
    'citrus',
    'lemon',
    'lime',
    'orange',
    'grapefruit',
    'avocado',
    'mango',
    'banana',
    'pineapple',
    'coconut',
    'coffee',
    'tea',
    'cacao',
    'rice',
    'wheat',
    'barley',
    'oat',
    'rye',
    'sorghum',
    'millet',
    'soybean',
    'peanut',
    'sunflower',
    'cotton',
    'hemp',
    'flax',
    'rose',
    'tulip',
    'lily',
    'daisy',
    'sunflower',
    'marigold',
    'zinnia',
    'dahlia',
    'geranium',
    'orchid',
    'violet',
    'azalea',
    'rhododendron',
    'hydrangea',
    'oak',
    'maple',
    'pine',
    'spruce',
    'fir',
    'cedar',
    'juniper',
    'cypress',
    'palm',
    'fern',
    'moss',
    'lichen',
    'succulent',
    'cactus',
    'aloe',
    'bamboo',
    'grass',
  };

  // App-related terms that should also be allowed
  static final Set<String> _appKeywords = {
    'app',
    'camera',
    'photo',
    'picture',
    'image',
    'scan',
    'analyze',
    'detect',
    'model',
    'prediction',
    'accuracy',
    'result',
    'history',
    'save',
    'share',
    'report',
    'profile',
    'account',
    'login',
    'sign',
    'password',
    'email',
    'notification',
    'setting',
    'preference',
    'feedback',
    'suggestion',
    'help',
    'tutorial',
    'guide',
    'instruction',
    'information',
    'database',
    'offline',
    'update',
    'version',
    'bug',
    'issue',
    'error',
    'problem',
    'fix',
    'improve',
  };

  // Combine all relevant keyword sets for matching
  static final Set<String> _allRelevantKeywords = {
    ..._plantKeywords,
    ..._diseaseKeywords,
    ..._pestKeywords,
    ..._plantNames,
    ..._appKeywords,
  };

  /// Very lightweight filter: calculates relevance score and identifies potential off-topic messages
  ///
  /// Returns a relevance score from 0.0 (completely off-topic) to 1.0 (clearly relevant)
  static double getRelevanceScore(String text) {
    if (text.isEmpty) return 0.5; // Neutral for empty text

    // Normalize text: lowercase, remove punctuation, split into words
    final words =
        text
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z\s]'), ' ')
            .split(RegExp(r'\s+'))
            .where(
              (w) => w.isNotEmpty && w.length > 1,
            ) // Skip single-letter words
            .toList();

    if (words.isEmpty) return 0.5; // Neutral for text with no usable words

    // Count matching words
    int matchCount = 0;
    for (final word in words) {
      if (_allRelevantKeywords.contains(word)) {
        matchCount++;
      }
    }

    // Extra check for really short queries with 2-3 words
    if (words.length <= 3 && matchCount > 0) {
      return 0.7; // Assume relevant if short query has any matches
    }

    // Calculate relevance as proportion of matching words
    return matchCount / words.length;
  }

  /// Determine if a chat message is out of scope
  ///
  /// Returns true if the message appears to be off-topic
  static bool isOutOfScope(String text) {
    final score = getRelevanceScore(text);
    return score < 0.5; // Adjust threshold as needed
  }

  /// Get a debug string showing the relevance score (for development only)
  static String getDebugInfo(String text) {
    final score = getRelevanceScore(text);
    final words =
        text
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z\s]'), ' ')
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty && w.length > 1)
            .toList();

    int matchCount = 0;
    List<String> matchedWords = [];
    for (final word in words) {
      if (_allRelevantKeywords.contains(word)) {
        matchCount++;
        matchedWords.add(word);
      }
    }

    return "[Debug: Score ${score.toStringAsFixed(2)}, " +
        "Matched ${matchCount}/${words.length}: ${matchedWords.join(', ')}]";
  }
}
