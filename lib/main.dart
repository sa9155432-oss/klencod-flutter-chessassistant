import 'dart:async';
import 'dart:convert';
import 'dart:math' as m;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stockfish/stockfish.dart';

// ───────────── config: لو القراءة غلط، عدّل هنا فقط ─────────────
abstract class Cfg {
  static const inset = 0.15;       // قص داخل كل مربع (يتجنب أرقام/حروف الإحداثيات)
  static const grid = 16;          // دقة بصمة القطعة
  static const darkLum = 90;       // lum أقل من هذا = حبر (حدود/قطع سوداء)
  static const whiteLum = 205;     // lum أعلى من هذا + chroma واطي = حشوة قطعة بيضاء
  static const chroma = 28;
  static const whiteFillMin = 0.07;
  static const blackInkMin = 0.12;
  static const light = [240, 217, 181]; // FILL: لون المربع الفاتح من لقطة الشاشة
  static const dark = [181, 136, 99];   // FILL: لون المربع الغامق
  static const tol = 24;
  static const thinkMs = 900;
}

class Shot {
  Shot(this.w, this.h, this.px);
  final int w, h;
  final Uint8List px; // RGBA
}

class Cell {
  Cell(this.kind, this.sig);
  final int kind; // 0 فارغ, 1 أبيض, 2 أسود
  final List<double> sig;
}

bool _near(Shot s, int x, int y, List<int> c) {
  final p = (y * s.w + x) * 4;
  return (s.px[p] - c[0]).abs() <= Cfg.tol &&
      (s.px[p + 1] - c[1]).abs() <= Cfg.tol &&
      (s.px[p + 2] - c[2]).abs() <= Cfg.tol;
}

// البورد ياخذ كامل العرض: نلكي أول وآخر صف أغلبه ألوان مربعات
(double top, double sq)? findBoard(Shot s) {
  int top = -1, bot = -1;
  for (int y = 0; y < s.h; y += 2) {
    int hit = 0, n = 0;
    for (int x = 0; x < s.w; x += 6) {
      n++;
      if (_near(s, x, y, Cfg.light) || _near(s, x, y, Cfg.dark)) hit++;
    }
    if (hit / n > .5) { if (top < 0) top = y; bot = y; }
  }
  if (top < 0 || ((bot - top) - s.w).abs() > s.w * .08) return null;
  return (top.toDouble(), s.w / 8);
}

Cell readCell(Shot s, double ox, double oy, double sq) {
  final a = sq * Cfg.inset;
  final sz = (sq - 2 * a).floor();
  final x0 = (ox + a).round(), y0 = (oy + a).round();
  const n = Cfg.grid;
  final ink = List<double>.filled(n * n, 0), cnt = List<double>.filled(n * n, 0);
  int dark = 0, white = 0;
  for (int j = 0; j < sz; j++) {
    final bj = j * n ~/ sz;
    final rowBase = (y0 + j) * s.w + x0;
    for (int i = 0; i < sz; i++) {
      final p = (rowBase + i) * 4;
      final r = s.px[p], g = s.px[p + 1], b = s.px[p + 2];
      final lum = (r * 299 + g * 587 + b * 114) ~/ 1000;
      final k = bj * n + i * n ~/ sz;
      cnt[k]++;
      if (lum < Cfg.darkLum) { dark++; ink[k]++; }
      else if (lum > Cfg.whiteLum && (m.max(r, m.max(g, b)) - m.min(r, m.min(g, b))) < Cfg.chroma) { white++; }
    }
  }
  final tot = sz * sz;
  final kind = white / tot >= Cfg.whiteFillMin ? 1 : (dark / tot >= Cfg.blackInkMin ? 2 : 0);
  return Cell(kind, [for (int k = 0; k < n * n; k++) cnt[k] == 0 ? 0.0 : ink[k] / cnt[k]]);
}

// ───────────── قوالب القطع: تنتعلم من بداية اللعبة ─────────────
class Templates {
  Templates(this.t);
  final Map<String, List<double>> t;

  String toJson() => jsonEncode(t);
  static Templates fromJson(String s) => Templates((jsonDecode(s) as Map).map(
      (k, v) => MapEntry(k as String, (v as List).map((e) => (e as num).toDouble()).toList())));

  // index = rank*8+file (rank 0 = rank 1). الشاشة: صف r من فوق, عمود c من اليسار
  // أبيض تحت: file=c, rank=7-r | أسود تحت: file=7-c, rank=r
  static Templates? learn(List<Cell> cells, bool white) {
    const back = 'RNBQKBNR';
    final acc = <String, List<double>>{};
    final num = <String, int>{};
    for (int i = 0; i < 64; i++) {
      final r = i ~/ 8, c = i % 8;
      final f = white ? c : 7 - c, rk = white ? 7 - r : r;
      String want = '.';
      if (rk == 0) want = back[f];
      else if (rk == 1) want = 'P';
      else if (rk == 6) want = 'p';
      else if (rk == 7) want = back[f].toLowerCase();
      final wantKind = want == '.' ? 0 : (want == want.toUpperCase() ? 1 : 2);
      if (cells[i].kind != wantKind) return null; // مو وضع بداية
      if (want == '.') continue;
      final a = acc.putIfAbsent(want, () => List<double>.filled(Cfg.grid * Cfg.grid, 0));
      for (int k = 0; k < a.length; k++) a[k] += cells[i].sig[k];
      num[want] = (num[want] ?? 0) + 1;
    }
    return Templates({for (final e in acc.entries) e.key: [for (final v in e.value) v / num[e.key]!]});
  }

  List<String> read(List<Cell> cells, bool white) {
    final b = List<String>.filled(64, '.');
    for (int i = 0; i < 64; i++) {
      final c = cells[i];
      if (c.kind == 0) continue;
      final r = i ~/ 8, col = i % 8;
      final f = white ? col : 7 - col, rk = white ? 7 - r : r;
      String best = '?';
      double bd = double.infinity;
      for (final e in t.entries) {
        if ((e.key == e.key.toUpperCase()) != (c.kind == 1)) continue;
        double d = 0;
        for (int k = 0; k < e.value.length; k++) d += (e.value[k] - c.sig[k]).abs();
        if (d < bd) { bd = d; best = e.key; }
      }
      b[rk * 8 + f] = best;
    }
    return b;
  }
}

// ───────────── FEN + فحص صلاحية (Stockfish ينهار على وضع غير قانوني) ─────────────
bool _attacked(List<String> b, int sq, bool byWhite) {
  final f = sq % 8, r = sq ~/ 8;
  bool own(String p, String t) => byWhite ? p == t.toUpperCase() : p == t.toLowerCase();
  String at(int ff, int rr) => (ff < 0 || ff > 7 || rr < 0 || rr > 7) ? '' : b[rr * 8 + ff];
  final pr = byWhite ? r - 1 : r + 1;
  for (final df in [-1, 1]) { if (own(at(f + df, pr), 'p')) return true; }
  for (final d in [[1, 2], [2, 1], [-1, 2], [-2, 1], [1, -2], [2, -1], [-1, -2], [-2, -1]]) {
    if (own(at(f + d[0], r + d[1]), 'n')) return true;
  }
  for (final d in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]) {
    final diag = d[0] != 0 && d[1] != 0;
    for (int k = 1; k < 8; k++) {
      final p = at(f + d[0] * k, r + d[1] * k);
      if (p == '') break;
      if (p == '.') continue;
      if (own(p, 'q') || own(p, diag ? 'b' : 'r') || (k == 1 && own(p, 'k'))) return true;
      break;
    }
  }
  return false;
}

String? validate(List<String> b, String side) {
  if (b.contains('?')) return 'قراءة غلط، جرب مرة ثانية';
  if (b.where((x) => x == 'K').length != 1 || b.where((x) => x == 'k').length != 1) return 'قراءة غلط (الملوك)';
  for (int f = 0; f < 8; f++) {
    if ('Pp'.contains(b[f]) && b[f] != '.' || 'Pp'.contains(b[56 + f]) && b[56 + f] != '.') return 'قراءة غلط (بيدق بصف غلط)';
  }
  final wk = b.indexOf('K'), bk = b.indexOf('k');
  if ((wk % 8 - bk % 8).abs() <= 1 && (wk ~/ 8 - bk ~/ 8).abs() <= 1) return 'قراءة غلط (الملوك ملتصقين)';
  if (_attacked(b, side == 'w' ? bk : wk, side == 'w')) return 'قراءة غلط، جرب مرة ثانية';
  return null;
}

String toFen(List<String> b, String side) {
  final rows = <String>[];
  for (int r = 7; r >= 0; r--) {
    var s = '';
    var e = 0;
    for (int f = 0; f < 8; f++) {
      final p = b[r * 8 + f];
      if (p == '.') { e++; } else { if (e > 0) { s += '$e'; e = 0; } s += p; }
    }
    if (e > 0) s += '$e';
    rows.add(s);
  }
  var cs = '';
  if (b[4] == 'K' && b[7] == 'R') cs += 'K';
  if (b[4] == 'K' && b[0] == 'R') cs += 'Q';
  if (b[60] == 'k' && b[63] == 'r') cs += 'k';
  if (b[60] == 'k' && b[56] == 'r') cs += 'q';
  return '${rows.join('/')} $side ${cs.isEmpty ? '-' : cs} - 0 1';
}

// ───────────── الدماغ: يشتغل بالـ isolate الرئيسي ─────────────
class Brain {
  static const cap = MethodChannel('amr/capture');
  static Stockfish? _sf;
  static Templates? tpl;
  static bool busy = false;
  static Completer<String?>? _pending;

  static Future<void> init() async {
    final raw = (await SharedPreferences.getInstance()).getString('tpl');
    if (raw != null) tpl = Templates.fromJson(raw);
    FlutterOverlayWindow.overlayListener.listen(_onMsg);
  }

  static Future<void> resetCal() async {
    tpl = null;
    await (await SharedPreferences.getInstance()).remove('tpl');
  }

  static Future<Stockfish> _engine() async {
    var e = _sf;
    if (e != null) return e;
    e = Stockfish();
    _sf = e;
    e.stdout.listen((l) {
      if (l.startsWith('bestmove') && _pending != null && !_pending!.isCompleted) {
        _pending!.complete(l.split(' ')[1]);
      }
    });
    while (e.state.value != StockfishState.ready) {
      if (e.state.value == StockfishState.error) throw 'Stockfish error';
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return e;
  }

  static Future<String?> _best(String fen) async {
    final e = await _engine();
    _pending = Completer<String?>();
    e.stdin = 'ucinewgame';
    e.stdin = 'position fen $fen';
    e.stdin = 'go movetime ${Cfg.thinkMs}';
    return _pending!.future.timeout(const Duration(seconds: 8), onTimeout: () => null);
  }

  static Map<String, dynamic> _err(String s) => {'ok': false, 'err': s};

  static Future<void> _onMsg(dynamic raw) async {
    if (raw is! String) return;
    final msg = jsonDecode(raw);
    if (msg is! Map || msg['cmd'] != 'go' || busy) return;
    busy = true;
    Map<String, dynamic> reply;
    try {
      reply = await _analyze(msg['side'] as String);
    } catch (e) {
      reply = _err('$e');
    }
    busy = false;
    await FlutterOverlayWindow.shareData(jsonEncode(reply));
  }

  static Future<Map<String, dynamic>> _analyze(String side) async {
    final r = await cap.invokeMethod<Map>('grab');
    final shot = Shot(r!['w'] as int, r['h'] as int, r['px'] as Uint8List);
    final bd = findBoard(shot);
    if (bd == null) return _err('ما لكيت البورد. خلي اللعبة ظاهرة');
    final white = side == 'w';
    final cells = [
      for (var rr = 0; rr < 8; rr++)
        for (var c = 0; c < 8; c++) readCell(shot, c * bd.$2, bd.$1 + rr * bd.$2, bd.$2)
    ];
    if (tpl == null) {
      final t = Templates.learn(cells, white);
      if (t == null) return _err('أول مرة: اضغط وكل القطع بمكانها (بداية لعبة جديدة)');
      tpl = t;
      await (await SharedPreferences.getInstance()).setString('tpl', t.toJson());
    }
    final board = tpl!.read(cells, white);
    final why = validate(board, side);
    if (why != null) return _err(why);
    final bm = await _best(toFen(board, side));
    if (bm == null) return _err('المحرك ما رد');
    if (bm == '(none)') return _err('ما أكو نقلة (كش مات/تعادل)');
    final from = bm.substring(0, 2), to = bm.substring(2, 4);
    final piece = board[(from.codeUnitAt(1) - 49) * 8 + from.codeUnitAt(0) - 97].toUpperCase();
    return {'ok': true, 'from': from, 'to': to, 'piece': piece, 'promo': bm.length > 4 ? bm[4].toUpperCase() : ''};
  }
}

// ───────────── التطبيق الرئيسي ─────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Brain.init();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
    home: const Home(),
  ));
}

class Home extends StatelessWidget {
  const Home({super.key});

  Future<void> _start(BuildContext ctx) async {
    final sm = ScaffoldMessenger.of(ctx);
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      if (!(await FlutterOverlayWindow.requestPermission() ?? false)) return;
    }
    final ok = await Brain.cap.invokeMethod<bool>('start') ?? false;
    if (!ok) { sm.showSnackBar(const SnackBar(content: Text('لازم توافق على تسجيل الشاشة'))); return; }
    await FlutterOverlayWindow.showOverlay(
      height: 180, width: 300, // dp بالنسخ الحديثة؛ لو طلع صغير/كبير عدّل الرقمين
      alignment: OverlayAlignment.topCenter,
      enableDrag: true,
      flag: OverlayFlag.defaultFlag,
      positionGravity: PositionGravity.none,
      overlayTitle: 'amr',
      overlayContent: 'chess',
    );
    await Brain.cap.invokeMethod('toBack');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 22)),
              onPressed: () => _start(context),
              child: const Text('تشغيل القائمة', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: Brain.resetCal, child: const Text('إعادة المعايرة')),
          ]),
        ),
      );
}

// ───────────── القائمة العائمة ─────────────
@pragma('vm:entry-point')
void overlayMain() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
      home: const Panel(),
    ));

const _names = {'P': 'بيدق', 'N': 'حصان', 'B': 'فيل', 'R': 'قلعة', 'Q': 'وزير', 'K': 'ملك'};

class Panel extends StatefulWidget {
  const Panel({super.key});
  @override
  State<Panel> createState() => _PanelState();
}

class _PanelState extends State<Panel> {
  String? side;
  bool busy = false;
  Map? res;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FlutterOverlayWindow.overlayListener.listen((e) {
      if (e is! String) return;
      final j = jsonDecode(e);
      if (j is Map && j['ok'] != null && mounted) setState(() { busy = false; res = j; });
    });
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  void _go(String s) {
    setState(() { side = s; busy = true; res = null; });
    FlutterOverlayWindow.shareData(jsonEncode({'cmd': 'go', 'side': s}));
    Future.delayed(const Duration(seconds: 14), () {
      if (mounted && busy) setState(() { busy = false; res = {'ok': false, 'err': 'ما رد، جرب مرة ثانية'}; });
    });
  }

  Widget _btn(String label, String s, Color bg, Color fg) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: bg, foregroundColor: fg,
              side: side == s ? const BorderSide(color: Color(0xFF22C55E), width: 3) : null,
            ),
            onPressed: busy ? null : () => _go(s),
            child: Text(label),
          ),
        ),
      );

  Widget _body() {
    const big = TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white);
    if (busy) return const Center(child: CircularProgressIndicator());
    final r = res;
    if (r == null) return const Center(child: Text('اختار لونك', style: TextStyle(color: Colors.white70, fontSize: 16)));
    if (r['ok'] != true) return Center(child: Text('${r['err']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontSize: 14)));
    final castle = r['piece'] == 'K' && ((r['from'] as String).codeUnitAt(0) - (r['to'] as String).codeUnitAt(0)).abs() == 2;
    return Row(children: [
      ClipRRect(borderRadius: BorderRadius.circular(6),
          child: CustomPaint(size: const Size(100, 100), painter: MiniBoard(r, side == 'w'))),
      const SizedBox(width: 12),
      Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${r['from']} → ${r['to']}${r['promo'] != '' ? ' =${r['promo']}' : ''}', textDirection: TextDirection.ltr, style: big),
          const SizedBox(height: 4),
          Text('${_names[r['piece']] ?? ''}${castle ? ' (تبييت)' : ''}', style: const TextStyle(fontSize: 18, color: Color(0xFF22C55E))),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xEE10202F), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            SizedBox(
              height: 40,
              child: Row(children: [
                _btn('⚪ أبيض', 'w', Colors.white, Colors.black),
                _btn('⚫ أسود', 'b', const Color(0xFF2B2B2B), Colors.white),
                IconButton(onPressed: FlutterOverlayWindow.closeOverlay, icon: const Icon(Icons.close, color: Colors.white54)),
              ]),
            ),
            const SizedBox(height: 8),
            SizedBox(height: 100, child: _body()),
          ]),
        ),
      );
}

class MiniBoard extends CustomPainter {
  MiniBoard(this.mv, this.white);
  final Map mv;
  final bool white;

  // نفس اتجاه بورد اللعبة: أبيض تحت أو أسود تحت
  Offset _c(String sq, double s) {
    final f = sq.codeUnitAt(0) - 97, r = sq.codeUnitAt(1) - 49;
    return Offset(((white ? f : 7 - f) + .5) * s, ((white ? 7 - r : r) + .5) * s);
  }

  @override
  void paint(Canvas c, Size z) {
    final s = z.width / 8;
    final p = Paint();
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        p.color = (x + y) % 2 == 0 ? const Color(0xFFEFD9B5) : const Color(0xFFB58863);
        c.drawRect(Rect.fromLTWH(x * s, y * s, s, s), p);
      }
    }
    final a = _c(mv['from'], s), b = _c(mv['to'], s);
    p.color = const Color(0xCC22C55E);
    c.drawRect(Rect.fromCenter(center: a, width: s, height: s), p);
    p.color = const Color(0xCCF97316);
    c.drawRect(Rect.fromCenter(center: b, width: s, height: s), p);
    final u = (b - a) / (b - a).distance;
    final base = b - u * (s * .55), tip = b - u * (s * .1);
    final n = Offset(-u.dy, u.dx) * (s * .32);
    const red = Color(0xFFE11D48);
    c.drawLine(a, base, Paint()..color = red..strokeWidth = s * .26..strokeCap = StrokeCap.round);
    c.drawPath(
        Path()..moveTo(tip.dx, tip.dy)..lineTo((base + n).dx, (base + n).dy)..lineTo((base - n).dx, (base - n).dy)..close(),
        Paint()..color = red);
  }

  @override
  bool shouldRepaint(covariant MiniBoard o) => true;
}