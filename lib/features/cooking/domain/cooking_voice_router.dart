/// Voice intents that the cooking flow can handle without depending on STT,
/// networking, or a UI layer.
enum VoiceIntentType {
  next,
  previous,
  repeat,
  currentStep,
  startTimer,
  extendTimer,
  pauseTimer,
  resumeTimer,
  finish,
  exceptionQuestion,
  ignore,
}

/// Immutable result of routing one final STT transcript.
final class VoiceIntent {
  const VoiceIntent(this.type, {this.seconds = 0});

  final VoiceIntentType type;

  /// Requested timer extension. It is zero for every non-extension intent.
  final int seconds;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VoiceIntent && type == other.type && seconds == other.seconds;
  }

  @override
  int get hashCode => Object.hash(type, seconds);

  @override
  String toString() => 'VoiceIntent($type, seconds: $seconds)';
}

/// Pure classifier for final Korean cooking voice transcripts.
///
/// Explicit cooking problems and contextual questions are checked before the
/// local substring commands. This prevents a question such as
/// "다음에 소금 넣는 게 맞아?" from being mistaken for [VoiceIntentType.next].
///
/// The router only classifies. It does not answer exception questions or
/// mutate a cooking session.
final class CookingVoiceRouter {
  const CookingVoiceRouter();

  static const _questionSignals = <String>[
    '어떻게',
    '왜',
    '뭐',
    '무엇',
    '몇',
    '얼마나',
    '어때',
    '괜찮',
    '맞아',
    '맞나',
    '맞지',
    '될까',
    '되나',
    '되나요',
    '할까',
    '해야',
    '해도',
    '하면',
    '익었',
    '일까',
    '인가',
    '?',
    '？',
  ];

  static const _staticCookingContext = <String>[
    '온도',
    '시간',
    '타이머',
    '소스',
    '반죽',
    '재료',
    '양념',
    '냄비',
    '프라이팬',
    '팬',
    '오븐',
    '고기',
    '기름',
    '가스',
    '불꽃',
    // These one-syllable cooking cues are useful in natural questions such as
    // "불 줄여?" and "간 맞아?". The question AND-gate keeps plain
    // statements from being sent to the exception path.
    '불',
    '간',
    '끓',
  ];

  static const _finishPhrases = <String>[
    '조리완료',
    '요리완료',
    '조리끝',
    '요리끝',
    '다끝났',
    '전부끝났',
    '완성했',
    '완료했',
  ];

  static const _timerExtensionSignals = <String>['더', '추가', '연장', '늘려'];

  static const _koreanNativeNumberPrefixes = <String>{
    '열',
    '스물',
    '서른',
    '마흔',
    '쉰',
    '예순',
    '일흔',
    '여든',
    '아흔',
  };

  static const _koreanSingleMinuteValues = <String, int>{
    '구': 9,
    '팔': 8,
    '칠': 7,
    '육': 6,
    '오': 5,
    '사': 4,
    '삼': 3,
    '세': 3,
    '이': 2,
    '두': 2,
    '일': 1,
    '한': 1,
  };

  VoiceIntent route(
    String transcript, {
    required String recipeTitle,
    required Iterable<String> ingredientNames,
    required String currentStepInstruction,
  }) {
    final text = _normalize(transcript);
    if (text.isEmpty) return const VoiceIntent(VoiceIntentType.ignore);

    // Materialize ingredient tokens once so callers may safely pass a lazy
    // iterable and both exception gates see the same vocabulary.
    final ingredientTokens = <String>{
      for (final ingredient in ingredientNames)
        ..._contextTokens(ingredient, allowSingleKorean: true),
    };
    final hasIngredientContext = _hasIngredientContext(
      transcript,
      ingredientTokens,
    );
    final dynamicContextTokens = <String>{
      ..._contextTokens(recipeTitle),
      ..._contextTokens(currentStepInstruction),
    };

    final hasQuestionSignal = _hasQuestionSignal(text);
    final extensionSeconds = _extensionSeconds(transcript, text);
    final mutatingIntent = _mutatingIntent(text, extensionSeconds);

    // A tentative question must reach the coach before any local command that
    // mutates the cooking session. The command candidate keeps this gate
    // narrow: unrelated questions do not become cooking exceptions.
    if ((hasQuestionSignal && mutatingIntent != null) ||
        _isExplicitCookingProblem(text, hasIngredientContext) ||
        (hasQuestionSignal &&
            (_hasCookingContext(text, dynamicContextTokens) ||
                hasIngredientContext))) {
      return const VoiceIntent(VoiceIntentType.exceptionQuestion);
    }

    if (mutatingIntent != null) return mutatingIntent;
    if (_hasAny(text, const ['다시말', '반복', '한번더읽', '한번더말', '못들었'])) {
      return const VoiceIntent(VoiceIntentType.repeat);
    }
    if (_hasAny(text, const ['지금단계', '현재단계', '뭐해야', '어떻게해'])) {
      return const VoiceIntent(VoiceIntentType.currentStep);
    }

    return const VoiceIntent(VoiceIntentType.ignore);
  }

  bool _isExplicitCookingProblem(String text, bool hasIngredientContext) {
    if (_hasAny(text, const [
      // Fire, gas, burns, and cuts.
      '기름에불',
      '불이붙',
      '불붙',
      '불났',
      '불이났',
      '가스냄새',
      '연기가나',
      '연기나',
      '화상',
      '데였',
      '칼에베',
      '손을베',
      '베였',
      // Spoilage and unsafe meat.
      '상한',
      '곰팡',
      '이상한냄새',
      '변질',
      '생고기',
      '피가나',
      '속이빨',
      '닭이안익',
      '돼지고기안익',
      // Explicit cooking failures.
      '안끓',
      '끓지않',
      '물이끓지',
      '덜익',
      '안익',
      '설익',
      '싱거',
      '간이약',
      '눌어붙',
      '너무묽',
      '너무되',
      '뭉쳐',
      '분리됐',
      '분리되',
      '넘쳐',
      '부풀지않',
    ])) {
      return true;
    }

    if (_isSaltyProblem(text)) return true;
    if (_isMissingIngredientProblem(text, hasIngredientContext)) return true;

    final describesBurning = _hasAny(text, const [
      '타고있',
      '타는냄새',
      '탔어',
      '탔네',
      '타버',
      '그을',
    ]);
    return describesBurning &&
        (_hasCookingContext(text, const <String>[]) || hasIngredientContext);
  }

  bool _isSaltyProblem(String text) {
    if (_hasAny(text, const ['계획을짜', '일정을짜', '각본을짜', '전략을짜'])) {
      return false;
    }

    const contextMarkers = [
      '간이',
      '국이',
      '국물',
      '소스',
      '양념',
      '찌개',
      '육수',
      '반찬',
      '음식',
      '요리',
      '너무',
      '좀',
      '조금',
      '약간',
    ];
    if (!_hasAny(text, contextMarkers)) return false;
    if (_hasAny(text, const ['짠', '짰'])) return true;

    var index = text.indexOf('짜');
    while (index >= 0) {
      final previous = index == 0 ? '' : text[index - 1];
      final next = index + 1 >= text.length ? '' : text[index + 1];
      final isKnownFalsePositive =
          previous == '진' || previous == '가' || next == '증' || next == '장';
      if (!isKnownFalsePositive) return true;
      index = text.indexOf('짜', index + 1);
    }
    return false;
  }

  bool _isMissingIngredientProblem(String text, bool hasIngredientContext) {
    final hasMissingSignal = _hasAny(text, const [
      '없어',
      '없는데',
      '다썼',
      '떨어졌',
      '모자라',
      '부족',
    ]);
    if (!hasMissingSignal) return false;

    if (_hasAny(text, const ['재료가', '재료는', '재료를', '양념이', '소스가'])) {
      return true;
    }
    return hasIngredientContext;
  }

  bool _hasQuestionSignal(String text) => _questionSignals.any(text.contains);

  bool _hasCookingContext(String text, Iterable<String> dynamicTokens) {
    return _staticCookingContext.any(text.contains) ||
        dynamicTokens.any(text.contains);
  }

  bool _hasIngredientContext(String transcript, Iterable<String> tokens) {
    final normalized = _normalize(transcript);
    final lower = transcript.toLowerCase();
    for (final token in tokens) {
      if (token.runes.length >= 2) {
        if (normalized.contains(token)) return true;
        continue;
      }
      // A one-letter ingredient must begin a spoken word. This keeps
      // "물 더 넣어", "물이 없어" and "파를 썰어" while preventing a
      // recipe containing "파" from treating "파티 어때?" as cooking context.
      final pattern = RegExp(
        '(^|[^가-힣a-z0-9])${RegExp.escape(token)}'
        r'(?=$|[^가-힣a-z0-9]|[이가은는을를도만과와로에의])',
      );
      if (pattern.hasMatch(lower)) return true;
    }
    return false;
  }

  VoiceIntent? _mutatingIntent(String text, int? extensionSeconds) {
    if (text == '재개' ||
        _hasAny(text, const [
          '다시시작',
          '타이머재개',
          '재개해',
          '계속해',
          '타이머계속',
          '이어서진행',
        ])) {
      return const VoiceIntent(VoiceIntentType.resumeTimer);
    }

    if (_hasAny(text, const ['일시정지', '타이머정지', '타이머멈춰', '잠깐멈춰', '잠깐', '멈춰'])) {
      return const VoiceIntent(VoiceIntentType.pauseTimer);
    }

    if (extensionSeconds != null) {
      return VoiceIntent(
        VoiceIntentType.extendTimer,
        seconds: extensionSeconds,
      );
    }

    if (_hasAny(text, const [
      '타이머시작',
      '타이머켜',
      '시간재기',
      '조리시작',
      '요리시작',
      '시작했어',
      '시작했어요',
    ])) {
      return const VoiceIntent(VoiceIntentType.startTimer);
    }

    // An explicit whole-cook completion wins over a step-level "됐어".
    if (_hasAny(text, _finishPhrases)) {
      return const VoiceIntent(VoiceIntentType.finish);
    }

    if (_isNextCommand(text)) {
      return const VoiceIntent(VoiceIntentType.next);
    }
    if (text == '이전' || _hasAny(text, const ['이전으로', '이전단계', '전단계', '뒤로'])) {
      return const VoiceIntent(VoiceIntentType.previous);
    }
    return null;
  }

  bool _isNextCommand(String text) {
    if (_hasAny(text, const [
      '다음단계',
      '다음으로',
      '단계넘어가',
      '넘어가줘',
      '이단계다했어',
      '여기까지다했어',
    ])) {
      return true;
    }
    return const {'다음', '넘어가', '다했어', '됐어'}.contains(text);
  }

  int? _extensionSeconds(String transcript, String text) {
    if (!_hasAny(text, _timerExtensionSignals)) return null;

    final source = transcript.toLowerCase();
    var seconds = 0;
    var hasDuration = false;

    for (final match in RegExp(r'(\d+)\s*분').allMatches(source)) {
      final minutes = int.tryParse(match.group(1)!);
      if (minutes == null) continue;
      seconds += minutes * 60;
      hasDuration = true;
    }
    for (final match in RegExp(r'(\d+)\s*초').allMatches(source)) {
      final parsedSeconds = int.tryParse(match.group(1)!);
      if (parsedSeconds == null) continue;
      seconds += parsedSeconds;
      hasDuration = true;
    }

    if (text.contains('반분')) {
      seconds += 30;
      hasDuration = true;
    }

    // Keep a Korean quantity intact up to "분", including whitespace between
    // Sino-Korean parts. This lets "십 이 분" parse as twelve minutes instead
    // of matching its "이 분" suffix.
    final koreanMinutePattern = RegExp(
      r'(^|[^공영일이삼사오육칠팔구십백천만억조한두세네넷다섯여섯곱덟홉열스물른마흔쉰예순일흔여든아흔])'
      r'((?:[일이삼사오육칠팔구십백천만]+\s*)+|한|두|세)\s*분',
    );
    for (final match in koreanMinutePattern.allMatches(source)) {
      final quantityStart = match.start + match.group(1)!.length;
      if (_hasSpacedNativeNumberPrefix(source, quantityStart)) continue;

      final quantity = match.group(2)!.replaceAll(RegExp(r'\s+'), '');
      final minutes = _parseKoreanMinuteQuantity(quantity);
      if (minutes == null) continue;
      seconds += minutes * 60;
      hasDuration = true;
    }

    return hasDuration ? _boundedSeconds(seconds) : null;
  }

  int? _parseKoreanMinuteQuantity(String quantity) {
    final singleValue = _koreanSingleMinuteValues[quantity];
    if (singleValue != null) return singleValue;

    final compound = RegExp(
      r'^([이삼사오육칠팔구])?십([일이삼사오육칠팔구])?$',
    ).firstMatch(quantity);
    if (compound == null) return null;

    final tens = compound.group(1) == null
        ? 1
        : _koreanSingleMinuteValues[compound.group(1)!]!;
    final ones = compound.group(2) == null
        ? 0
        : _koreanSingleMinuteValues[compound.group(2)!]!;
    return (tens * 10) + ones;
  }

  bool _hasSpacedNativeNumberPrefix(String source, int quantityStart) {
    final prefix = source.substring(0, quantityStart).trimRight();
    final previousWord = RegExp(r'([가-힣]+)$').firstMatch(prefix)?.group(1);
    return previousWord != null &&
        _koreanNativeNumberPrefixes.contains(previousWord);
  }

  int _boundedSeconds(int seconds) => seconds.clamp(15, 600);

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  static Iterable<String> _contextTokens(
    String value, {
    bool allowSingleKorean = false,
  }) sync* {
    final lower = value.toLowerCase();
    for (final match in RegExp(r'[가-힣a-z0-9]+').allMatches(lower)) {
      final token = match.group(0)!;
      if (token.runes.length >= 2 ||
          (allowSingleKorean && RegExp(r'^[가-힣]$').hasMatch(token))) {
        yield token;
      }
    }
  }

  bool _hasAny(String value, Iterable<String> candidates) {
    return candidates.any(value.contains);
  }
}
