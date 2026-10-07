import 'package:dyslexia_app/features/simplify/simplify_prompt.dart';
import 'package:dyslexia_app/features/simplify/text_simplification_config.dart';
import 'package:dyslexia_app/features/simplify/text_simplification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'TEXT_SIMPLIFY_BASE_URL=\n',
      isOptional: true,
    );
  });

  test('config defaults to mock when BASE_URL is empty', () {
    expect(TextSimplificationConfig.baseUrl, isEmpty);
    expect(TextSimplificationConfig.useMock, isTrue);
    expect(TextSimplificationConfig.simplifyUri, isNull);
    expect(TextSimplificationConfig.modelId, 'LVSTCK/domestic-yak-8B-instruct');
  });

  test('config uses HTTP when BASE_URL set and mock flag false', () {
    dotenv.loadFromString(
      envString:
          'TEXT_SIMPLIFY_BASE_URL=https://example.com\n'
          'TEXT_SIMPLIFY_USE_MOCK=false\n',
    );
    expect(TextSimplificationConfig.useMock, isFalse);
    expect(
      TextSimplificationConfig.simplifyUri?.toString(),
      'https://example.com/v1/simplify',
    );
  });

  test(
    'mock simplify returns labeled demo text and keeps meaning-ish content',
    () async {
      final service = TextSimplificationService();
      addTearDown(service.dispose);

      final result = await service.simplify('Денес времето е убаво.');
      expect(result.usedMock, isTrue);
      expect(result.simplifiedText, startsWith('【DEMO】'));
      expect(result.simplifiedText, contains('времето'));
    },
  );

  test('mock simplify rejects empty text', () async {
    final service = TextSimplificationService();
    addTearDown(service.dispose);

    expect(
      () => service.simplify('   '),
      throwsA(isA<TextSimplificationException>()),
    );
  });

  test('prompt id and system prompt are non-empty for backend contract', () {
    expect(kMacedonianSimplifyPromptId, isNotEmpty);
    expect(
      kMacedonianSimplifySystemPrompt,
      contains('Поедностави го следниот текст'),
    );
    expect(kMacedonianSimplifySystemPrompt, contains('македонски јазик'));
    expect(
      kMacedonianSimplifySystemPrompt,
      contains('не додавај нови информации'),
    );
  });
}
