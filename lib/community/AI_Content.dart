import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class PerspectiveModerationService {
  static String? _perspectiveApiKey;
  static const String _perspectiveApiUrl = 'https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze';

  // STRICTER thresholds to prevent API violations
  static const double TOXICITY_BLOCK_THRESHOLD = 0.7;
  static const double SEVERE_TOXICITY_BLOCK_THRESHOLD = 0.5;
  static const double PROFANITY_BLOCK_THRESHOLD = 0.6;
  static const double INSULT_BLOCK_THRESHOLD = 0.7;
  static const double HARASSMENT_WARN_THRESHOLD = 0.5;

  // Rate limiting to prevent API abuse
  static DateTime _lastApiCall = DateTime.now().subtract(Duration(seconds: 2));
  static const Duration _minTimeBetweenCalls = Duration(seconds: 1); // 1 second between calls
  static int _apiCallsToday = 0;
  static DateTime _lastResetDate = DateTime.now();
  static const int _maxDailyApiCalls = 1000; // Conservative limit

  static Future<void> initializeApiKey() async {
    try {
      final String response = await rootBundle.loadString('assets/config.json');
      final data = json.decode(response);
      _perspectiveApiKey = data['perspective_api_key'];
    } catch (e) {
      print('Failed to load API key: $e');
      // Fallback to local-only moderation if no API key
      _perspectiveApiKey = null;
    }
  }

  static Future<ModerationAction> shouldModerateContent(String content) async {
    _resetDailyCounterIfNeeded();

    final localResult = _performLocalModerationChecks(content);
    if (localResult.type != ModerationActionType.allow) {
      return localResult;
    }

    // Check rate limits before making API call
    if (!_canMakeApiCall()) {
      // If we can't make API call, rely on local checks only
      return _performStrictLocalModeration(content);
    }

    // Make API call only if content passes local checks
    try {
      if (_perspectiveApiKey == null) {
        await initializeApiKey();
      }

      if (_perspectiveApiKey == null || _perspectiveApiKey!.isEmpty) {
        // No API key available, use local-only moderation
        return _performStrictLocalModeration(content);
      }

      final result = await _analyzeContentSafely(content);
      _recordApiCall();

      return _processApiResult(result);

    } catch (e) {
      print('API error: $e - falling back to local moderation');
      return _performStrictLocalModeration(content);
    }
  }

  // Enhanced local checks to prevent sending inappropriate content to API
  static ModerationAction _performLocalModerationChecks(String content) {
    // Block empty or very short content
    if (content.trim().length < 3) {
      return ModerationAction.block(reason: 'Content too short');
    }

    // Block excessively long content
    if (content.length > 3000) {
      return ModerationAction.block(reason: 'Content too long');
    }

    // Check for explicit content
    if (_containsExplicitContent(content)) {
      return ModerationAction.block(reason: 'Contains inappropriate language');
    }

    // Check for spam patterns
    if (_detectSpam(content)) {
      return ModerationAction.block(reason: 'Spam detected');
    }

    // Check for obvious harassment patterns
    if (_containsHarassmentPatterns(content)) {
      return ModerationAction.block(reason: 'Harassment detected');
    }

    // Check for hate speech indicators
    if (_containsHateSpeechIndicators(content)) {
      return ModerationAction.block(reason: 'Hate speech detected');
    }

    return ModerationAction.allow();
  }

  // Strict local moderation when API is unavailable
  static ModerationAction _performStrictLocalModeration(String content) {
    final lowerContent = content.toLowerCase();

    // Be very conservative when we can't use API
    final suspiciousWords = [
      'kill', 'die', 'death', 'hurt', 'pain', 'hate', 'stupid', 'idiot',
      'ugly', 'fat', 'loser', 'dumb', 'worthless', 'pathetic'
    ];

    for (final word in suspiciousWords) {
      if (lowerContent.contains(word)) {
        return ModerationAction.warn(reason: 'Please use more positive language');
      }
    }

    return ModerationAction.allow();
  }

  // Enhanced explicit content detection
  static bool _containsExplicitContent(String text) {
    final explicitWords = [
      // Keep your existing list but add more variations
      'fuck', 'shit', 'bitch', 'ass', 'damn', 'crap', 'piss',
      'bastard', 'slut', 'whore', 'dick', 'cock', 'pussy', 'tits',
      // Add common variations and bypasses
      'f*ck', 'f**k', 'sh*t', 'b*tch', 'fck', 'sht', 'btch',
      'fuk', 'shyt', 'bytch', 'azz', 'fuq', 'shiit'
    ];

    final lowerText = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '');

    for (final word in explicitWords) {
      if (lowerText.contains(word)) {
        return true;
      }
    }

    return false;
  }

  // New Detect harassment patterns
  static bool _containsHarassmentPatterns(String text) {
    final harassmentPatterns = [
      'you should kill yourself', 'kill yourself', 'kys',
      'you\'re worthless', 'nobody likes you', 'you\'re pathetic',
      'go die', 'i hate you', 'you suck', 'you\'re ugly',
      'piece of shit', 'waste of space'
    ];

    final lowerText = text.toLowerCase();
    return harassmentPatterns.any((pattern) => lowerText.contains(pattern));
  }

  // New: Detect hate speech indicators
  static bool _containsHateSpeechIndicators(String text) {
    final hateSpeechWords = [
      // This is a minimal list - add more based on your specific needs
      'terrorist', 'nazi', 'fascist', 'commie', 'libtard', 'retard'
    ];

    final lowerText = text.toLowerCase();
    return hateSpeechWords.any((word) => lowerText.contains(word));
  }

  // Rate limiting functions
  static bool _canMakeApiCall() {
    final now = DateTime.now();

    // Check if enough time has passed since last call
    if (now.difference(_lastApiCall) < _minTimeBetweenCalls) {
      return false;
    }

    // Check daily limit
    if (_apiCallsToday >= _maxDailyApiCalls) {
      return false;
    }

    return true;
  }

  static void _recordApiCall() {
    _lastApiCall = DateTime.now();
    _apiCallsToday++;
  }

  static void _resetDailyCounterIfNeeded() {
    final now = DateTime.now();
    if (now.day != _lastResetDate.day) {
      _apiCallsToday = 0;
      _lastResetDate = now;
    }
  }

  // Safe API call with better error handling
  static Future<ContentModerationResult> _analyzeContentSafely(String text) async {
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
          },
          'languages': ['en'],
          'doNotStore': true, // Important: Don't store data
        }),
      ).timeout(Duration(seconds: 10)); // Add timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ContentModerationResult.fromPerspective(data);
      } else {
        throw Exception('API returned status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('API call failed: $e');
    }
  }

  // Process API results with stricter thresholds
  static ModerationAction _processApiResult(ContentModerationResult result) {
    if (result.isFlagged) {
      // Much stricter blocking criteria
      if (result.categoryScores['severe_toxicity']! > SEVERE_TOXICITY_BLOCK_THRESHOLD ||
          result.categoryScores['toxicity']! > TOXICITY_BLOCK_THRESHOLD ||
          result.categoryScores['profanity']! > PROFANITY_BLOCK_THRESHOLD ||
          result.categoryScores['threat']! > 0.3 ||  // Very low threshold
          result.categoryScores['identity_attack']! > 0.3) {
        return ModerationAction.block(reason: 'Content violates community guidelines');
      }
      // Flag for even moderate violations
      else if (result.categoryScores['insult']! > INSULT_BLOCK_THRESHOLD ||
          result.categoryScores['toxicity']! > 0.3) {
        return ModerationAction.flag(reason: 'Please be respectful in your language');
      }
    }

    // Warn for very mild issues
    if (result.categoryScores['toxicity']! > 0.2 ||
        result.categoryScores['insult']! > 0.2) {
      return ModerationAction.warn(reason: 'Consider using more constructive language');
    }

    return ModerationAction.allow();
  }

  // Keep your existing spam detection
  static bool _detectSpam(String text) {
    final spamKeywords = [
      'free money', 'click here', 'limited time', 'act now',
      'guaranteed', 'no risk', 'winner', 'congratulations',
      'urgent', 'immediately', 'special offer', 'buy now',
      'make money fast', 'work from home', 'get rich quick'
    ];

    final lowerText = text.toLowerCase();
    if (spamKeywords.any((keyword) => lowerText.contains(keyword))) {
      return true;
    }

    return _hasExcessiveCaps(text) || _hasExcessiveLinks(text) || _hasRepeatedCharacters(text);
  }

  static bool _hasExcessiveCaps(String text) {
    if (text.length < 10) return false;
    final capsCount = text.split('').where((char) =>
    char == char.toUpperCase() && char != char.toLowerCase()).length;
    return (capsCount / text.length) > 0.7;
  }

  static bool _hasExcessiveLinks(String text) {
    final linkRegex = RegExp(r'https?://[^\s]+');
    return linkRegex.allMatches(text).length > 2;
  }

  static bool _hasRepeatedCharacters(String text) {
    final repeatedRegex = RegExp(r'(.)\1{4,}');
    return repeatedRegex.hasMatch(text);
  }
}

// Keep your existing classes with minor updates
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

  factory ContentModerationResult.fromPerspective(Map<String, dynamic> json) {
    final attributes = json['attributeScores'] as Map<String, dynamic>? ?? {};

    double getScore(String attribute) {
      return attributes[attribute]?['summaryScore']?['value']?.toDouble() ?? 0.0;
    }

    final toxicity = getScore('TOXICITY');
    final severeToxicity = getScore('SEVERE_TOXICITY');
    final identityAttack = getScore('IDENTITY_ATTACK');
    final insult = getScore('INSULT');
    final profanity = getScore('PROFANITY');
    final threat = getScore('THREAT');

    final categoryScores = <String, double>{
      'toxicity': toxicity,
      'severe_toxicity': severeToxicity,
      'identity_attack': identityAttack,
      'harassment': insult,
      'insult': insult,
      'hate': identityAttack,
      'threat': threat,
      'profanity': profanity,
    };

    // More sensitive flagging
    final isFlagged = toxicity > 0.5 ||  // Lower threshold
        severeToxicity > 0.3 ||
        threat > 0.3 ||
        identityAttack > 0.3 ||
        insult > 0.5 ||
        profanity > 0.4;

    return ContentModerationResult(
      isFlagged: isFlagged,
      categories: {},
      categoryScores: categoryScores,
      toxicityScore: toxicity,
      spamScore: 0.0,
      threatScore: threat,
      isSafe: !isFlagged && toxicity < 0.3,
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