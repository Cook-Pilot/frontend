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
    '오븐',
    '고기',
    '기름',
    '가스',
    '불꽃',
    // This verb stem is intrinsically cooking-specific even when followed by
    // another Hangul syllable, as in "끓여야".
    '끓',
  ];

  // These cues are useful in natural questions such as "불 줄여?" and
  // "간 맞아?", but unrestricted substring matching would also classify
  // unrelated words such as "불가능" and "인간관계" as cooking context.
  static const _boundaryCookingContext = <String>['불', '간', '팬'];

  static const _planningObjectStems = <String>['계획', '일정', '각본', '전략'];
  static const _planningNonTargetSuffixes = <String>['대로'];

  static const _tasteSubjectStems = <String>[
    '국물',
    '소스',
    '양념',
    '찌개',
    '육수',
    '반찬',
    '음식',
    '요리',
    '이것',
    '이거',
    '이게',
    '이건',
    '간',
    '국',
  ];

  static const _tasteDegreeMarkers = <String>['너무', '조금', '약간', '좀'];

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
    final lowerTranscript = transcript.toLowerCase();

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
        _isExplicitCookingProblem(
          text,
          lowerTranscript,
          hasIngredientContext,
          ingredientTokens,
        ) ||
        (hasQuestionSignal &&
            (_hasCookingContext(text, lowerTranscript, dynamicContextTokens) ||
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

  bool _isExplicitCookingProblem(
    String text,
    String lowerTranscript,
    bool hasIngredientContext,
    Set<String> ingredientTokens,
  ) {
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

    if (_isSaltyProblem(text, lowerTranscript, ingredientTokens)) return true;
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
        (_hasCookingContext(text, lowerTranscript, const <String>[]) ||
            hasIngredientContext);
  }

  bool _isSaltyProblem(
    String text,
    String lowerTranscript,
    Set<String> ingredientTokens,
  ) {
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
    final predicates = _jjaPredicates(lowerTranscript).toList();
    if (predicates.any(
      (predicate) => _hasExplicitTasteExpression(lowerTranscript, predicate),
    )) {
      return true;
    }
    if (!_hasAny(text, contextMarkers)) return false;

    for (final predicate in predicates) {
      if (_isPlanningPredicateUse(
        lowerTranscript,
        predicate,
        ingredientTokens,
      )) {
        continue;
      }
      return true;
    }
    return false;
  }

  Iterable<RegExpMatch> _jjaPredicates(String lowerTranscript) sync* {
    for (final match in RegExp('짰|짠|짜').allMatches(lowerTranscript)) {
      if (!_isLexicalJja(lowerTranscript, match)) yield match;
    }
  }

  bool _isLexicalJja(String lowerTranscript, RegExpMatch match) {
    final surface = match.group(0)!;
    final previous = match.start == 0 ? '' : lowerTranscript[match.start - 1];
    final suffix = lowerTranscript.substring(match.end);

    if (surface == '짜') {
      return previous == '진' ||
          previous == '가' ||
          suffix.startsWith('증') ||
          suffix.startsWith('장') ||
          suffix.startsWith('릿');
    }
    if (surface == '짠') {
      return suffix.startsWith('돌이') ||
          suffix.startsWith('해') ||
          suffix.startsWith('하');
    }
    return false;
  }

  bool _isPlanningPredicateUse(
    String lowerTranscript,
    RegExpMatch predicate,
    Set<String> ingredientTokens,
  ) {
    var clauseStart = 0;
    final prefix = lowerTranscript.substring(0, predicate.start);
    for (final match in RegExp(r'[.!?。！？;；]').allMatches(prefix)) {
      clauseStart = match.end;
    }

    var objectIndex = -1;
    var objectEnd = -1;
    for (final stem in _planningObjectStems) {
      final markerIndex = lowerTranscript.lastIndexOf(stem, predicate.start);
      if (markerIndex >= clauseStart &&
          markerIndex > objectIndex &&
          _isPlanningTargetAt(lowerTranscript, markerIndex, stem)) {
        objectIndex = markerIndex;
        objectEnd = markerIndex + stem.length;
      }
    }
    if (objectIndex >= 0 &&
        !_startsNewFoodClause(
          lowerTranscript,
          objectEnd,
          predicate.start,
          ingredientTokens,
        )) {
      return true;
    }

    return _hasFollowingPlanningTarget(
      lowerTranscript,
      predicate,
      ingredientTokens,
    );
  }

  bool _isPlanningTargetAt(
    String text,
    int index,
    String stem, {
    bool allowAdverbialParticle = false,
  }) {
    final wordSuffix = _hangulWordSuffix(text, index + stem.length);
    if (wordSuffix.isEmpty) return true;
    if (_planningNonTargetSuffixes.any(wordSuffix.startsWith)) {
      return allowAdverbialParticle &&
          RegExp(r'^대로(?:은|는|도|만)?$').hasMatch(wordSuffix);
    }

    const primaryParticles = <String>[
      '에게서',
      '한테서',
      '에서',
      '으로',
      '에게',
      '한테',
      '부터',
      '까지',
      '이랑',
      '에',
      '의',
      '도',
      '만',
      '이',
      '가',
      '은',
      '는',
      '을',
      '를',
      '과',
      '와',
      '로',
      '랑',
    ];
    const auxiliaryParticles = <String>['은', '는', '도', '만'];
    final primary = _alternation(primaryParticles);
    final auxiliary = _alternation(auxiliaryParticles);
    return RegExp('^(?:$primary)(?:$auxiliary){0,2}\$').hasMatch(wordSuffix);
  }

  bool _startsNewFoodClause(
    String lowerTranscript,
    int objectEnd,
    int predicateStart,
    Set<String> ingredientTokens,
  ) {
    final between = lowerTranscript.substring(objectEnd, predicateStart);
    final connectorPattern = RegExp(
      r'(?:그런데|그러나|하지만|반면|보니까|보니|했는데|였는데|인데|는데|더니|다가|하고|지만|고)(?:\s+|[,，]\s*)',
    );
    RegExpMatch? lastConnector;
    for (final connector in connectorPattern.allMatches(between)) {
      lastConnector = connector;
    }
    if (lastConnector == null) return false;

    return _hasTasteSubject(
      between.substring(lastConnector.end),
      ingredientTokens,
    );
  }

  bool _hasFollowingPlanningTarget(
    String lowerTranscript,
    RegExpMatch predicate,
    Set<String> ingredientTokens,
  ) {
    if (!_isForwardPlanningPredicate(lowerTranscript, predicate)) return false;

    var clauseEnd = lowerTranscript.length;
    final punctuation = RegExp(
      r'[.!?。！？;；,，]',
    ).firstMatch(lowerTranscript.substring(predicate.end));
    if (punctuation != null) clauseEnd = predicate.end + punctuation.start;

    for (final stem in _planningObjectStems) {
      final objectIndex = lowerTranscript.indexOf(stem, predicate.end);
      if (objectIndex < 0 || objectIndex >= clauseEnd) continue;
      if (!_isPlanningTargetAt(
        lowerTranscript,
        objectIndex,
        stem,
        allowAdverbialParticle: true,
      )) {
        continue;
      }
      final between = lowerTranscript.substring(predicate.end, objectIndex);
      if (_startsWithConnectingEnding(between)) return false;
      if (!_hasTasteSubject(between, ingredientTokens)) return true;
    }
    return false;
  }

  bool _startsWithConnectingEnding(String value) {
    return RegExp(r'^\s*(?:데도|데|지만|고|면서)(?:\s+|[,，])').hasMatch(value);
  }

  bool _isForwardPlanningPredicate(
    String lowerTranscript,
    RegExpMatch predicate,
  ) {
    final surface = predicate.group(0)!;
    final wordSuffix = _hangulWordSuffix(lowerTranscript, predicate.end);
    if (surface == '짠') {
      return wordSuffix.isEmpty ||
          _planningObjectStems.any(wordSuffix.startsWith);
    }
    if (surface != '짰') return false;
    if (wordSuffix == '던') return true;
    return _planningObjectStems.any((stem) => wordSuffix.startsWith('던$stem'));
  }

  bool _hasTasteSubject(String value, Set<String> ingredientTokens) {
    final normalized = _normalize(value);
    final lower = value.toLowerCase();
    return _tasteSubjectStems.any(
          (subject) => subject.runes.length == 1
              ? _hasSingleKoreanWordToken(lower, subject)
              : normalized.contains(subject),
        ) ||
        _hasIngredientContext(value, ingredientTokens);
  }

  bool _hasExplicitTasteExpression(
    String lowerTranscript,
    RegExpMatch predicate,
  ) {
    final subjects = _alternation(_tasteSubjectStems);
    final degrees = _alternation(_tasteDegreeMarkers);
    final prefix = lowerTranscript.substring(0, predicate.start);
    return RegExp(
      '(^|[^가-힣a-z0-9])(?:$subjects)'
      '(?:이|가|은|는|도|만)?\\s*(?:(?:$degrees)\\s*)?\$',
    ).hasMatch(prefix);
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

  bool _hasCookingContext(
    String text,
    String lowerTranscript,
    Iterable<String> dynamicTokens,
  ) {
    return _staticCookingContext.any(text.contains) ||
        _boundaryCookingContext.any(
          (token) => _hasSingleKoreanWordToken(
            lowerTranscript,
            token,
            allowCopular: true,
          ),
        ) ||
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
      if (_hasSingleKoreanWordToken(lower, token)) return true;
    }
    return false;
  }

  bool _hasSingleKoreanWordToken(
    String lower,
    String token, {
    bool allowCopular = false,
  }) {
    final codePoint = token.runes.single;
    final finalConsonant = (codePoint - 0xAC00) % 28;
    final hasFinalConsonant = finalConsonant != 0;
    // ㄹ 받침은 모음 끝 명사와 마찬가지로 "로"를 쓴다(불로, 물로).
    final directional = !hasFinalConsonant || finalConsonant == 8 ? '로' : '으로';
    final primaryParticles = <String>{
      '$directional서',
      '$directional써',
      directional,
      '에게서',
      '한테서',
      '에서',
      '에게',
      '한테',
      '께서',
      '께',
      '부터',
      '까지',
      '처럼',
      '보다',
      '조차',
      '마저',
      '밖에',
      '마다',
      '만큼',
      '에',
      '의',
      '도',
      '만',
      if (hasFinalConsonant) ...[
        '이라도',
        '이라면',
        '이라고',
        '이랑',
        '이',
        '은',
        '을',
        '과',
        '아',
      ],
      if (!hasFinalConsonant) ...[
        '라도',
        '라면',
        '라고',
        '랑',
        '가',
        '는',
        '를',
        '와',
        '야',
      ],
    };
    final auxiliaryParticles = <String>{
      '이라도',
      '이라면',
      '라도',
      '라면',
      '부터',
      '까지',
      '조차',
      '마저',
      '은',
      '는',
      '도',
      '만',
    };
    final primaryPattern = _alternation(primaryParticles);
    final auxiliaryPattern = _alternation(auxiliaryParticles);
    final copularEndings = <String>{
      '인가요',
      '인가',
      '일까요',
      '일까',
      '입니다',
      if (hasFinalConsonant) ...[
        '이었나요',
        '이었어요',
        '이어도요',
        '이어도',
        '이면요',
        '이면',
        '이에요',
      ],
      if (!hasFinalConsonant) ...['였나요', '였어요', '여도요', '여도', '면요', '면', '예요'],
    };
    final copularPattern = _alternation(copularEndings);
    final tokenPattern = RegExp('(^|[^가-힣a-z0-9])${RegExp.escape(token)}');
    final particlePattern =
        '(?:(?:$primaryPattern)?(?:$auxiliaryPattern){0,2}요?)';
    final suffixAlternatives = allowCopular
        ? '(?:$copularPattern)|$particlePattern'
        : particlePattern;
    final suffixPattern = RegExp(
      '^(?:$suffixAlternatives)?'
      r'(?=$|[^가-힣a-z0-9])',
    );
    for (final candidate in tokenPattern.allMatches(lower)) {
      final wordSuffix = _hangulWordSuffix(lower, candidate.end);
      if (_isKnownSingleTokenLexeme(token, wordSuffix)) continue;
      if (suffixPattern.hasMatch(lower.substring(candidate.end))) return true;
    }
    return false;
  }

  bool _isKnownSingleTokenLexeme(String token, String wordSuffix) {
    final lexicalRoots = switch (token) {
      '불' => const ['만', '과', '의'],
      '파' => const ['도'],
      _ => const <String>[],
    };
    for (final root in lexicalRoots) {
      if (!wordSuffix.startsWith(root)) continue;
      final tail = wordSuffix.substring(root.length);
      if (tail.isEmpty ||
          RegExp(r'^(?:(?:이|가|은|는|을|를|의|도|만)){1,2}요?$').hasMatch(tail)) {
        return true;
      }
    }
    return false;
  }

  String _hangulWordSuffix(String value, int start) {
    return RegExp(r'^[가-힣]+').firstMatch(value.substring(start))?.group(0) ??
        '';
  }

  String _alternation(Iterable<String> values) {
    final sorted = values.toSet().toList()
      ..sort((left, right) => right.length.compareTo(left.length));
    return sorted.map(RegExp.escape).join('|');
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
    final durationParts = <({int start, int end, int seconds})>[];

    for (final match in RegExp(r'(\d+)\s*분').allMatches(source)) {
      final minutes = int.tryParse(match.group(1)!);
      if (minutes == null) continue;
      durationParts.add((
        start: match.start,
        end: match.end,
        seconds: minutes * 60,
      ));
    }
    for (final match in RegExp(r'(\d+)\s*초').allMatches(source)) {
      final parsedSeconds = int.tryParse(match.group(1)!);
      if (parsedSeconds == null) continue;
      durationParts.add((
        start: match.start,
        end: match.end,
        seconds: parsedSeconds,
      ));
    }

    for (final match in RegExp(r'반\s*분').allMatches(source)) {
      durationParts.add((start: match.start, end: match.end, seconds: 30));
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
      durationParts.add((
        start: quantityStart,
        end: match.end,
        seconds: minutes * 60,
      ));
    }

    if (durationParts.isEmpty) return null;
    durationParts.sort((left, right) => left.start.compareTo(right.start));

    final associatedParts = <int>{};
    final signalPattern = RegExp(
      _timerExtensionSignals.map(RegExp.escape).join('|'),
    );
    for (final signal in signalPattern.allMatches(source)) {
      int? beforeIndex;
      int? afterIndex;
      for (var index = 0; index < durationParts.length; index++) {
        final part = durationParts[index];
        if (part.end <= signal.start) beforeIndex = index;
        if (afterIndex == null && part.start >= signal.end) afterIndex = index;
      }

      if (beforeIndex != null &&
          _isExtensionSignalGap(
            source.substring(durationParts[beforeIndex].end, signal.start),
          )) {
        _addDurationClusterBefore(
          source,
          durationParts,
          beforeIndex,
          associatedParts,
        );
      }
      if (afterIndex != null &&
          _isExtensionSignalGap(
            source.substring(signal.end, durationParts[afterIndex].start),
          )) {
        _addDurationClusterAfter(
          source,
          durationParts,
          afterIndex,
          associatedParts,
        );
      }
    }

    if (associatedParts.isEmpty) return null;
    final seconds = associatedParts.fold<int>(
      0,
      (total, index) => total + durationParts[index].seconds,
    );
    return _boundedSeconds(seconds);
  }

  void _addDurationClusterBefore(
    String source,
    List<({int start, int end, int seconds})> parts,
    int anchorIndex,
    Set<int> associatedParts,
  ) {
    associatedParts.add(anchorIndex);
    for (var index = anchorIndex - 1; index >= 0; index--) {
      final gap = source.substring(parts[index].end, parts[index + 1].start);
      if (!_isDurationJoiner(gap)) break;
      associatedParts.add(index);
    }
  }

  void _addDurationClusterAfter(
    String source,
    List<({int start, int end, int seconds})> parts,
    int anchorIndex,
    Set<int> associatedParts,
  ) {
    associatedParts.add(anchorIndex);
    for (var index = anchorIndex + 1; index < parts.length; index++) {
      final gap = source.substring(parts[index - 1].end, parts[index].start);
      if (!_isDurationJoiner(gap)) break;
      associatedParts.add(index);
    }
  }

  bool _isExtensionSignalGap(String value) {
    final gap = value.replaceAll(RegExp(r'[\s,·+]'), '');
    return const {
      '',
      '만',
      '정도',
      '씩',
      '가량',
      '쯤',
      '만큼',
      '을',
      '를',
      '로',
      '으로',
    }.contains(gap);
  }

  bool _isDurationJoiner(String value) {
    final gap = value.replaceAll(RegExp(r'[\s,·+]'), '');
    return const {'', '하고', '과', '와', '및', '에'}.contains(gap);
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
