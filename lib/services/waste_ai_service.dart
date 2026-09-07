import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';

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
  late final Future<GenerativeModel> _modelFuture;

  WasteAiService() {
    _modelFuture = _createModel();
  }

  // ============================================================
  // GEMINI MODEL INITIALIZATION
  // ============================================================
  //
  // The application now uses the Agent Platform Gemini API
  // instead of the Gemini Developer API.
  //
  // The Agent Platform backend is connected to the Firebase
  // project's Google Cloud billing account.
  //
  // Firebase App Check remains enabled globally in main.dart.
  //
  // ============================================================

  Future<GenerativeModel> _createModel() async {
    final ai = await FirebaseAI.agentPlatform(
      location: 'global',
    );

    return ai.generativeModel(
      model: 'gemini-3.7-flash',
    );
  }

  // ============================================================
  // SUPPORTED WASTE CATEGORIES
  // ============================================================

  static const Map<String, String> _categoryMap = {
    'GENERAL_WASTE': 'General Waste',
    'PLASTIC_WASTE': 'Plastic Waste',
    'ILLEGAL_DUMPING': 'Illegal Dumping',
    'BULKY_WASTE': 'Bulky Waste',
    'HAZARDOUS_WASTE': 'Hazardous Waste',
  };

  // ============================================================
  // ANALYSE WASTE IMAGE
  // ============================================================

  Future<WasteAiSuggestion> suggestWasteType(
    File imageFile,
  ) async {
    final bytes = await imageFile.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception(
        'The selected image is empty.',
      );
    }

    final mimeType = _mimeTypeForFile(
      imageFile.path,
    );

    // Wait until the Agent Platform Gemini model
    // has finished initializing.
    final model = await _modelFuture;

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

    final imagePart = InlineDataPart(
      mimeType,
      bytes,
    );

    final response = await model.generateContent([
      Content.multi([
        prompt,
        imagePart,
      ]),
    ]);

    final rawResult =
        response.text?.trim().toUpperCase() ?? '';

    final normalized = rawResult
        .replaceAll('`', '')
        .replaceAll('*', '')
        .replaceAll('.', '')
        .trim();

    // ==========================================================
    // VALID WASTE CATEGORY
    // ==========================================================

    for (final entry in _categoryMap.entries) {
      if (normalized == entry.key ||
          normalized.contains(entry.key)) {
        return WasteAiSuggestion(
          category: entry.value,
          isWasteRelated: true,
          isUnclear: false,
          message:
              'Gemini suggests ${entry.value}.',
        );
      }
    }

    // ==========================================================
    // IMAGE IS NOT WASTE RELATED
    // ==========================================================

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

    // ==========================================================
    // IMAGE IS UNCLEAR
    // ==========================================================

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

    // ==========================================================
    // UNEXPECTED GEMINI RESPONSE
    // ==========================================================

    throw Exception(
      'Gemini returned an unexpected category. Please try again.',
    );
  }

  // ============================================================
  // IMAGE MIME TYPE
  // ============================================================

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