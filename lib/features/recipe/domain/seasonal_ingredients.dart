/// 이 달의 제철 재료.
///
/// 별도 데이터가 필요 없다 — 재료 이름으로 검색하면 그 재료를 쓰는 레시피가 나온다.
/// 태그를 새로 만들지 않은 이유이기도 하다. 제철은 해마다 같은 달에 돌아오므로
/// 태그로 붙여 두면 매년 다시 손봐야 한다.
///
/// 재료는 카탈로그에 실제로 있는 것으로 골랐다. 없는 재료를 넣으면 열이 비어 버린다.
class SeasonalIngredients {
  const SeasonalIngredients._();

  /// 월 → (재료, 그 달을 부르는 말).
  static const _byMonth = <int, (String, String)>{
    1: ('시금치', '한겨울'),
    2: ('시금치', '늦겨울'),
    3: ('달래', '봄이 오는'),
    4: ('두릅', '완연한 봄'),
    5: ('양파', '초여름'),
    6: ('감자', '유월'),
    7: ('애호박', '한여름'),
    8: ('깻잎', '무더운'),
    9: ('고구마', '초가을'),
    10: ('버섯', '가을'),
    11: ('배추', '김장철'),
    12: ('무', '한겨울'),
  };

  /// [month] 의 제철 재료. 범위를 벗어나면 null.
  static (String ingredient, String season)? forMonth(int month) =>
      _byMonth[month];

  /// '무더운 8월엔 깻잎 요리 어떠세요?' 같은 문장.
  static String invitation(int month) {
    final entry = _byMonth[month];
    if (entry == null) return '제철 재료로 만드는 요리';
    return '${entry.$2} $month월엔 ${entry.$1} 요리 어떠세요?';
  }
}
