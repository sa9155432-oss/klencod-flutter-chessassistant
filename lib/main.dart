import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (await FlutterOverlayWindow.isActive()) {
    runApp(const OverlayApp());
  } else {
    runApp(const MyApp());
  }
}

// ==========================================
// التطبيق الأساسي (اللي بيه زر التشغيل)
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

    // فتح الشاشة العائمة بحجم كبير وشفاف عشان نرسم فوق الرقعة
    await FlutterOverlayWindow.showOverlay(
      enableDrag: false,
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
    );

    setState(() {
      _isOverlayActive = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chess AR'), centerTitle: true),
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
      color: Colors.transparent,
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
  String _bestMoveText = "جاري التحليل...";

  void _selectColor(bool isWhite) {
    setState(() {
      _isWhite = isWhite;
      _colorSelected = true;
      _isAnalyzing = true;
    });

    // هنا نحاكي قراءة الشاشة والحساب (ثانيتين)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          // هنا راح يطبع الحركة، مثلاً e2-e4
          _bestMoveText = "الحركة: e2-e4"; 
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
          // 1. القائمة الصغيرة اللي تختار منها اللون
          if (!_colorSelected)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("اختر لونك", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
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

          // 2. شاشة عرض الحركة الأفضل
          if (_colorSelected)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.greenAccent, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isAnalyzing)
                      const CircularProgressIndicator(color: Colors.greenAccent)
                    else
                      Text(
                        _bestMoveText,
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                      ),
                    const SizedBox(height: 15),
                    Text(
                      _isAnalyzing ? "جاري قراءة الرقعة..." : "أفضل حركة",
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    )
                  ],
                ),
              ),
            ),

          // 3. زر الإغلاق (فوق على اليمين)
          Positioned(
            top: 50,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.red,
              onPressed: () => FlutterOverlayWindow.closeOverlay(),
              child: const Icon(Icons.close, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }
}