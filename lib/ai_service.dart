import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

/// Talks to Groq's OpenAI-compatible chat/completions endpoint.
/// Get a free API key at https://console.groq.com/keys (no phone needed).
class AiService {
  final String apiKey;
  final String model;
  static const String endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  AiService({required this.apiKey, this.model = 'llama-3.3-70b-versatile'});

  /// Sends the task, screen tree and short history, gets back one AgentAction.
  Future<AgentAction> decideNextAction({
    required String task,
    required List<ScreenNode> nodes,
    required List<String> history,
  }) async {
    final nodeLines =
        nodes.asMap().entries.map((e) => e.value.toPromptLine(e.key)).join('\n');

    final systemPrompt = '''
You control an Android phone on behalf of its owner, one step at a time.
You will be given the user's task, a list of on-screen elements (with an
index and center coordinates), and the last few actions you already took.

Reply with STRICT JSON only, no prose, no markdown fences, matching:
{"type": "tap|input_text|scroll|back|wait|done",
 "x": <int, only for tap>, "y": <int, only for tap>,
 "text": <string, only for input_text>,
 "direction": "up|down|left|right, only for scroll",
 "reason": "<short reason, <15 words>"}

Use "done" once the task is complete. Use "wait" if the screen looks like
it is still loading. Never invent coordinates outside the given elements.
''';

    final userPrompt = '''
TASK: $task

RECENT ACTIONS:
${history.isEmpty ? '(none yet)' : history.join('\n')}

CURRENT SCREEN ELEMENTS:
$nodeLines
''';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'temperature': 0.2,
        'max_tokens': 300,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('NVIDIA API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'] as String;
    final cleaned = content.replaceAll('```json', '').replaceAll('```', '').trim();
    return AgentAction.fromJson(jsonDecode(cleaned) as Map<String, dynamic>);
  }
}
