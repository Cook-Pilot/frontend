import 'dart:math';

/// 태그를 권유 문장으로 바꾼다.
///
/// 홈에 `한식`·`안주` 같은 태그를 그대로 붙이면 목록의 이름표가 되지만, 권유가 되지는
/// 않는다. 넷플릭스가 "지금 뜨는 콘텐츠"라고 쓰지 "인기"라고만 쓰지 않는 것과 같다.
///
/// 태그마다 문장을 여러 개 두고 화면을 그릴 때 하나를 고른다. 같은 태그라도 열 때마다
/// 달라 보이므로, 카탈로그가 1,150건으로 고정돼 있어도 홈이 덜 정적으로 느껴진다.
class TagInvitations {
  const TagInvitations._();

  /// 태그 코드 → 권유 문장들. 코드가 여기 없으면 라벨로 기본 문장을 만든다.
  static const _phrases = <String, List<String>>{
    // 문화권
    'CUISINE_KOREAN': ['오늘은 한식 어때요?', '역시 집밥이죠', '든든한 한식 한 상'],
    'CUISINE_WESTERN': ['오늘은 양식이 당기나요?', '접시부터 예쁘게', '집에서 만드는 양식'],
    'CUISINE_CHINESE': ['중식이 당기는 날', '집에서 만드는 중화요리'],
    'CUISINE_JAPANESE': ['담백하게, 일식', '오늘은 일식 어때요?'],
    'CUISINE_ASIAN': ['향신료가 그리울 때', '오늘은 아시안 요리'],
    'CUISINE_FUSION': ['익숙한 재료, 낯선 조합', '섞을수록 맛있는'],

    // 용도
    'OCCASION_DIET': ['가볍게 먹고 싶은 날', '부담 없는 한 끼', '오늘은 가볍게 어때요?'],
    'OCCASION_SNACK': ['출출할 때 딱', '간단히 입이 심심할 때', '오늘의 간식'],
    'OCCASION_DRINKING_SNACK': ['한잔 하시나요?', '술 부르는 안주', '오늘 안주는 뭘로 할까요?'],
    'OCCASION_LATE_NIGHT': ['밤에 생각나는 그 맛', '야식이 당기는 밤'],
    'OCCASION_GUEST': ['손님 오시는 날', '상 차릴 일이 있다면'],
    'OCCASION_LUNCHBOX': ['내일 도시락 뭐 싸지', '식어도 맛있는'],
    'OCCASION_HOLIDAY': ['명절에 빠지면 섭섭한', '온 가족이 모이는 날'],
    'OCCASION_HANGOVER': ['속이 쓰린 아침에', '해장이 필요하다면'],

    // 음식 형태
    'DISH_SIDE': ['밑반찬 뭐 만들까요', '한 가지만 더 있으면'],
    'DISH_SOUP_STEW': ['국물이 필요한 날', '따뜻한 국물 한 그릇'],
    'DISH_RICE': ['밥 한 그릇으로 끝', '오늘은 한 그릇 요리'],
    'DISH_MAIN': ['오늘의 메인은', '이거 하나면 충분해요'],
    'DISH_DESSERT': ['마무리는 달콤하게', '후식까지 챙기는 날'],

    // 조리법
    'METHOD_BOIL': ['푹 끓여내는 요리', '끓이기만 하면 되는'],
    'METHOD_GRILL': ['노릇하게 구워서', '구우면 다 맛있죠'],
    'METHOD_STIR_FRY': ['센 불에 빠르게', '볶음 요리 모음'],
    'METHOD_STEAM': ['담백하게 쪄내는', '기름 없이 쪄서'],
    'METHOD_DEEP_FRY': ['바삭한 게 먹고 싶을 때', '튀김의 유혹'],
  };

  /// [tagCode] 의 권유 문장 하나. [seed] 를 주면 같은 값에 같은 문장이 나온다 —
  /// 화면이 다시 그려질 때마다 문구가 바뀌면 읽는 중에 흔들린다.
  static String forTag(String tagCode, String label, {int? seed}) {
    final candidates = _phrases[tagCode];
    if (candidates == null || candidates.isEmpty) {
      return '$label 요리 모아봤어요';
    }
    final random = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
    return candidates[random.nextInt(candidates.length)];
  }

  /// 문장을 준비해 둔 태그인지. 홈에 올릴 후보를 고를 때 쓴다 —
  /// 문장이 없는 태그는 기본 문장으로도 나가지만, 있는 쪽을 먼저 보여준다.
  static bool hasPhrase(String tagCode) => _phrases.containsKey(tagCode);

  /// 문장이 준비된 태그 코드 전부.
  static List<String> get curatedCodes => _phrases.keys.toList();
}
