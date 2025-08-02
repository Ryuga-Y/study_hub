import 'dart:convert';
import 'package:http/http.dart' as http;

class PerspectiveModerationService {
  static const String _perspectiveApiKey = 'AIzaSyBr0AG8OE5et8DA_5dCuizUIQr76ch00Uc'; // Replace with your actual API key
  static const String _perspectiveApiUrl = 'https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze';
  // Stricter thresholds
  // More sensitive thresholds for better user experience
  static const double TOXICITY_BLOCK_THRESHOLD = 0.7;      // Lowered from 0.8
  static const double SEVERE_TOXICITY_BLOCK_THRESHOLD = 0.5; // Lowered from 0.6
  static const double PROFANITY_BLOCK_THRESHOLD = 0.6;     // Lowered from 0.8
  static const double INSULT_BLOCK_THRESHOLD = 0.7;        // Lowered from 0.8
  static const double HARASSMENT_WARN_THRESHOLD = 0.5;     // Lowered from 0.7

  // Add more granular warning thresholds
  static const double MILD_TOXICITY_WARN_THRESHOLD = 0.4;  // New
  static const double MILD_INSULT_WARN_THRESHOLD = 0.4;   // New threshold

  static Future<ModerationAction> shouldModerateContent(String content) async {
    // Check for explicit words first (local check)
    if (_containsExplicitContent(content)) {
      return ModerationAction.block(reason: 'Content contains inappropriate language');
    }

    // Check for spam
    if (_detectSpam(content)) {
      return ModerationAction.block(reason: 'Spam detected');
    }

    // Check toxicity with Perspective API
    final result = await analyzeContent(content);

    if (result.isFlagged) {
      // Block only for serious violations
      if (result.categoryScores['severe_toxicity']! > SEVERE_TOXICITY_BLOCK_THRESHOLD ||
          result.categoryScores['toxicity']! > TOXICITY_BLOCK_THRESHOLD ||
          result.categoryScores['profanity']! > PROFANITY_BLOCK_THRESHOLD ||
          result.categoryScores['threat']! > 0.8 ||  // Increased from 0.7
          result.categoryScores['identity_attack']! > 0.8) {  // Increased from 0.7
        return ModerationAction.block(reason: 'Content violates community guidelines');
      }
      // Flag for moderate violations
      else if (result.categoryScores['harassment']! > HARASSMENT_WARN_THRESHOLD ||
          result.categoryScores['insult']! > INSULT_BLOCK_THRESHOLD) {
        return ModerationAction.flag(reason: 'Please be respectful in your language');
      }
      // Warn for mild issues
      else if (result.categoryScores['toxicity']! > 0.6 ||
          result.categoryScores['insult']! > 0.6) {
        return ModerationAction.warn(reason: 'Consider using more constructive language');
      }
    }

    if (result.isFlagged) {
      // Block only for serious violations
      if (result.categoryScores['severe_toxicity']! > SEVERE_TOXICITY_BLOCK_THRESHOLD ||
          result.categoryScores['toxicity']! > TOXICITY_BLOCK_THRESHOLD ||
          result.categoryScores['profanity']! > PROFANITY_BLOCK_THRESHOLD ||
          result.categoryScores['threat']! > 0.7 ||
          result.categoryScores['identity_attack']! > 0.7) {
        return ModerationAction.block(reason: 'Content violates community guidelines');
      }
      // Flag for moderate violations
      else if (result.categoryScores['harassment']! > HARASSMENT_WARN_THRESHOLD ||
          result.categoryScores['insult']! > INSULT_BLOCK_THRESHOLD) {
        return ModerationAction.flag(reason: 'Please be respectful in your language');
      }
    }

    // Add more sensitive warning for mild issues
    if (result.categoryScores['toxicity']! > MILD_TOXICITY_WARN_THRESHOLD ||
        result.categoryScores['insult']! > MILD_INSULT_WARN_THRESHOLD ||
        result.categoryScores['profanity']! > 0.4) {
      return ModerationAction.warn(reason: 'Consider using more constructive language');
    }

    return ModerationAction.allow();

    return ModerationAction.allow();
  }

  static bool _isLikelyOffensive(String text, Map<String, double> scores) {
    // If it's a short message with high insult score, it's more likely offensive
    if (text.split(' ').length < 10 && scores['insult']! > 0.7) {
      return true;
    }

    // Check for patterns that indicate constructive criticism vs personal attacks
    final constructivePatterns = [
      'bug', 'code', 'design', 'idea', 'plan', 'mistake', 'error'
    ];

    final lowerText = text.toLowerCase();
    final hasConstructiveContext = constructivePatterns.any(
            (pattern) => lowerText.contains(pattern)
    );

    // Be more lenient if it seems like constructive criticism
    return !hasConstructiveContext;
  }

  // Local explicit content detection
  static bool _containsExplicitContent(String text) {
    final explicitWords = [
      'fuck', 'shit', 'bitch', 'ass', 'damn', 'crap', 'piss',
      'bastard', 'slut', 'whore', 'dick', 'cock', 'pussy', 'tits',
      // Add more as needed, but be careful with context
    ];

    final lowerText = text.toLowerCase();

    // Check for whole words to avoid false positives
    for (final word in explicitWords) {
      final regex = RegExp(r'\b' + RegExp.escape(word) + r'\b');
      if (regex.hasMatch(lowerText)) {
        return true;
      }
    }

    // Check for variations with special characters
    final variations = [
      'f*ck', 'f**k', 'f***', 'sh*t', 'b*tch', 'd*mn',
      'fck', 'sht', 'btch', 'dmn', 'fuk', 'fok'
    ];

    for (final variation in variations) {
      if (lowerText.contains(variation)) {
        return true;
      }
    }

    return false;
  }

  // Enhanced spam detection
  static bool _detectSpam(String text) {
    final spamKeywords = [
      'free money', 'click here', 'limited time', 'act now',
      'guaranteed', 'no risk', 'winner', 'congratulations',
      'urgent', 'immediately', 'special offer', 'buy now',
      'make money fast', 'work from home', 'get rich quick'
    ];

    final lowerText = text.toLowerCase();

    // Check for spam keywords
    if (spamKeywords.any((keyword) => lowerText.contains(keyword))) {
      return true;
    }

    // Check for excessive capitalization
    if (_hasExcessiveCaps(text)) {
      return true;
    }

    return _hasExcessiveLinks(text) || _hasRepeatedCharacters(text);
  }

  static bool _hasExcessiveCaps(String text) {
    if (text.length < 10) return false;

    final capsCount = text.split('').where((char) =>
    char == char.toUpperCase() && char != char.toLowerCase()).length;

    return (capsCount / text.length) > 0.7; // More than 70% caps
  }

  // Rest of your existing methods remain the same...
  static bool _hasExcessiveLinks(String text) {
    final linkRegex = RegExp(r'https?://[^\s]+');
    return linkRegex.allMatches(text).length > 2;
  }

  static bool _hasRepeatedCharacters(String text) {
    final repeatedRegex = RegExp(r'(.)\1{4,}'); // 5+ repeated characters
    return repeatedRegex.hasMatch(text);
  }
  // Google Perspective API - FREE and very accurate for toxicity detection
  static Future<ContentModerationResult> analyzeContent(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_perspectiveApiUrl?key=$_perspectiveApiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'comment': {
            'text': text,
          },
          'requestedAttributes': {
            'TOXICITY': {},
            'SEVERE_TOXICITY': {},
            'IDENTITY_ATTACK': {},
            'INSULT': {},
            'PROFANITY': {},
            'THREAT': {},
            'SEXUALLY_EXPLICIT': {},
            'FLIRTATION': {},
          },
          'languages': ['en'],
          'doNotStore': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ContentModerationResult.fromPerspective(data);
      }

      return ContentModerationResult.safe();
    } catch (e) {
      print('Perspective API moderation error: $e');
      // In case of API failure, use local check
      if (_containsExplicitContent(text)) {
        return ContentModerationResult(
          isFlagged: true,
          categories: {'profanity': true},
          categoryScores: {'toxicity': 0.9, 'profanity': 0.9},
          toxicityScore: 0.9,
          spamScore: 0.0,
          threatScore: 0.0,
          isSafe: false,
        );
      }
      return ContentModerationResult.safe();
    }
  }
}

class ContentModerationResult {
  final bool isFlagged;
  final Map<String, bool> categories;
  final Map<String, double> categoryScores;
  final double toxicityScore;
  final double spamScore;
  final double threatScore;
  final bool isSafe;

  ContentModerationResult({
    required this.isFlagged,
    required this.categories,
    required this.categoryScores,
    required this.toxicityScore,
    required this.spamScore,
    required this.threatScore,
    required this.isSafe,
  });

  // Factory for Perspective API response
  factory ContentModerationResult.fromPerspective(Map<String, dynamic> json) {
    final attributes = json['attributeScores'] as Map<String, dynamic>? ?? {};

    // Extract scores from Perspective API
    double getScore(String attribute) {
      return attributes[attribute]?['summaryScore']?['value']?.toDouble() ?? 0.0;
    }

    final toxicity = getScore('TOXICITY');
    final severeToxicity = getScore('SEVERE_TOXICITY');
    final identityAttack = getScore('IDENTITY_ATTACK');
    final insult = getScore('INSULT');
    final profanity = getScore('PROFANITY');
    final threat = getScore('THREAT');
    final sexuallyExplicit = getScore('SEXUALLY_EXPLICIT');
    final flirtation = getScore('FLIRTATION');

    // Map Perspective scores to categories (using thresholds)
    final categories = <String, bool>{
      'hate': identityAttack > 0.7,
      'harassment': toxicity > 0.7 || insult > 0.7,
      'threat': threat > 0.7,
      'violence': threat > 0.8, // High threat score indicates violence
      'sexual': sexuallyExplicit > 0.7,
      'insult': insult > 0.7,
      'profanity': profanity > 0.7,
    };

    // Map scores to match expected format
    final categoryScores = <String, double>{
      'toxicity': toxicity,
      'severe_toxicity': severeToxicity,
      'identity_attack': identityAttack,
      'harassment': insult,
      'insult': insult,
      'hate': identityAttack,
      'threat': threat,
      'violence': threat,
      'sexual': sexuallyExplicit,
      'profanity': profanity,
    };

    // Determine if content should be flagged
    final isFlagged = toxicity > 0.8 ||  // Changed from 0.7
        severeToxicity > 0.6 ||  // Changed from 0.5
        threat > 0.8 ||  // Changed from 0.7
        identityAttack > 0.8 ||  // Changed from 0.7
        insult > 0.8 ||  // Add insult check
        profanity > 0.8;  // Add profanity check

    return ContentModerationResult(
      isFlagged: isFlagged,
      categories: categories,
      categoryScores: categoryScores,
      toxicityScore: toxicity,
      spamScore: 0.0, // Perspective doesn't have spam detection
      threatScore: threat,
      isSafe: !isFlagged && toxicity < 0.6,
    );
  }

  // Keep the OpenAI factory for backwards compatibility if needed
  factory ContentModerationResult.fromOpenAI(Map<String, dynamic> json) {
    final results = json['results'][0] as Map<String, dynamic>;
    final flagged = results['flagged'] as bool;
    final categories = Map<String, bool>.from(results['categories']);
    final categoryScores = Map<String, double>.from(
      (results['category_scores'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );

    // Calculate overall toxicity score from OpenAI categories
    final toxicityScore = [
      categoryScores['hate'] ?? 0.0,
      categoryScores['harassment'] ?? 0.0,
      categoryScores['violence'] ?? 0.0,
    ].reduce((a, b) => a > b ? a : b); // Get max score

    return ContentModerationResult(
      isFlagged: flagged,
      categories: categories,
      categoryScores: categoryScores,
      toxicityScore: toxicityScore,
      spamScore: 0.0, // OpenAI doesn't have spam detection
      threatScore: categoryScores['violence/graphic'] ?? 0.0,
      isSafe: !flagged,
    );
  }

  // Factory for backwards compatibility
  factory ContentModerationResult.fromJson(Map<String, dynamic> json) {
    // This is for Google Perspective API format
    final attributes = json['attributeScores'] as Map<String, dynamic>? ?? {};

    double getToxicityScore(String attribute) {
      return attributes[attribute]?['summaryScore']?['value']?.toDouble() ?? 0.0;
    }

    final toxicity = getToxicityScore('TOXICITY');
    final spam = getToxicityScore('SPAM');
    final threat = getToxicityScore('THREAT');

    return ContentModerationResult(
      isFlagged: toxicity > 0.7,
      categories: {},
      categoryScores: {},
      toxicityScore: toxicity,
      spamScore: spam,
      threatScore: threat,
      isSafe: toxicity < 0.6 && spam < 0.7 && threat < 0.5,
    );
  }

  factory ContentModerationResult.safe() {
    return ContentModerationResult(
      isFlagged: false,
      categories: {},
      categoryScores: {},
      toxicityScore: 0.0,
      spamScore: 0.0,
      threatScore: 0.0,
      isSafe: true,
    );
  }
}

class ModerationAction {
  final ModerationActionType type;
  final String reason;

  ModerationAction._(this.type, this.reason);

  factory ModerationAction.allow() => ModerationAction._(ModerationActionType.allow, '');
  factory ModerationAction.warn({required String reason}) => ModerationAction._(ModerationActionType.warn, reason);
  factory ModerationAction.flag({required String reason}) => ModerationAction._(ModerationActionType.flag, reason);
  factory ModerationAction.block({required String reason}) => ModerationAction._(ModerationActionType.block, reason);
}

enum ModerationActionType { allow, warn, flag, block }