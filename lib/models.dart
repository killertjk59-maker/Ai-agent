/// A single element found in the current screen's accessibility tree.
class ScreenNode {
  final String? text;
  final String? contentDescription;
  final String className;
  final bool clickable;
  final bool editable;
  final bool scrollable;
  final List<int> bounds; // [left, top, right, bottom]

  ScreenNode({
    required this.text,
    required this.contentDescription,
    required this.className,
    required this.clickable,
    required this.editable,
    required this.scrollable,
    required this.bounds,
  });

  factory ScreenNode.fromMap(Map<dynamic, dynamic> map) {
    return ScreenNode(
      text: map['text'] as String?,
      contentDescription: map['contentDescription'] as String?,
      className: map['className'] as String? ?? '',
      clickable: map['clickable'] as bool? ?? false,
      editable: map['editable'] as bool? ?? false,
      scrollable: map['scrollable'] as bool? ?? false,
      bounds: (map['bounds'] as List).map((e) => e as int).toList(),
    );
  }

  /// Compact one-line text representation fed to the LLM.
  /// Kept short and structured — token budget matters.
  String toPromptLine(int index) {
    final label = (text?.isNotEmpty ?? false)
        ? text
        : (contentDescription?.isNotEmpty ?? false)
            ? contentDescription
            : '';
    final flags = [
      if (clickable) 'clickable',
      if (editable) 'editable',
      if (scrollable) 'scrollable',
    ].join(',');
    final cx = ((bounds[0] + bounds[2]) / 2).round();
    final cy = ((bounds[1] + bounds[3]) / 2).round();
    return '[$index] $className "$label" ($flags) center=($cx,$cy)';
  }
}

/// A single action the agent decided to perform.
class AgentAction {
  final String type; // tap | input_text | scroll | back | wait | done
  final int? x;
  final int? y;
  final String? text;
  final String? direction; // up|down|left|right (for scroll)
  final String? reason; // short explanation, shown in the log

  AgentAction({
    required this.type,
    this.x,
    this.y,
    this.text,
    this.direction,
    this.reason,
  });

  factory AgentAction.fromJson(Map<String, dynamic> json) {
    return AgentAction(
      type: json['type'] as String,
      x: json['x'] as int?,
      y: json['y'] as int?,
      text: json['text'] as String?,
      direction: json['direction'] as String?,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (text != null) 'text': text,
        if (direction != null) 'direction': direction,
      };
}
