import 'package:cookpilot/features/recipe/domain/seasonal_ingredients.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('열두 달 모두 제철 재료가 있다', () {
    for (var month = 1; month <= 12; month++) {
      expect(
        SeasonalIngredients.forMonth(month),
        isNotNull,
        reason: '$month월의 재료가 없다',
      );
    }
  });

  test('문장에 달과 재료가 함께 들어간다', () {
    expect(SeasonalIngredients.invitation(8), '무더운 8월엔 깻잎 요리 어떠세요?');
  });

  test('범위를 벗어난 달도 문장은 만든다', () {
    // 달 계산이 어긋나도 화면이 비지 않게 한다.
    expect(SeasonalIngredients.invitation(0), isNotEmpty);
    expect(SeasonalIngredients.forMonth(13), isNull);
  });
}
