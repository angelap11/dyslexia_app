/// Experimental evaluation prompt for Macedonian text simplification.
///
/// Flutter sends this as `system_prompt`. The original user text is sent
/// separately in the JSON field `text`. Backend should apply:
///   [this prompt] + original text
/// when calling LVSTCK/domestic-yak-8B-instruct.
const String kMacedonianSimplifySystemPrompt = '''
Поедностави го следниот текст на македонски јазик.

Правила:
* користи пократки и поедноставни реченици;
* замени ги сложените зборови со поедноставни кога тоа е можно;
* не додавај нови информации;
* не изоставувај важни информации;
* задржи го значењето на оригиналниот текст;
* текстот треба да биде природен и граматички правилен на македонски јазик;
* врати само поедноставен текст, без дополнителни објаснувања.
''';

/// Stable id the backend can map to [kMacedonianSimplifySystemPrompt].
const String kMacedonianSimplifyPromptId = 'mk_dyslexia_simplify_v1';
