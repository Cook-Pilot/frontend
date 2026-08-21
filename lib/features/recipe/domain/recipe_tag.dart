/// 서버가 내려주는 태그. 축(axis)은 오지 않는다 —
/// 필터 의미(축 안 OR, 축 사이 AND)는 서버가 계산한다.
class RecipeTag {
  const RecipeTag({required this.code, required this.label});

  factory RecipeTag.fromJson(Map<String, dynamic> json) {
    return RecipeTag(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }

  final String code;
  final String label;
}
