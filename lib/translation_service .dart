import 'package:google_generative_ai/google_generative_ai.dart';

class TranslationService {
  // Your Gemini API key
  static const String _geminiApiKey = 'AIzaSyBswr5pBGxo_u8gFnXc62MhnFn3_pL_bPM';

  // Gemini model instance
  late final GenerativeModel _model;

  // Singleton pattern for the service
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;

  TranslationService._internal() {
    // Initialize the Gemini model
    _model = GenerativeModel(
      model: 'gemini-1.5-flash', // You can also use 'gemini-pro'
      apiKey: _geminiApiKey,
    );
  }

  /// Translate text from source language to target language
  /// 
  /// [text] - The text to translate
  /// [targetLanguage] - The target language (e.g., 'Spanish', 'French', 'Chinese')
  /// [sourceLanguage] - The source language (optional, Gemini can auto-detect)
  /// 
  /// Returns the translated text or throws an exception
  Future<String> translateText({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    try {
      // Build the prompt for translation
      final prompt = _buildTranslationPrompt(
        text: text,
        targetLanguage: targetLanguage,
        sourceLanguage: sourceLanguage,
      );

      // Generate content using Gemini
      final response = await _model.generateContent([Content.text(prompt)]);

      // Extract the translated text
      final translatedText = response.text;

      if (translatedText == null || translatedText.isEmpty) {
        throw Exception('Translation failed: Empty response from Gemini');
      }

      return translatedText.trim();
    } catch (e) {
      throw Exception('Translation error: $e');
    }
  }

  /// Translate text to multiple languages at once
  Future<Map<String, String>> translateToMultipleLanguages({
    required String text,
    required List<String> targetLanguages,
    String? sourceLanguage,
  }) async {
    final translations = <String, String>{};

    // Process translations in parallel for better performance
    final futures = targetLanguages.map((language) async {
      try {
        final translation = await translateText(
          text: text,
          targetLanguage: language,
          sourceLanguage: sourceLanguage,
        );
        return MapEntry(language, translation);
      } catch (e) {
        return MapEntry(language, 'Translation failed: $e');
      }
    });

    final results = await Future.wait(futures);
    translations.addEntries(results);

    return translations;
  }

  /// Detect the language of the given text
  Future<String> detectLanguage(String text) async {
    try {
      final prompt = '''
Please identify the language of the following text. 
Respond with only the language name, nothing else.

Text: "$text"
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final detectedLanguage = response.text;

      if (detectedLanguage == null || detectedLanguage.isEmpty) {
        throw Exception('Language detection failed');
      }

      return detectedLanguage.trim();
    } catch (e) {
      throw Exception('Language detection error: $e');
    }
  }

  /// Build the translation prompt for Gemini
  String _buildTranslationPrompt({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) {
    if (sourceLanguage != null) {
      return '''
Translate the following text from $sourceLanguage to $targetLanguage.
Provide only the translation, no explanations or additional text.

Text to translate: "$text"
''';
    } else {
      return '''
Translate the following text to $targetLanguage.
Provide only the translation, no explanations or additional text.

Text to translate: "$text"
''';
    }
  }
}

// Example usage class
class TranslationExample {
  static Future<void> runExamples() async {
    final translator = TranslationService();

    try {
      // Example 1: Simple translation
      print('Example 1: Simple Translation');
      final spanishTranslation = await translator.translateText(
        text: 'Hello, how are you today?',
        targetLanguage: 'Spanish',
      );
      print('English -> Spanish: $spanishTranslation');

      // Example 2: Translation with source language specified
      print('\nExample 2: Translation with source language');
      final frenchTranslation = await translator.translateText(
        text: 'Good morning',
        targetLanguage: 'French',
        sourceLanguage: 'English',
      );
      print('English -> French: $frenchTranslation');

      // Example 3: Detect language
      print('\nExample 3: Language Detection');
      final detectedLang = await translator.detectLanguage('Bonjour le monde');
      print('Detected language: $detectedLang');

      // Example 4: Multiple translations
      print('\nExample 4: Multiple Translations');
      final multiTranslations = await translator.translateToMultipleLanguages(
        text: 'Welcome to our application',
        targetLanguages: ['Spanish', 'French', 'German', 'Italian'],
      );
      multiTranslations.forEach((language, translation) {
        print('$language: $translation');
      });

    } catch (e) {
      print('Error: $e');
    }
  }
}