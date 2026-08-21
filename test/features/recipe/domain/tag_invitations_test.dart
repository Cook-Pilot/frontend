import 'package:cookpilot/features/recipe/domain/tag_invitations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('준비된 태그는 권유 문장을 돌려준다', () {
    final phrase = TagInvitations.forTag('CUISINE_KOREAN', '한식', seed: 0);

    expect(phrase, isNotEmpty);
    expect(phrase, isNot(contains('CUISINE')));
  });

  test('같은 seed 면 같은 문장이 나온다', () {
    // 화면이 다시 그려질 때마다 문구가 바뀌면 읽는 중에 흔들린다.
    final first = TagInvitations.forTag('OCCASION_SNACK', '간식', seed: 7);
    final second = TagInvitations.forTag('OCCASION_SNACK', '간식', seed: 7);

    expect(first, second);
  });

  test('seed 를 바꾸면 문장이 갈린다', () {
    final phrases = {
      for (var seed = 0; seed < 30; seed++)
        TagInvitations.forTag('CUISINE_KOREAN', '한식', seed: seed),
    };

    expect(phrases.length, greaterThan(1));
  });

  test('문장을 준비하지 않은 태그는 라벨로 기본 문장을 만든다', () {
    final phrase = TagInvitations.forTag('OCCASION_UNKNOWN', '혼밥', seed: 1);

    expect(phrase, contains('혼밥'));
  });

  test('문장이 준비됐는지 알려준다', () {
    expect(TagInvitations.hasPhrase('CUISINE_KOREAN'), isTrue);
    expect(TagInvitations.hasPhrase('OCCASION_UNKNOWN'), isFalse);
  });

  test('준비한 문장은 모두 비어 있지 않다', () {
    for (final code in TagInvitations.curatedCodes) {
      expect(
        TagInvitations.forTag(code, '라벨', seed: 0),
        isNotEmpty,
        reason: '$code 의 문장이 비어 있다',
      );
    }
  });
}
