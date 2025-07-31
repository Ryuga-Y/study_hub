import 'package:flutter/material.dart';
import 'package:study_hub/translation_service%20.dart';

class TranslationScreen extends StatefulWidget {
  final String? initialText;

  const TranslationScreen({Key? key, this.initialText}) : super(key: key);

  @override
  _TranslationScreenState createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _textController = TextEditingController();
  final TranslationService _translator = TranslationService();

  String _translatedText = '';
  bool _isLoading = false;
  String _selectedLanguage = 'Spanish';

  final List<String> _languages = [
    'Spanish', 'French', 'German', 'Italian',
    'Portuguese', 'Chinese', 'Japanese', 'Korean'
  ];

  @override
  void initState() {
    super.initState();
    // Auto-fill the text field if initialText is provided
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
    }
  }

  Future<void> _translateText() async {
    if (_textController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _translator.translateText(
        text: _textController.text,
        targetLanguage: _selectedLanguage,
      );

      setState(() {
        _translatedText = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _translatedText = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gemini Translator')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Enter text to translate',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedLanguage,
              items: _languages.map((String language) {
                return DropdownMenuItem<String>(
                  value: language,
                  child: Text(language),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedLanguage = newValue!;
                });
              },
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _translateText,
              child: Text(_isLoading ? 'Translating...' : 'Translate'),
            ),
            SizedBox(height: 16),
            if (_translatedText.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _translatedText,
                  style: TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}