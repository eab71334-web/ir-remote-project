import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const svcUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const rxUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
const txUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

void main() => runApp(const MaterialApp(
    debugShowCheckedModeBanner: false, home: RemotePage()));

class RemotePage extends StatefulWidget {
  const RemotePage({super.key});
  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  Map<String, String> buttons = {}; // name -> "type:hex:bits"
  BluetoothCharacteristic? rx;
  BluetoothDevice? dev;
  String status = 'غير متصل';
  Completer<String>? learnWait;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('buttons');
    if (s != null) setState(() => buttons = Map<String, String>.from(jsonDecode(s)));
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('buttons', jsonEncode(buttons));
  }

  Future<void> connect() async {
    setState(() => status = 'جاري البحث...');
    try {
      await FlutterBluePlus.startScan(
          withServices: [Guid(svcUuid)], timeout: const Duration(seconds: 8));
      final r = await FlutterBluePlus.scanResults
          .firstWhere((l) => l.isNotEmpty)
          .timeout(const Duration(seconds: 8));
      await FlutterBluePlus.stopScan();
      dev = r.first.device;
      await dev!.connect();
      for (final s in await dev!.discoverServices()) {
        if (s.uuid.toString().toLowerCase() != svcUuid) continue;
        for (final c in s.characteristics) {
          final id = c.uuid.toString().toLowerCase();
          if (id == rxUuid) rx = c;
          if (id == txUuid) {
            await c.setNotifyValue(true);
            c.onValueReceived.listen((v) {
              final m = utf8.decode(v);
              if (m.startsWith('R:') && learnWait != null && !learnWait!.isCompleted) {
                learnWait!.complete(m.substring(2));
              }
            });
          }
        }
      }
      setState(() => status = 'متصل');
    } catch (e) {
      setState(() => status = 'فشل الاتصال');
    }
  }

  Future<void> send(String code) async {
    await rx?.write(utf8.encode('S:$code'), withoutResponse: false);
  }

  Future<void> learn() async {
    if (rx == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اتصل بالملحق أولاً')));
      return;
    }
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('اسم الزر'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('تعلّم'))
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    learnWait = Completer<String>();
    await rx!.write(utf8.encode('L'));
    if (!mounted) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
            content: Text('وجّه الريموت على الملحق واضغط الزر...')));
    try {
      final code = await learnWait!.future.timeout(const Duration(seconds: 15));
      buttons[name.trim()] = code;
      await _save();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ريموت الرسيفر - $status'), actions: [
        IconButton(icon: const Icon(Icons.bluetooth), onPressed: connect)
      ]),
      floatingActionButton:
          FloatingActionButton(onPressed: learn, child: const Icon(Icons.add)),
      body: buttons.isEmpty
          ? const Center(child: Text('اضغط + لإضافة زر'))
          : GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(12),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: buttons.entries
                  .map((e) => GestureDetector(
                        onLongPress: () async {
                          buttons.remove(e.key);
                          await _save();
                          setState(() {});
                        },
                        child: ElevatedButton(
                            onPressed: () => send(e.value), child: Text(e.key)),
                      ))
                  .toList(),
            ),
    );
  }
}
