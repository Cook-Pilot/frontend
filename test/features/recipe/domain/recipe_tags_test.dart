import 'package:cookpilot/features/recipe/domain/recipe_tags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('한 줄에 둘이 붙어 있어도 각각 뽑는다', () {
    final tags = RecipeTags.parse(
      '월계수잎과 통후추 등을 사용해 깊은 맛을 냈어요.\n'
      '조리방법: 굽기 | 요리종류: 반찬\n'
      '1인분 310.8kcal · 탄수화물 9.4g · 나트륨 301.7mg\n'
      '해시태그: 저염간장',
    );

    expect(tags.labels, ['굽기', '반찬', '저염간장']);
    expect(tags.body, '월계수잎과 통후추 등을 사용해 깊은 맛을 냈어요.');
  });

  test('영양 줄은 칩에도 본문에도 넣지 않는다 — 상세에 스탯 타일이 따로 있다', () {
    final tags = RecipeTags.parse('담백해요.\n1인분 164.5g · 297.2kcal · 지방 17.6g');

    expect(tags.labels, isEmpty);
    expect(tags.body, '담백해요.');
  });

  test('분류가 없으면 설명을 그대로 둔다', () {
    final tags = RecipeTags.parse('가자미 대신 도다리를 넣으면 담백하다.');

    expect(tags.labels, isEmpty);
    expect(tags.body, '가자미 대신 도다리를 넣으면 담백하다.');
  });

  test('같은 값이 두 번 나와도 칩은 하나만 만든다', () {
    final tags = RecipeTags.parse('조리방법: 굽기\n해시태그: 굽기');

    expect(tags.labels, ['굽기']);
  });

  test('빈 설명도 견딘다', () {
    final tags = RecipeTags.parse('');

    expect(tags.labels, isEmpty);
    expect(tags.body, isEmpty);
  });
}
