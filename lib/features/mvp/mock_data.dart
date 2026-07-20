class Recipe {
  const Recipe({
    required this.title,
    required this.subtitle,
    required this.minutes,
    required this.difficulty,
    required this.rating,
    required this.tags,
    required this.ingredients,
    required this.steps,
    required this.memorySummary,
    required this.imageAsset,
  });

  final String title;
  final String subtitle;
  final int minutes;
  final String difficulty;
  final double rating;
  final List<String> tags;
  final List<Ingredient> ingredients;
  final List<CookStep> steps;
  final String memorySummary;
  final String imageAsset;
}

const recipeImageAssets = <String, String>{
  '두부 조림': 'assets/recipes/previews/tofu-braised.png',
  '김치볶음밥': 'assets/recipes/previews/kimchi-fried-rice.png',
  '된장찌개': 'assets/recipes/previews/soybean-paste-stew.png',
  '오일 파스타': 'assets/recipes/previews/oil-pasta.png',
  '닭갈비': 'assets/recipes/previews/dakgalbi.png',
  '크림 파스타': 'assets/recipes/previews/cream-pasta.png',
  '매콤 제육': 'assets/recipes/previews/spicy-pork.png',
  '치킨 샐러드': 'assets/recipes/previews/chicken-salad.png',
  '마파두부': 'assets/recipes/previews/mapo-tofu.png',
  '두부 덮밥': 'assets/recipes/previews/tofu-rice-bowl.png',
  '두부 된장국': 'assets/recipes/previews/tofu-soybean-soup.png',
};

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
  });

  final String title;
  final String variant;
  final String summary;
  final String lastCooked;
  final double rating;
}

const tofuRecipe = Recipe(
  title: '두부 조림',
  subtitle: '짭짤한 간장 양념을 머금은 2인분 반찬',
  minutes: 20,
  difficulty: '쉬움',
  rating: 4.8,
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
  imageAsset: 'assets/recipes/previews/tofu-braised.png',
);

const recipes = [
  tofuRecipe,
  Recipe(
    title: '김치볶음밥',
    subtitle: '잘 익은 김치와 달걀을 곁들인 한 그릇',
    minutes: 15,
    difficulty: '쉬움',
    rating: 4.8,
    tags: ['볶음밥', '빠른 요리'],
    ingredients: [],
    steps: [],
    memorySummary: '김치를 먼저 2분 볶으면 감칠맛이 좋아짐',
    imageAsset: 'assets/recipes/previews/kimchi-fried-rice.png',
  ),
  Recipe(
    title: '된장찌개',
    subtitle: '두부와 채소를 듬뿍 넣은 구수한 찌개',
    minutes: 30,
    difficulty: '보통',
    rating: 4.7,
    tags: ['국물', '한식'],
    ingredients: [],
    steps: [],
    memorySummary: '된장은 마지막에 조금 더 풀어 간 맞추기',
    imageAsset: 'assets/recipes/previews/soybean-paste-stew.png',
  ),
  Recipe(
    title: '오일 파스타',
    subtitle: '마늘 향을 살린 담백한 알리오 올리오',
    minutes: 20,
    difficulty: '쉬움',
    rating: 4.6,
    tags: ['파스타', '마늘'],
    ingredients: [],
    steps: [],
    memorySummary: '면수는 한 국자 남겨 농도 조절하기',
    imageAsset: 'assets/recipes/previews/oil-pasta.png',
  ),
  Recipe(
    title: '닭갈비',
    subtitle: '양배추와 고구마를 넣은 매콤한 철판 요리',
    minutes: 35,
    difficulty: '보통',
    rating: 4.7,
    tags: ['닭고기', '매콤'],
    ingredients: [],
    steps: [],
    memorySummary: '고구마는 얇게 썰어 먼저 익히기',
    imageAsset: 'assets/recipes/previews/dakgalbi.png',
  ),
  Recipe(
    title: '크림 파스타',
    subtitle: '버섯과 크림의 부드러운 풍미',
    minutes: 25,
    difficulty: '보통',
    rating: 4.5,
    tags: ['파스타', '크림'],
    ingredients: [],
    steps: [],
    memorySummary: '크림은 약불에서 졸여 분리되지 않게 하기',
    imageAsset: 'assets/recipes/previews/cream-pasta.png',
  ),
  Recipe(
    title: '매콤 제육',
    subtitle: '양파와 대파를 곁들인 매콤한 돼지불고기',
    minutes: 25,
    difficulty: '보통',
    rating: 4.8,
    tags: ['돼지고기', '매콤'],
    ingredients: [],
    steps: [],
    memorySummary: '고기는 센 불에 짧게 볶아 식감 살리기',
    imageAsset: 'assets/recipes/previews/spicy-pork.png',
  ),
  Recipe(
    title: '치킨 샐러드',
    subtitle: '구운 닭가슴살과 신선한 채소 한 접시',
    minutes: 20,
    difficulty: '쉬움',
    rating: 4.6,
    tags: ['샐러드', '가벼움'],
    ingredients: [],
    steps: [],
    memorySummary: '드레싱은 먹기 직전에 가볍게 버무리기',
    imageAsset: 'assets/recipes/previews/chicken-salad.png',
  ),
  Recipe(
    title: '마파두부',
    subtitle: '매콤한 돼지고기 두부 볶음',
    minutes: 25,
    difficulty: '보통',
    rating: 4.6,
    tags: ['매콤', '돼지고기'],
    ingredients: [],
    steps: [],
    memorySummary: '다음엔 고추기름 1작은술 줄이기',
    imageAsset: 'assets/recipes/previews/mapo-tofu.png',
  ),
  Recipe(
    title: '두부 덮밥',
    subtitle: '15분 안에 끝나는 1인분 덮밥',
    minutes: 15,
    difficulty: '쉬움',
    rating: 4.5,
    tags: ['1인분', '빠른 요리'],
    ingredients: [],
    steps: [],
    memorySummary: '밥 양 20% 줄이면 간이 더 맞음',
    imageAsset: 'assets/recipes/previews/tofu-rice-bowl.png',
  ),
  Recipe(
    title: '두부 된장국',
    subtitle: '담백한 국물 요리',
    minutes: 18,
    difficulty: '쉬움',
    rating: 4.7,
    tags: ['국물', '담백'],
    ingredients: [],
    steps: [],
    memorySummary: '다음엔 애호박을 먼저 넣기',
    imageAsset: 'assets/recipes/previews/tofu-soybean-soup.png',
  ),
];

Recipe recipeByTitle(String title) {
  return recipes.firstWhere(
    (recipe) => recipe.title == title,
    orElse: () => tofuRecipe,
  );
}

const memories = [
  RecipeMemory(
    title: '두부 조림',
    variant: '나 맞춤 · 기본값',
    summary: '설탕 생략 · 간장 50% · 2분 추가',
    lastCooked: '오늘 2인분',
    rating: 5,
  ),
  RecipeMemory(
    title: '두부 조림',
    variant: '변형 1 · 매콤한 버전',
    summary: '고춧가루 2배 · 청양고추 추가',
    lastCooked: '7월 2일 2인분',
    rating: 4,
  ),
  RecipeMemory(
    title: '김치볶음밥',
    variant: '나 맞춤',
    summary: '김치 먼저 2분 볶기 · 설탕 반스푼',
    lastCooked: '어제 1인분',
    rating: 4.5,
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
