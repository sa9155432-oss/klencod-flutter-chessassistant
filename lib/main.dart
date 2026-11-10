// Language: Dart (Flutter 3.0+)
// Filename: main.dart
// Target: Android / iOS (Overlay & Companion Utility)
// Note: Implements a main control panel, a dedicated chess assistant view, 
//       and a floating selection menu for board-state processing (White/Black turn configuration).

import 'package:flutter/material.dart';

void main() {
  runApp(const ChessAssistantApp());
}

class ChessAssistantApp extends StatelessWidget {
  const ChessAssistantApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Checkmate Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueGrey[900],
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _cheatEngineActive = false;

  void _toggleCheatEngine() {
    setState(() {
      _cheatEngineActive = !_cheatEngineActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم - Assistant Panel'),
        backgroundColor: Colors.blueGrey[850],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey[700]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تشغيل الغش (Cheat Engine)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Switch(
                    value: _cheatEngineActive,
                    onChanged: (val) => _toggleCheatEngine(),
                    activeColor: Colors.tealAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_cheatEngineActive) ...[
              const Text(
                'الخيارات المتاحة:',
                style: TextStyle(fontSize: 16, color: Colors.tealAccent),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[800],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.sports_esports),
                label: const Text('لعبة الشطرنج (Checkmate Assistant)'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChessOverlayScreen(),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChessOverlayScreen extends StatefulWidget {
  const ChessOverlayScreen({Key? key}) : super(key: key);

  @override
  State<ChessOverlayScreen> createState() => _ChessOverlayScreenState();
}

class _ChessOverlayScreenState extends State<ChessOverlayScreen> {
  String _statusMessage = 'في انتظار النقلة الأولى...';
  bool _menuVisible = false;
  String _selectedRole = 'غير محدد';

  void _triggerBoardRead() {
    setState(() {
      _statusMessage = 'جاري قراءة الرقعة وتحليل القطع...';
    });
    // محاكاة عملية معالجة الرقعة
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _statusMessage = 'تم قراءة الرقعة بنجاح. حدد دورك (أبيض / أسود)';
        _menuVisible = true;
      });
    });
  }

  void _setPlayerColor(String color) {
    setState(() {
      _selectedRole = color;
      _statusMessage = 'تم ضبط الدور على: $_selectedRole. يتم حساب النقلة المثلى...';
      _menuVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لعبة الشطرنج - المساعد الذكي'),
        backgroundColor: Colors.blueGrey[850],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black45,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_statusMessage, style: const TextStyle(fontSize: 14)),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _triggerBoardRead,
                      tooltip: 'قراءة الرقعة',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.amber, width: 2),
                      color: const Color(0xFF262421),
                    ),
                    child: Stack(
                      children: [
                        // محاكاة لصفوف رقعة الشطرنج المعروضة في الصور
                        GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                          ),
                          itemCount: 64,
                          itemBuilder: (context, index) {
                            final isDark = (index ~/ 8 + index % 8) % 2 == 1;
                            return Container(
                              color: isDark ? const Color(0xFFB58863) : const Color(0xFFF0D9B5),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blueGrey[900],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('الدور الحالي: $_selectedRole'),
                    ElevatedButton(
                      onPressed: _triggerBoardRead,
                      child: const Text('قراءة الرقعة'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_menuVisible)
            Positioned(
              bottom: 80,
              left: MediaQuery.of(context).size.width / 2 - 80,
              child: Container(
                width: 160,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.tealAccent),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.circle, color: Colors.white, size: 16),
                      title: const Text('أبيض', style: TextStyle(color: Colors.white)),
                      onTap: () => _setPlayerColor('أبيض'),
                    ),
                    const Divider(height: 1, color: Colors.grey),
                    ListTile(
                      leading: const Icon(Icons.circle, color: Colors.black, size: 16),
                      title: const Text('أسود', style: TextStyle(color: Colors.white)),
                      onTap: () => _setPlayerColor('أسود'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
const double KSpacerSize = 0.0;
