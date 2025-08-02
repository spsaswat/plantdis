
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
    if (relevanceScore < 0.15) {
      return clearlyOffTopicReply;
    }

    // For borderline cases, use a gentler reminder
    if (relevanceScore < 0.35) {
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
    'roots',
    'stem',
    'stems',
    'flower',
    'flowers',
    'seed',
    'seeds',
    'fruit',
    'fruits',
    'tree',
    'trees',
    'shrub',
    'shrubs',
    'vine',
    'vines',
    'crop',
    'crops',
    'garden',
    'gardening',
    'grow',
    'growing',
    'growth',
    'prune',
    'pruning',
    'water',
    'watering',
    'soil',
    'fertilizer',
    'fertilizers',
    'fertilize',
    'compost',
    'mulch',
    'mulching',
    'potting',
    'transplant',
    'propagate',
    'germinate',
    'seedling',
    'seedlings',
    'cutting',
    'cuttings',
    'clone',
    'agriculture',
    'agricultural',
    'farm',
    'farming',
    'field',
    'fields',
    'harvest',
    'harvesting',
    'yield',
    'organic',
    'sustainable',
    'heirloom',
    'native',
    'invasive',
    'weed',
    'weeds',
  };

  // Disease-related keywords
  static final Set<String> _diseaseKeywords = {
    'disease',
    'diseases',
    'blight',
    'blights',
    'rot',
    'rots',
    'rotting',
    'wilt',
    'wilting',
    'mildew',
    'powdery',
    'downy',
    'rust',
    'rusts',
    'spot',
    'spots',
    'spotted',
    'spotting',
    'scorch',
    'scorching',
    'canker',
    'cankers',
    'gall',
    'galls',
    'mosaic',
    'mosaics',
    'yellowing',
    'chlorosis',
    'chlorotic',
    'necrosis',
    'necrotic',
    'lesion',
    'lesions',
    'fungus',
    'fungi',
    'fungal',
    'bacterial',
    'bacteria',
    'virus',
    'viruses',
    'viral',
    'pathogen',
    'pathogens',
    'infection',
    'infections',
    'infected',
    'infect',
    'infecting',
    'symptom',
    'symptoms',
    'treatment',
    'treatments',
    'treat',
    'treating',
    'control',
    'controlling',
    'prevention',
    'prevent',
    'preventing',
    'preventive',
    'pesticide',
    'pesticides',
    'fungicide',
    'fungicides',
    'spray',
    'spraying',
    'sprays',
    'copper',
    'sulfur',
    'sulphur',
    'resistant',
    'resistance',
    'immunity',
    'immune',
    'susceptible',
    'vulnerability',
    'vulnerable',
    'diagnose',
    'diagnosis',
    'diagnostic',
    'identify',
    'identification',
    'cure',
    'curing',
    'remedy',
    'remedies',
    'medicine',
    'medicinal',
    'blast',
  };

  // Pest-related keywords
  static final Set<String> _pestKeywords = {
    'pest',
    'pests',
    'insect',
    'insects',
    'bug',
    'bugs',
    'beetle',
    'beetles',
    'aphid',
    'aphids',
    'mite',
    'mites',
    'spider',
    'spiders',
    'caterpillar',
    'caterpillars',
    'larva',
    'larvae',
    'grub',
    'grubs',
    'worm',
    'worms',
    'thrip',
    'thrips',
    'scale',
    'scales',
    'mealybug',
    'mealybugs',
    'whitefly',
    'whiteflies',
    'leafminer',
    'leafminers',
    'borer',
    'borers',
    'weevil',
    'weevils',
    'maggot',
    'maggots',
    'nematode',
    'nematodes',
    'snail',
    'snails',
    'slug',
    'slugs',
    'rodent',
    'rodents',
    'deer',
    'rabbit',
    'rabbits',
    'bird',
    'birds',
    'damage',
    'damaged',
    'damaging',
    'chew',
    'chewing',
    'eat',
    'eating',
    'bite',
    'biting',
    'suck',
    'sucking',
    'pierce',
    'piercing',
    'attack',
    'attacking',
    'infestation',
    'infested',
  };

  // Common plant names (extend as needed)
  static final Set<String> _plantNames = {
    'tomato',
    'tomatoes',
    'potato',
    'potatoes',
    'pepper',
    'peppers',
    'eggplant',
    'eggplants',
    'cucumber',
    'cucumbers',
    'squash',
    'melon',
    'melons',
    'watermelon',
    'watermelons',
    'corn',
    'maize',
    'bean',
    'beans',
    'pea',
    'peas',
    'lettuce',
    'spinach',
    'kale',
    'rice',
    'cabbage',
    'broccoli',
    'cauliflower',
    'onion',
    'onions',
    'garlic',
    'carrot',
    'carrots',
    'beet',
    'beets',
    'radish',
    'radishes',
    'turnip',
    'turnips',
    'strawberry',
    'strawberries',
    'raspberry',
    'raspberries',
    'blueberry',
    'blueberries',
    'blackberry',
    'blackberries',
    'grape',
    'grapes',
    'apple',
    'apples',
    'pear',
    'pears',
    'peach',
    'peaches',
    'plum',
    'plums',
    'cherry',
    'cherries',
    'citrus',
    'lemon',
    'lemons',
    'lime',
    'limes',
    'orange',
    'oranges',
    'grapefruit',
    'avocado',
    'avocados',
    'mango',
    'mangoes',
    'banana',
    'bananas',
    'pineapple',
    'pineapples',
    'coconut',
    'coconuts',
    'coffee',
    'tea',
    'cacao',
    'wheat',
    'barley',
    'oat',
    'oats',
    'rye',
    'sorghum',
    'millet',
    'soybean',
    'soybeans',
    'peanut',
    'peanuts',
    'sunflower',
    'sunflowers',
    'cotton',
    'hemp',
    'flax',
    'rose',
    'roses',
    'tulip',
    'tulips',
    'lily',
    'lilies',
    'daisy',
    'daisies',
    'marigold',
    'marigolds',
    'zinnia',
    'zinnias',
    'dahlia',
    'dahlias',
    'geranium',
    'geraniums',
    'orchid',
    'orchids',
    'violet',
    'violets',
    'azalea',
    'azaleas',
    'rhododendron',
    'rhododendrons',
    'hydrangea',
    'hydrangeas',
    'oak',
    'maple',
    'pine',
    'spruce',
    'fir',
    'cedar',
    'juniper',
    'cypress',
    'palm',
    'palms',
    'fern',
    'ferns',
    'moss',
    'lichen',
    'succulent',
    'succulents',
    'cactus',
    'cacti',
    'aloe',
    'bamboo',
    'grass',
    'grasses',
  };

  // App-related terms that should also be allowed
  static final Set<String> _appKeywords = {
    'app',
    'application',
    'camera',
    'photo',
    'photos',
    'picture',
    'pictures',
    'image',
    'images',
    'scan',
    'scanning',
    'analyze',
    'analyzing',
    'detection',
    'detect',
    'detector',
    'model',
    'models',
    'ai',
    'machine',
    'learning',
    'prediction',
    'predictions',
    'accuracy',
    'result',
    'results',
    'history',
    'save',
    'saving',
    'share',
    'sharing',
    'report',
    'reports',
    'profile',
    'account',
    'login',
    'sign',
    'password',
    'email',
    'notification',
    'notifications',
    'setting',
    'settings',
    'preference',
    'preferences',
    'feedback',
    'suggestion',
    'suggestions',
    'help',
    'tutorial',
    'guide',
    'guides',
    'instruction',
    'instructions',
    'information',
    'database',
    'offline',
    'update',
    'updates',
    'version',
    'bug',
    'issue',
    'issues',
    'error',
    'errors',
    'problem',
    'problems',
    'fix',
    'improve',
    'improvement',
  };

  // Combine all relevant keyword sets for matching
  static final Set<String> _allRelevantKeywords = {
    ..._plantKeywords,
    ..._diseaseKeywords,
    ..._pestKeywords,
    ..._plantNames,
    ..._appKeywords,
  };

  // High-value combinations that should boost score
  static final List<RegExp> _highValuePatterns = [
    RegExp(
      r'\b(tomato|potato|pepper)\s+(blight|rot|disease)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(plant|crop)\s+(disease|pest|treatment)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(how\s+to|what\s+is|why\s+is)\s+.*(plant|disease|pest|treatment|garden)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(treat|cure|prevent|control)\s+.*(disease|pest|blight|rot)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(garden|grow|plant)\s+(problem|issue|help)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(leaf|leaves|stem|root)\s+(yellow|brown|spot|wilt|rot)\b',
      caseSensitive: false,
    ),
  ];

  /// Very lightweight filter: calculates relevance score and identifies potential off-topic messages
  ///
  /// Returns a relevance score from 0.0 (completely off-topic) to 1.0 (clearly relevant)
  static double getRelevanceScore(String text) {
    if (text.isEmpty) return 0.5; // Neutral for empty text

    // Check for high-value patterns first
    for (final pattern in _highValuePatterns) {
      if (pattern.hasMatch(text)) {
        return 0.85; // High confidence for pattern matches
      }
    }

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

    // Check for stem matches and partial matches
    int partialMatches = 0;
    for (final word in words) {
      if (!_allRelevantKeywords.contains(word)) {
        // Check for words that start with known keywords
        for (final keyword in _allRelevantKeywords) {
          if (word.startsWith(keyword) && word.length <= keyword.length + 3) {
            partialMatches++;
            break;
          }
          if (keyword.startsWith(word) && keyword.length <= word.length + 3) {
            partialMatches++;
            break;
          }
        }
      }
    }

    // Special handling for very short queries
    if (words.length <= 3) {
      if (matchCount > 0) {
        return 0.8; // High confidence for short relevant queries
      } else if (partialMatches > 0) {
        return 0.6; // Medium confidence for partial matches
      }
    }

    // Calculate base score from exact matches
    double baseScore = matchCount / words.length;

    // Add bonus for partial matches
    double partialBonus = (partialMatches * 0.5) / words.length;

    // Final score with bonus, capped at 1.0
    double finalScore = (baseScore + partialBonus).clamp(0.0, 1.0);

    // Extra bonus for questions containing both plant names and disease terms
    bool hasPlantName = words.any((word) => _plantNames.contains(word));
    bool hasDiseaseKeyword = words.any(
      (word) => _diseaseKeywords.contains(word),
    );

    if (hasPlantName && hasDiseaseKeyword) {
      finalScore = (finalScore * 1.2).clamp(0.0, 1.0);
    }

    return finalScore;
  }

  /// Determine if a chat message is out of scope
  ///
  /// Returns true if the message appears to be off-topic
  static bool isOutOfScope(String text) {
    final score = getRelevanceScore(text);
    return score < 0.4; // Adjust threshold as needed
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

    // Check for pattern matches
    List<String> patternMatches = [];
    for (final pattern in _highValuePatterns) {
      if (pattern.hasMatch(text)) {
        patternMatches.add('Pattern match detected');
        break;
      }
    }

    String debugInfo =
        '[Debug: Score ${score.toStringAsFixed(2)}, ' +
        'Matched ${matchCount}/${words.length}: ${matchedWords.join(', ')}';

    if (patternMatches.isNotEmpty) {
      debugInfo += ', ${patternMatches.join(', ')}';
    }

    debugInfo += ']';

    return debugInfo;
  }
}
