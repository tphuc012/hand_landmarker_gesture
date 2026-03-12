import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:jni/jni.dart';

// This is the auto-generated file from jnigen.
import 'hand_landmarker_bindings.dart';

// --- Public Data Models ---
/// A detected hand with its landmarks, gesture, and handedness.
class Hand {
  /// A list of 21 landmarks for the detected hand.
  final List<Landmark> landmarks;

  /// The top recognized gesture for this hand.
  final Gesture gesture;

  /// The handedness (Left / Right) for this hand.
  final Handedness handedness;

  Hand(this.landmarks, this.gesture, this.handedness);
}

/// A single landmark point with its 3D coordinates.
class Landmark {
  final double x;
  final double y;
  final double z;

  Landmark(this.x, this.y, this.z);
}

/// A recognized gesture with its label and confidence score.
class Gesture {
  final String name;
  final double score;

  Gesture(this.name, this.score);
}

/// The handedness (Left or Right) with its confidence score.
class Handedness {
  final String name;
  final double score;

  Handedness(this.name, this.score);
}

enum HandLandmarkerDelegate { cpu, gpu }

/// The main class for the Hand Landmarker plugin.
class HandLandmarkerPlugin {
  /// The underlying JNI-generated landmarker object.
  final MyHandLandmarker _landmarker;

  /// Private constructor to force initialization via the `create` method.
  HandLandmarkerPlugin._(this._landmarker);

  /// Creates and initializes the Hand Landmarker.
  static HandLandmarkerPlugin create({
    int numHands = 2,
    double minHandDetectionConfidence = 0.5,
    HandLandmarkerDelegate delegate = HandLandmarkerDelegate.gpu,
  }) {
    // Create the native MyHandLandmarker object.
    final contextObj = Jni.androidApplicationContext;

    final landmarker = MyHandLandmarker(contextObj);

    // Initialize the native landmarker with the provided options.
    landmarker.initialize(
      numHands,
      minHandDetectionConfidence,
      delegate == HandLandmarkerDelegate.gpu,
    );

    return HandLandmarkerPlugin._(landmarker);
  }

  /// Detects hand landmarks in a given [CameraImage].
  List<Hand> detect(CameraImage image, int sensorOrientation) {
    // Get the Y, U, and V planes from the CameraImage.
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    // Create JNI-compatible ByteBuffers for each plane.
    final yBuffer = JByteBuffer.fromList(yPlane.bytes);
    final uBuffer = JByteBuffer.fromList(uPlane.bytes);
    final vBuffer = JByteBuffer.fromList(vPlane.bytes);

    // Call the new native method with all the required plane data.
    final resultJString = _landmarker.detectFromYuv(
      yBuffer,
      uBuffer,
      vBuffer,
      image.width,
      image.height,
      yPlane.bytesPerRow,
      uPlane.bytesPerRow,
      uPlane.bytesPerPixel!,
      sensorOrientation,
    );
    final resultString = resultJString.toDartString();

    // Release native resources as soon as possible.
    yBuffer.release();
    uBuffer.release();
    vBuffer.release();
    resultJString.release();

    if (resultString.isEmpty || resultString == "[]") {
      return [];
    }

    // Parse the JSON result and map it to our clean data models.
    final parsedResult = jsonDecode(resultString) as List<dynamic>;
    final hands = parsedResult.map((handData) {
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

    return hands;
  }

  /// Releases the native landmarker resources.
  void dispose() {
    _landmarker.release();
  }
}
