import 'package:flutter/services.dart';
import 'ai_service.dart';
import 'models.dart';

/// Bridges Dart <-> the native AccessibilityService via a MethodChannel.
class AgentController {
  static const _channel = MethodChannel('ai_agent/accessibility');

  final AiService ai;
  final void Function(String line) onLog;
  bool _running = false;
  final List<String> _history = [];

  AgentController({required this.ai, required this.onLog});

  bool get isRunning => _running;

  Future<bool> isAccessibilityEnabled() async {
    final res = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
    return res ?? false;
  }

  Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  Future<void> start(String task, {int maxSteps = 25}) async {
    if (_running) return;
    _running = true;
    _history.clear();
    onLog('Агент оғоз шуд: "$task"');

    for (var step = 0; step < maxSteps && _running; step++) {
      try {
        final rawNodes = await _channel.invokeMethod<List<dynamic>>('captureScreen');
        if (rawNodes == null) {
          onLog('Хатогӣ: экран хонда нашуд (Accessibility Service фаъол аст?)');
          break;
        }
        final nodes = rawNodes
            .map((m) => ScreenNode.fromMap(Map<dynamic, dynamic>.from(m as Map)))
            .toList();

        final action = await ai.decideNextAction(
          task: task,
          nodes: nodes,
          history: _history,
        );

        onLog('Қадам ${step + 1}: ${action.type} — ${action.reason ?? ''}');

        if (action.type == 'done') {
          onLog('Вазифа анҷом ёфт.');
          break;
        }

        await _channel.invokeMethod('performAction', action.toMap());
        _history.add('${action.type}: ${action.reason ?? ''}');
        if (_history.length > 8) _history.removeAt(0);

        await Future.delayed(const Duration(milliseconds: 900));
      } catch (e) {
        onLog('Хатогӣ: $e');
        break;
      }
    }
    _running = false;
    onLog('Агент боздошта шуд.');
  }

  void stop() {
    _running = false;
  }
}
