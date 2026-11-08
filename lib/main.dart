import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // هذا السطر مهم جداً: يتحقق إذا التطبيق يشتغل كشاشة عائمة أو تطبيق عادي
  if (FlutterOverlayWindow.isActive()) {
    runApp(const OverlayApp());
  } else {
    runApp(const MyApp());
  }
}

// ==========================================
// التطبيق الأساسي
// ==========================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF3B82F6),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isOverlayActive = false;

  Future<void> _startOverlay() async {
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: false,
      overlayFlags: OverlayWindowFlags.none,
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
      position: OverlayPosition.fullScreen,
    );

    setState(() {
      _isOverlayActive = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AR Chess Assistant'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grid_on, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "افتح اللعبة، اضغط تشغيل،\nواختر لونك في الشاشة العائمة.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isOverlayActive ? null : _startOverlay,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Text(
                _isOverlayActive ? "الأداة شغالة!" : "تشغيل",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// تطبيق الشاشة العائمة (Overlay)
// ==========================================
class OverlayApp extends StatelessWidget {
  const OverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayWidget(),
    );
  }
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  bool _colorSelected = false;
  bool _isWhite = true;
  bool _isAnalyzing = false;
  
  Rect _pieceSquare = Rect.zero;
  Rect _targetSquare = Rect.zero;
  bool _showHighlights = false;

  void _selectColor(bool isWhite) {
    setState(() {
      _isWhite = isWhite;
      _colorSelected = true;
      _isAnalyzing = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _showHighlights = true;
          double squareSize = 50.0;
          _pieceSquare = Rect.fromLTWH(200, 500, squareSize, squareSize);
          _targetSquare = Rect.fromLTWH(200, 300, squareSize, squareSize);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          if (_showHighlights)
            Positioned.fill(
              child: CustomPaint(
                painter: SquareHighlighter(
                  pieceSquare: _pieceSquare,
                  targetSquare: _targetSquare,
                ),
              ),
            ),

          if (!_colorSelected)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("اختر لونك للبدء", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => _selectColor(true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.all(20)),
                          child: const Text("أبيض", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () => _selectColor(false),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.all(20), side: const BorderSide(color: Colors.white)),
                          child: const Text("أسود", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          if (_isAnalyzing)
            Center( // تم إزالة const من هنا لحل المشكلة
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(15)),
                child: const Column( // تم وضع const هنا
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.greenAccent),
                    SizedBox(height: 15),
                    Text("جاري قراءة الرقعة...", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),

          Positioned(
            top: 50,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 30),
              onPressed: () => FlutterOverlayWindow.closeOverlay(),
            ),
          )
        ],
      ),
    );
  }
}

class SquareHighlighter extends CustomPainter {
  final Rect pieceSquare;
  final Rect targetSquare;

  SquareHighlighter({required this.pieceSquare, required this.targetSquare});

  @override
  void paint(Canvas canvas, Size size) {
    final piecePaint = Paint()..color = Colors.blueAccent.withOpacity(0.6)..style = PaintingStyle.fill;
    final targetPaint = Paint()..color = Colors.greenAccent.withOpacity(0.6)..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3.0;

    canvas.drawRect(pieceSquare, piecePaint);
    canvas.drawRect(pieceSquare, borderPaint);
    canvas.drawRect(targetSquare, targetPaint);
    canvas.drawRect(targetSquare, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}