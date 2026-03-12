import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Import the plugin's main class.
import 'package:hand_landmarker/hand_landmarker.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Hand Landmarker Example',
      home: HandTrackerView(),
    );
  }
}

class HandTrackerView extends StatefulWidget {
  const HandTrackerView({super.key});

  @override
  State<HandTrackerView> createState() => _HandTrackerViewState();
}

class _HandTrackerViewState extends State<HandTrackerView> {
  CameraController? _controller;
  // The plugin instance that will handle all the heavy lifting.
  HandLandmarkerPlugin? _plugin;
  // The results from the plugin will be stored in this list.
  List<Hand> _landmarks = [];
  // A flag to show a loading indicator while the camera and plugin are initializing.
  bool _isInitialized = false;
  // A guard to prevent processing multiple frames at once.
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final camera = _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    // Create an instance of our plugin with custom options.
    _plugin = HandLandmarkerPlugin.create(
      numHands: 2,
      minHandDetectionConfidence: 0.7,
      delegate: HandLandmarkerDelegate.gpu,
    );

    await _controller!.initialize();
    await _controller!.startImageStream(_processCameraImage);

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    // Stop the image stream and dispose of the controller.
    _controller?.stopImageStream();
    _controller?.dispose();
    // Dispose of the plugin to release native resources.
    _plugin?.dispose();
    super.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || !_isInitialized || _plugin == null) return;

    _isDetecting = true;

    try {
      // The detect method is now synchronous (not async).
      final hands = _plugin!.detect(
        image,
        _controller!.description.sensorOrientation,
      );
      if (mounted) {
        setState(() {
          _landmarks = hands;
        });
      }
    } catch (e) {
      debugPrint('Error detecting landmarks: $e');
    } finally {
      // Allow the next frame to be processed.
      _isDetecting = false;
    }
  }

  Widget _buildGestureInfo() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.3),
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: _landmarks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.pan_tool,
                    size: 48,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No hands detected',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: _landmarks.length,
              itemBuilder: (context, index) {
                final hand = _landmarks[index];
                final gestureScore = hand.gesture.score;
                final handednessScore = hand.handedness.score;
                final isLeftHand = hand.handedness.name.toLowerCase().contains('left');
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with hand number and icon
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(
                                  isLeftHand
                                      ? Icons.back_hand
                                      : Icons.front_hand,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hand ${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '${hand.handedness.name} Hand',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Info cards in a grid
                        Row(
                          children: [
                            // Gesture Card
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.pan_tool,
                                          color: Colors.amber[300],
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Gesture',
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      hand.gesture.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    // Progress bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: gestureScore,
                                        minHeight: 4,
                                        backgroundColor:
                                            Colors.amber.withOpacity(0.2),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.amber[300]!,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(gestureScore * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: Colors.amber.withOpacity(0.9),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Handedness Card
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.green[300],
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Confidence',
                                          style: TextStyle(
                                            color: Colors.lightGreen,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      hand.handedness.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    // Progress bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: handednessScore,
                                        minHeight: 4,
                                        backgroundColor:
                                            Colors.green.withOpacity(0.2),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.green[300]!,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(handednessScore * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: Colors.green.withOpacity(0.9),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while initializing.
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final controller = _controller!;
    final previewSize = controller.value.previewSize!;
    final previewAspectRatio = previewSize.height / previewSize.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Hand Tracking')),
      body: Center(
        child: AspectRatio(
          aspectRatio: previewAspectRatio,
          child: Stack(
            children: [
              CameraPreview(controller),
              _buildGestureInfo(),
              CustomPaint(
                // Tell the painter to fill the available space
                size: Size.infinite,
                painter: LandmarkPainter(
                  hands: _landmarks,
                  // Pass the camera's resolution explicitly
                  previewSize: previewSize,
                  lensDirection: controller.description.lensDirection,
                  sensorOrientation: controller.description.sensorOrientation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A custom painter that renders the hand landmarks and connections.
class LandmarkPainter extends CustomPainter {
  LandmarkPainter({
    required this.hands,
    required this.previewSize,
    required this.lensDirection,
    required this.sensorOrientation,
  });

  final List<Hand> hands;
  final Size previewSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / previewSize.height;

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 8 / scale
      ..strokeCap = StrokeCap.round;

    final linePaint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 4 / scale;

    canvas.save();

    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sensorOrientation * math.pi / 180);

    if (lensDirection == CameraLensDirection.front) {
      canvas.scale(-1, 1);
      canvas.rotate(math.pi);
    }

    canvas.scale(scale);

    // Assign logicalWidth to the sensor's width and logicalHeight to the sensor's height.
    final logicalWidth = previewSize.width;
    final logicalHeight = previewSize.height;

    for (final hand in hands) {
      for (final landmark in hand.landmarks) {
        // Now dx is scaled by width, and dy is scaled by height.
        final dx = (landmark.x - 0.5) * logicalWidth;
        final dy = (landmark.y - 0.5) * logicalHeight;
        canvas.drawCircle(Offset(dx, dy), 8 / scale, paint);
      }
      for (final connection in HandLandmarkConnections.connections) {
        final start = hand.landmarks[connection[0]];
        final end = hand.landmarks[connection[1]];
        final startDx = (start.x - 0.5) * logicalWidth;
        final startDy = (start.y - 0.5) * logicalHeight;
        final endDx = (end.x - 0.5) * logicalWidth;
        final endDy = (end.y - 0.5) * logicalHeight;
        canvas.drawLine(
          Offset(startDx, startDy),
          Offset(endDx, endDy),
          linePaint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Helper class.
class HandLandmarkConnections {
  static const List<List<int>> connections = [
    [0, 1], [1, 2], [2, 3], [3, 4], // Thumb
    [0, 5], [5, 6], [6, 7], [7, 8], // Index finger
    [5, 9], [9, 10], [10, 11], [11, 12], // Middle finger
    [9, 13], [13, 14], [14, 15], [15, 16], // Ring finger
    [13, 17], [0, 17], [17, 18], [18, 19], [19, 20], // Pinky
  ];
}
