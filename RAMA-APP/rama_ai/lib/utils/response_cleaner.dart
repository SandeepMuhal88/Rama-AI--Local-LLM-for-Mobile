// Strip model artefacts like <end|><|assistant|> from raw LLM output
String cleanLLMResponse(String text) {
  final patterns = [
    RegExp(r'<\|?end\|?>(\s*<\|?assistant\|?>)?', caseSensitive: false),
    RegExp(r'<\|?assistant\|?>',                  caseSensitive: false),
    RegExp(r'<\|?user\|?>',                       caseSensitive: false),
    RegExp(r'<\|?system\|?>',                     caseSensitive: false),
    RegExp(r'<\|?im_end\|?>',                     caseSensitive: false),
    RegExp(r'<\|?im_start\|?>',                   caseSensitive: false),
    RegExp(r'\[INST\]|\[/INST\]'),
    RegExp(r'<<SYS>>|<</SYS>>'),
  ];
  var cleaned = text;
  for (final p in patterns) {
    cleaned = cleaned.replaceAll(p, '');
  }
  return cleaned.trim();
}
