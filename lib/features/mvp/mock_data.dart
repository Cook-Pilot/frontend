class Recipe {
  const Recipe({
    required this.title,
    required this.subtitle,
    required this.minutes,
    required this.difficulty,
    required this.rating,
    required this.reviewCount,
    required this.image,
    required this.tags,
    required this.ingredients,
    required this.steps,
    required this.memorySummary,
    this.badge,
  });

  final String title;
  final String subtitle;
  final int minutes;
  final String difficulty;
  final double rating;
  final int reviewCount;

  /// 이미지 URL. 빈 문자열이면 기본 플레이스홀더를 표시한다.
  final String image;

  /// 카드 위에 얹는 짧은 라벨 (나 맞춤, 인기 등). 없으면 미표시.
  final String? badge;

  final List<String> tags;
  final List<Ingredient> ingredients;
  final List<CookStep> steps;
  final String memorySummary;
}

class Ingredient {
  const Ingredient({required this.name, required this.amount, this.note = ''});

  final String name;
  final String amount;
  final String note;
}

class CookStep {
  const CookStep({
    required this.title,
    required this.description,
    required this.minutes,
  });

  final String title;
  final String description;
  final int minutes;
}

class RecipeMemory {
  const RecipeMemory({
    required this.title,
    required this.variant,
    required this.summary,
    required this.lastCooked,
    required this.rating,
    required this.image,
  });

  final String title;
  final String variant;
  final String summary;
  final String lastCooked;
  final double rating;
  final String image;
}

const tofuRecipe = Recipe(
  title: '두부 조림',
  subtitle: '짭짤한 간장 양념을 머금은 2인분 반찬',
  minutes: 20,
  difficulty: '쉬움',
  rating: 4.8,
  reviewCount: 1284,
  image: '',
  badge: '나 맞춤',
  tags: ['간장', '대파', '한식', '나 맞춤'],
  ingredients: [
    Ingredient(name: '두부', amount: '1모'),
    Ingredient(name: '대파', amount: '1/2대'),
    Ingredient(name: '간장', amount: '3큰술', note: '나 맞춤은 15% 줄임'),
    Ingredient(name: '고춧가루', amount: '1큰술'),
    Ingredient(name: '설탕', amount: '1큰술', note: '나 맞춤은 생략'),
  ],
  steps: [
    CookStep(
      title: '두부 손질',
      description: '두부의 물기를 제거하고 먹기 좋은 크기로 썰어요.',
      minutes: 5,
    ),
    CookStep(
      title: '양념 만들기',
      description: '간장, 고춧가루, 물을 섞어 양념장을 만들어요.',
      minutes: 3,
    ),
    CookStep(
      title: '중불로 졸이기',
      description: '양념을 넣고 두부가 양념을 흡수할 때까지 졸여요.',
      minutes: 4,
    ),
    CookStep(
      title: '완성·플레이팅',
      description: '대파를 올리고 불을 끈 뒤 1분간 뜸을 들여요.',
      minutes: 2,
    ),
  ],
  memorySummary: '간장 15% ↓ · 설탕 생략 · 최근 만족도 ★5',
);

const recipes = [
  tofuRecipe,
  Recipe(
    title: '마파두부',
    subtitle: '매콤한 돼지고기 두부 볶음',
    minutes: 25,
    difficulty: '보통',
    rating: 4.6,
    reviewCount: 872,
    image: '',
    tags: ['매콤', '돼지고기'],
    ingredients: [],
    steps: [],
    memorySummary: '다음엔 고추기름 1작은술 줄이기',
  ),
  Recipe(
    title: '두부 덮밥',
    subtitle: '15분 안에 끝나는 1인분 덮밥',
    minutes: 15,
    difficulty: '쉬움',
    rating: 4.5,
    reviewCount: 655,
    image: '',
    tags: ['1인분', '빠른 요리'],
    ingredients: [],
    steps: [],
    memorySummary: '밥 양 20% 줄이면 간이 더 맞음',
  ),
  Recipe(
    title: '두부 된장국',
    subtitle: '담백한 국물 요리',
    minutes: 18,
    difficulty: '쉬움',
    rating: 4.7,
    reviewCount: 934,
    image: '',
    tags: ['국물', '담백'],
    ingredients: [],
    steps: [],
    memorySummary: '다음엔 애호박을 먼저 넣기',
  ),
];

/// 홈 캐러셀용 요약 카드 데이터.
class RecipeCardData {
  const RecipeCardData({
    required this.title,
    required this.label,
    required this.image,
    required this.minutes,
    required this.rating,
  });

  final String title;
  final String label;
  final String image;
  final int minutes;
  final double rating;
}

const recentCooked = [
  RecipeCardData(
    title: '김치볶음밥',
    label: '나 맞춤',
    image: '',
    minutes: 15,
    rating: 4.7,
  ),
  RecipeCardData(
    title: '된장찌개',
    label: '기본',
    image: '',
    minutes: 25,
    rating: 4.8,
  ),
  RecipeCardData(
    title: '오일 파스타',
    label: '변형 1',
    image: '',
    minutes: 20,
    rating: 4.5,
  ),
];

const favorites = [
  RecipeCardData(
    title: '두부 조림',
    label: '나 맞춤',
    image: '',
    minutes: 20,
    rating: 4.8,
  ),
  RecipeCardData(
    title: '닭갈비',
    label: '기본',
    image: '',
    minutes: 35,
    rating: 4.9,
  ),
  RecipeCardData(
    title: '크림 파스타',
    label: '변형 1',
    image: '',
    minutes: 25,
    rating: 4.6,
  ),
];

const todayPicks = [
  RecipeCardData(
    title: '매콤 제육',
    label: '인기',
    image: '',
    minutes: 20,
    rating: 4.9,
  ),
  RecipeCardData(
    title: '두부 조림',
    label: '추천',
    image: '',
    minutes: 20,
    rating: 4.8,
  ),
  RecipeCardData(
    title: '치킨 샐러드',
    label: '가벼움',
    image: '',
    minutes: 10,
    rating: 4.4,
  ),
];

const categories = ['전체', '한식', '국물', '볶음', '파스타', '샐러드', '초스피드'];

const memories = [
  RecipeMemory(
    title: '두부 조림',
    variant: '나 맞춤 · 기본값',
    summary: '설탕 생략 · 간장 50% · 2분 추가',
    lastCooked: '오늘 2인분',
    rating: 5,
    image: '',
  ),
  RecipeMemory(
    title: '두부 조림',
    variant: '변형 1 · 매콤한 버전',
    summary: '고춧가루 2배 · 청양고추 추가',
    lastCooked: '7월 2일 2인분',
    rating: 4,
    image: '',
  ),
  RecipeMemory(
    title: '김치볶음밥',
    variant: '나 맞춤',
    summary: '김치 먼저 2분 볶기 · 설탕 반스푼',
    lastCooked: '어제 1인분',
    rating: 4.5,
    image: '',
  ),
];

const tasteOptions = [
  '마라탕',
  '김치찌개',
  '파스타',
  '초밥',
  '떡볶이',
  '삼겹살',
  '샐러드',
  '카레',
  '치킨',
  '냉면',
  '크림리조또',
  '제육볶음',
];
