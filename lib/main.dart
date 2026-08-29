import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_service.dart';
import 'agent_controller.dart';

void main() => runApp(const AiAgentApp());

class AiAgentApp extends StatelessWidget {
  const AiAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Agent',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _apiKeyCtrl = TextEditingController();
  final _taskCtrl = TextEditingController();
  final _modelCtrl = TextEditingController(text: 'llama-3.3-70b-versatile');
  final _log = <String>[];
  AgentController? _controller;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKeyCtrl.text = prefs.getString('groq_api_key') ?? '';
    _modelCtrl.text = prefs.getString('model') ?? _modelCtrl.text;
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_api_key', _apiKeyCtrl.text.trim());
    await prefs.setString('model', _modelCtrl.text.trim());
  }

  void _appendLog(String line) {
    setState(() => _log.add(line));
  }

  Future<void> _start() async {
    await _savePrefs();
    final controller = AgentController(
      ai: AiService(apiKey: _apiKeyCtrl.text.trim(), model: _modelCtrl.text.trim()),
      onLog: _appendLog,
    );

    final enabled = await controller.isAccessibilityEnabled();
    if (!enabled) {
      _appendLog('Лутфан хидмати Accessibility-ро дар танзимот фаъол кунед.');
      await controller.openAccessibilitySettings();
      return;
    }

    setState(() => _controller = controller);
    controller.start(_taskCtrl.text.trim());
  }

  void _stop() {
    _controller?.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final running = _controller?.isRunning ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Агенти AI (шахсӣ)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _apiKeyCtrl,
              decoration: const InputDecoration(labelText: 'Groq API key'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelCtrl,
              decoration: const InputDecoration(labelText: 'Модел (Groq)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _taskCtrl,
              decoration: const InputDecoration(labelText: 'Вазифа (масалан: "Wi-Fi-ро хомӯш кун")'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: running ? null : _start,
                    child: const Text('Оғоз'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: running ? _stop : null,
                    child: const Text('Бозист'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const Text('Гузориш:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (_, i) => Text(_log[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
