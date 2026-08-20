/// 레시피 설명에 섞여 들어온 분류를 칩으로 쓸 수 있게 뽑아낸다.
///
/// 식약처 원본의 분류(RCP_WAY2·RCP_PAT2)와 해시태그가 `description` 안에
/// 줄 단위 문자열로 들어와 있다. 백엔드에 태그 테이블(`tags`/`recipe_tags`)이
/// 있지만 아직 레시피에 붙은 행이 없고 내려주는 API 도 없다 —
/// **태그 API 가 생기면 이 파싱을 지우고 그쪽을 쓴다.**
///
/// ```
/// 월계수잎과 통후추 등을 사용해 …
/// 조리방법: 굽기 | 요리종류: 반찬
/// 1인분 310.8kcal · 탄수화물 9.4g · …
/// 해시태그: 저염간장
/// ```
library;

class RecipeTags {
  const RecipeTags({required this.labels, required this.body});

  /// 칩으로 보여줄 분류. 원문 순서를 지킨다(조리방법 → 요리종류 → 해시태그).
  final List<String> labels;

  /// 분류·영양 줄을 걷어낸 본래 설명.
  final String body;

  static const _tagLinePrefixes = ['조리방법:', '요리종류:', '해시태그:'];

  /// 영양 줄은 칩이 아니라 숫자라 본문에서도 뺀다 — 상세 화면에 이미 스탯 타일이 있다.
  static final _nutritionLine = RegExp(r'kcal|탄수화물|단백질|나트륨');

  factory RecipeTags.parse(String description) {
    final labels = <String>[];
    final body = <String>[];

    for (final rawLine in description.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final prefix = _tagLinePrefixes
          .where((prefix) => line.startsWith(prefix))
          .firstOrNull;
      if (prefix != null) {
        // '조리방법: 굽기 | 요리종류: 반찬' 처럼 한 줄에 둘이 올 수 있다.
        for (final part in line.split('|')) {
          final value = part.contains(':')
              ? part.substring(part.indexOf(':') + 1).trim()
              : part.trim();
          if (value.isNotEmpty && !labels.contains(value)) labels.add(value);
        }
        continue;
      }

      if (_nutritionLine.hasMatch(line)) continue;
      body.add(line);
    }

    return RecipeTags(labels: labels, body: body.join('\n'));
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
