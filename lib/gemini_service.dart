import 'dart:typed_data';

import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  final GenerativeModel _textModel;
  final GenerativeModel _imageModel;

  GeminiService()
      : _textModel = FirebaseVertexAI.instance.generativeModel(
          model: 'gemini-pro',
          generationConfig: GenerationConfig(temperature: 0.8),
        ),
        _imageModel = FirebaseVertexAI.instance.generativeModel(
          model: 'gemini-pro-vision',
        );

  Future<String> generateStory(String prompt) async {
    try {
      final fullPrompt = '''
      You are a creative and engaging storyteller for children.
      Write a short, simple, and educational story based on the following theme: $prompt
      The story should be suitable for a 5-year-old child, with a positive and clear moral message.
      The story must be split into exactly 5 paragraphs. Each paragraph should be short (2-3 sentences max).
      Do not use complex words; keep sentences short.
      ''';

      final response = await _textModel.generateContent([Content.text(fullPrompt)]);
      return response.text ?? 'I could not think of a story right now.';
    } catch (e) {
      debugPrint('Error generating story: $e');
      return 'An error occurred while generating the story.';
    }
  }

  Future<List<Uint8List>> generateStoryboardImages(String storyText) async {
    try {
      final paragraphs = storyText.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
      final List<Uint8List> allImageData = [];

      for (var paragraph in paragraphs) {
        final imagePrompt = '''
        A cute, vibrant, and simple children's storybook illustration for the following scene:
        $paragraph
        Style: Whimsical, colorful, friendly characters, soft lighting, clean digital art. No text, just the image.
        ''';

        final response = await _imageModel.generateContent([
          Content.multi([
            TextPart(imagePrompt),
            // Placeholder for image data if needed, but we are generating from text
          ])
        ]);

        // The `firebase_vertexai` package doesn't directly return image bytes.
        // This part of the code will need to be adapted based on how you intend
        // to generate and receive image data from the 'gemini-pro-vision' model.
        // This example assumes a text-based response that might contain a link or
        // identifier to an image, which is not the typical use case for generation.
        // For actual image generation, a different model or service (like Imagen)
        // would be used. The code below is a placeholder and will not work as-is.

        // if (response.parts.isNotEmpty && response.parts.first is DataPart) {
        //   final dataPart = response.parts.first as DataPart;
        //   allImageData.add(dataPart.bytes);
        // }
      }

      return allImageData;
    } catch (e) {
      debugPrint('Error generating storyboard: $e');
      return [];
    }
  }
}
