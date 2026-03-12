import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_landmarker_gesture/hand_landmarker_gesture.dart';

// A helper function to replicate the parsing logic from the plugin.
// This makes the tests self-contained and easy to understand.
List<Hand> parseHandsFromJson(String jsonString) {
  if (jsonString.isEmpty) return [];

  final parsedResult = jsonDecode(jsonString) as List<dynamic>;
  if (parsedResult.isEmpty) return [];

  return parsedResult.map((handData) {
    final data = handData as Map<String, dynamic>;

    final landmarks = (data['landmarks'] as List<dynamic>).map((lm) {
      final l = lm as Map<String, dynamic>;
      return Landmark(
        (l['x'] as num).toDouble(),
        (l['y'] as num).toDouble(),
        (l['z'] as num).toDouble(),
      );
    }).toList();

    final gestureData = data['gesture'] as Map<String, dynamic>;
    final gesture = Gesture(
      gestureData['name'] as String,
      (gestureData['score'] as num).toDouble(),
    );

    final handednessData = data['handedness'] as Map<String, dynamic>;
    final handedness = Handedness(
      handednessData['name'] as String,
      (handednessData['score'] as num).toDouble(),
    );

    return Hand(landmarks, gesture, handedness);
  }).toList();
}

void main() {
  group('Hand Landmarker Unit Tests', () {
    group('Data Model Tests', () {
      test('Landmark class holds correct values', () {
        final landmark = Landmark(0.1, 0.2, 0.3);
        expect(landmark.x, 0.1);
        expect(landmark.y, 0.2);
        expect(landmark.z, 0.3);
      });

      test('Gesture class holds correct values', () {
        final gesture = Gesture('Thumb_Up', 0.97);
        expect(gesture.name, 'Thumb_Up');
        expect(gesture.score, 0.97);
      });

      test('Handedness class holds correct values', () {
        final handedness = Handedness('Right', 0.99);
        expect(handedness.name, 'Right');
        expect(handedness.score, 0.99);
      });
    });

    group('JSON Parsing Tests', () {
      test('Correctly parses a valid result with two hands', () {
        // ARRANGE
        const jsonString = '''
[
  {
    "landmarks":[{"x":0.1,"y":0.2,"z":0.3},{"x":0.4,"y":0.5,"z":0.6}],
    "gesture":{"name":"Thumb_Up","score":0.97},
    "handedness":{"name":"Right","score":0.99}
  },
  {
    "landmarks":[{"x":0.7,"y":0.8,"z":0.9}],
    "gesture":{"name":"Open_Palm","score":0.85},
    "handedness":{"name":"Left","score":0.95}
  }
]''';

        // ACT
        final hands = parseHandsFromJson(jsonString);

        // ASSERT
        expect(hands, isA<List<Hand>>());
        expect(hands.length, 2);
        expect(hands[0].landmarks.length, 2);
        expect(hands[1].landmarks.length, 1);
        expect(hands[0].landmarks[0].x, 0.1);
        expect(hands[0].landmarks[1].y, 0.5);
        expect(hands[1].landmarks[0].z, 0.9);
        expect(hands[0].gesture.name, 'Thumb_Up');
        expect(hands[0].gesture.score, 0.97);
        expect(hands[0].handedness.name, 'Right');
        expect(hands[1].gesture.name, 'Open_Palm');
        expect(hands[1].handedness.name, 'Left');
      });

      test('Returns an empty list for an empty JSON array string', () {
        const jsonString = '[]';
        final hands = parseHandsFromJson(jsonString);
        expect(hands, isA<List<Hand>>());
        expect(hands, isEmpty);
      });

      test('Returns an empty list for an empty string', () {
        const jsonString = '';
        final hands = parseHandsFromJson(jsonString);
        expect(hands, isA<List<Hand>>());
        expect(hands, isEmpty);
      });

      test('Throws a FormatException for invalid JSON', () {
        const jsonString = 'not json';
        expect(() => jsonDecode(jsonString), throwsA(isA<FormatException>()));
      });
    });
  });
}
