import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WasteAiSuggestion {
  final String? category;
  final bool isWasteRelated;
  final bool isUnclear;
  final String message;

  const WasteAiSuggestion({
    required this.category,
    required this.isWasteRelated,
    required this.isUnclear,
    required this.message,
  });
}

class WasteAiService {
  late final GenerativeModel _model;

  WasteAiService() {
    // IMPORTANT FOR firebase_ai 2.3.0:
    // Older firebase_ai versions do not automatically use the
    // Firebase App Check instance for AI Logic requests.
    //
    // We therefore pass both App Check and Firebase Auth explicitly.
    final ai = FirebaseAI.googleAI(
      appCheck: FirebaseAppCheck.instance,
      auth: FirebaseAuth.instance,
    );

    _model = ai.generativeModel(
      model: 'gemini-3.7-flash',
    );
  }

  static const Map<String, String> _categoryMap = {
    'GENERAL_WASTE': 'General Waste',
    'PLASTIC_WASTE': 'Plastic Waste',
    'ILLEGAL_DUMPING': 'Illegal Dumping',
    'BULKY_WASTE': 'Bulky Waste',
    'HAZARDOUS_WASTE': 'Hazardous Waste',
  };

  Future<WasteAiSuggestion> suggestWasteType(File imageFile) async {
    final bytes = await imageFile.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception('The selected image is empty.');
    }

    final mimeType = _mimeTypeForFile(imageFile.path);

    final prompt = TextPart(
      '''
You are assisting a community waste reporting mobile application.

Analyze ONLY the submitted image and choose the most suitable report category.

Allowed categories:
- GENERAL_WASTE: ordinary mixed household/community waste that does not fit another category
- PLASTIC_WASTE: the main visible waste is plastic items such as bottles, bags, containers, packaging
- ILLEGAL_DUMPING: waste appears dumped or abandoned improperly in a public/open area, especially piles or scattered dumping
- BULKY_WASTE: large discarded items such as furniture, mattresses, large appliances, cabinets, large boxes
- HAZARDOUS_WASTE: clearly visible potentially hazardous waste such as batteries, chemicals, paint/chemical containers, medical/sharp waste, or other dangerous material
- NOT_WASTE: the image clearly does not show a waste-related issue
- UNCLEAR: the image is too unclear or there is not enough visual evidence to decide

Important:
1. This is only a suggestion. A human user will make the final choice.
2. Do not invent objects that are not visible.
3. If uncertain, use UNCLEAR.
4. Return EXACTLY ONE of these values and nothing else:
GENERAL_WASTE
PLASTIC_WASTE
ILLEGAL_DUMPING
BULKY_WASTE
HAZARDOUS_WASTE
NOT_WASTE
UNCLEAR
''',
    );

    final imagePart = InlineDataPart(mimeType, bytes);

    final response = await _model.generateContent([
      Content.multi([
        prompt,
        imagePart,
      ]),
    ]);

    final rawResult = response.text?.trim().toUpperCase() ?? '';

    final normalized = rawResult
        .replaceAll('`', '')
        .replaceAll('*', '')
        .replaceAll('.', '')
        .trim();

    for (final entry in _categoryMap.entries) {
      if (normalized == entry.key || normalized.contains(entry.key)) {
        return WasteAiSuggestion(
          category: entry.value,
          isWasteRelated: true,
          isUnclear: false,
          message: 'Gemini suggests ${entry.value}.',
        );
      }
    }

    if (normalized.contains('NOT_WASTE')) {
      return const WasteAiSuggestion(
        category: null,
        isWasteRelated: false,
        isUnclear: false,
        message:
            'Gemini could not identify a waste-related issue in this image. '
            'Please check the photo or choose the waste type manually.',
      );
    }

    if (normalized.contains('UNCLEAR')) {
      return const WasteAiSuggestion(
        category: null,
        isWasteRelated: true,
        isUnclear: true,
        message:
            'Gemini could not confidently identify the waste type from this '
            'image. Please choose the waste type manually.',
      );
    }

    throw Exception(
      'Gemini returned an unexpected category. Please try again.',
    );
  }

  String _mimeTypeForFile(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    return 'image/jpeg';
  }
}
