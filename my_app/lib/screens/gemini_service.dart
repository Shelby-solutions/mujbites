import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String _apiKey = 'AIzaSyBHDFSnjvrvX4oI8hdLunfBUeMzAc72l_E'; // Replace with your actual API key
  static const String _model = 'gemini-1.5-flash'; // Using the latest stable model

  Future<String> getPersonalizedRecommendation({
    required String mood,
    required String category,
    required String cuisine,
    required List<String> orderHistory,
    required double priceRange,
  }) async {
    try {
      final prompt = '''
        As a food recommendation AI, suggest a personalized reason why a user might enjoy a $category dish from $cuisine cuisine.
        Consider:
        - Current mood: $mood
        - Previous orders: ${orderHistory.join(', ')}
        - Price range: \$$priceRange
        
        Provide a short, engaging reason (max 50 characters) that feels personal and considerate.
      ''';

      final response = await http.post(
        Uri.parse('$_baseUrl/models/$_model:generateContent?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [{
            'parts': [{
              'text': prompt
            }]
          }],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 50,
            'topK': 40,
            'topP': 0.95,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            }
          ]
        }),
      );

      if (response.statusCode == 429) {
        print('Gemini API quota exhausted, using default suggestion');
        return _getDefaultReason(mood, category);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
          return text.trim();
        }
        return _getDefaultReason(mood, category);
      } else {
        print('Gemini API error: ${response.statusCode} - ${response.body}');
        return _getDefaultReason(mood, category);
      }
    } catch (e) {
      print('Gemini API error: $e');
      return _getDefaultReason(mood, category);
    }
  }

  String _getDefaultReason(String mood, String category) {
    final moodLower = mood.toLowerCase();
    final categoryLower = category.toLowerCase();

    if (moodLower == 'happy') {
      return 'Perfect to celebrate your happy mood!';
    } else if (moodLower == 'stressed') {
      return 'Comfort food to help you relax';
    } else if (moodLower == 'tired') {
      return 'Quick energy boost for you';
    } else if (moodLower == 'healthy') {
      return 'Nutritious choice for your healthy mood';
    }

    // Category-based fallbacks if mood is not recognized
    if (categoryLower.contains('dessert') || categoryLower.contains('sweet')) {
      return 'Sweet treat to brighten your day';
    } else if (categoryLower.contains('spicy') || categoryLower.contains('hot')) {
      return 'Spicy kick to energize you';
    } else if (categoryLower.contains('healthy') || categoryLower.contains('salad')) {
      return 'Fresh and healthy choice';
    } else if (categoryLower.contains('comfort') || categoryLower.contains('soup')) {
      return 'Comforting and satisfying';
    }

    return 'A delicious choice for you';
  }

  Future<List<String>> getMoodBasedCategories(String mood) async {
    try {
      final prompt = '''
        As a food expert, suggest 5 food categories that would be perfect for someone feeling $mood.
        Consider the psychological and nutritional aspects of food choices based on mood.
        Provide just the category names separated by commas, no explanations.
      ''';

      final response = await http.post(
        Uri.parse('$_baseUrl/models/$_model:generateContent?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [{
            'parts': [{
              'text': prompt
            }]
          }],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 50,
            'topK': 40,
            'topP': 0.95,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            }
          ]
        }),
      );

      if (response.statusCode == 429) {
        print('Gemini API quota exhausted, using default categories');
        return _getDefaultCategories(mood);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
          return text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        return _getDefaultCategories(mood);
      } else {
        print('Gemini API error: ${response.statusCode} - ${response.body}');
        return _getDefaultCategories(mood);
      }
    } catch (e) {
      print('Gemini API error: $e');
      return _getDefaultCategories(mood);
    }
  }

  List<String> _getDefaultCategories(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return ['Pizza', 'Ice Cream', 'Burgers', 'Desserts', 'Snacks'];
      case 'stressed':
        return ['Comfort Food', 'Soups', 'Chocolate', 'Tea', 'Pasta'];
      case 'tired':
        return ['Coffee', 'Energy Drinks', 'Healthy Snacks', 'Smoothies', 'Light Meals'];
      case 'healthy':
        return ['Salads', 'Grilled Chicken', 'Smoothie Bowls', 'Protein Bowls', 'Fresh Juices'];
      default:
        return ['Pizza', 'Burgers', 'Salads', 'Desserts', 'Beverages'];
    }
  }
} 