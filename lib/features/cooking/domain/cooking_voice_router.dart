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
    '김치',
    '음식',
    '요리',
    '이것',
    '이거',
    '이게',
    '이건',
    '맛',
    '간',
    '국',
  ];

  static const _tasteDegreeMarkers = <String>['너무', '조금', '약간', '좀'];

  static const _explicitFinishPhrases = <String>[
    '조리완료',
    '요리완료',
    '조리끝',
    '요리끝',
    '다끝났',
    '전부끝났',
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
    final recipeTokens = <String>{..._contextTokens(recipeTitle)};
    final tasteContextTokens = <String>{...ingredientTokens, ...recipeTokens};
    final dynamicContextTokens = <String>{
      ...recipeTokens,
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
          tasteContextTokens,
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

    if (_isUnsafeRawMeatProblem(text, lowerTranscript)) return true;
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

  bool _isUnsafeRawMeatProblem(String text, String source) {
    // Raw meat is an ordinary input while it is being prepared. Escalate only
    // an unsafe predicate or an actual raw-meat consumption event.
    if (RegExp(
      r'생고기(?:가|는|은|도|만)?(?:정말|너무)?'
      r'(?:위험(?:해|하다|한|하네|해서|해요|합니다)|안전하지않|괜찮지않)',
    ).hasMatch(text)) {
      return true;
    }
    return _hasUnsafeRawConsumption(source);
  }

  bool _hasUnsafeRawConsumption(String source) {
    final rawReferences = RegExp(
      r'생고기|(?:돼지고기|소고기|고기|닭)\s*(?:을|를)?\s*생으로',
    ).allMatches(source).toList();
    if (rawReferences.isEmpty) return false;

    final consumptions = _rawConsumptionMatches(source);
    for (final consumption in consumptions) {
      final rawReference = _nearestRawReference(
        source,
        rawReferences,
        consumption,
      );
      if (rawReference == null) continue;

      final segment = _consumptionSegment(source, rawReference, consumption);
      if (!_isSafeConsumptionEvent(
        source,
        consumption,
        start: segment.start,
        end: segment.end,
      )) {
        return true;
      }
    }
    return false;
  }

  Iterable<RegExpMatch> _rawConsumptionMatches(String source) {
    return RegExp(
      r'먹(?:었|어(?:도)?|으면|으려|을까|은|는\s*중|고)|'
      r'섭취(?:했|해|한)|삼켰',
    ).allMatches(source);
  }

  RegExpMatch? _nearestRawReference(
    String source,
    List<RegExpMatch> rawReferences,
    RegExpMatch consumption,
  ) {
    for (final rawReference in rawReferences.reversed) {
      if (rawReference.end > consumption.start) continue;
      final between = source.substring(rawReference.end, consumption.start);
      if (between.length > 120 ||
          _nextHardBoundaryOutsideQuotes(
                source,
                rawReference.end,
                end: consumption.start,
              ) !=
              null ||
          _crossesDetachedClause(between) ||
          _hasDifferentConsumptionTarget(between)) {
        return null;
      }
      return rawReference;
    }
    return null;
  }

  bool _crossesDetachedClause(String between) {
    for (final comma in RegExp(r'[,，]').allMatches(between)) {
      final before = between.substring(0, comma.start).trimRight();
      final after = between.substring(comma.end).trimLeft();
      final followsContrast = RegExp(
        r'(?:그렇지만|하지만|지만|그런데|그러나|반면)\s*$',
      ).hasMatch(before);
      final startsContrast = RegExp(
        r'^(?:그렇지만|하지만|그런데|그러나|반면)(?:\s|$)',
      ).hasMatch(after);
      if (!followsContrast && !startsContrast) return true;
    }
    return RegExp(r'(?:^|\s)(?:그리고|그러고|그다음)(?:\s|$)').hasMatch(between);
  }

  bool _hasDifferentConsumptionTarget(String between) {
    const adverbs = r'(?:[가-힣]{1,8}게|결국|그냥|바로|먼저|나중에|오늘|또)';
    final object = RegExp(
      '(?:^|[\\s,，])([가-힣a-z0-9]{1,20})\\s*(?:을|를|도)\\s*'
      '(?:$adverbs\\s*)*\$',
    ).firstMatch(between);
    return object != null;
  }

  ({int start, int end}) _consumptionSegment(
    String source,
    RegExpMatch rawReference,
    RegExpMatch consumption,
  ) {
    var sentenceEnd = source.length;
    final nextHardBoundary = _nextHardBoundaryOutsideQuotes(
      source,
      consumption.end,
    );
    if (nextHardBoundary != null) {
      sentenceEnd = nextHardBoundary;
    }

    final contrast = RegExp(r'그렇지만|하지만|그런데|그러나|반면|대신|지만');
    var start = rawReference.start;
    for (final previous in _rawConsumptionMatches(source)) {
      if (previous.start >= consumption.start) break;
      if (previous.end > rawReference.end) start = previous.end;
    }
    for (final boundary in contrast.allMatches(
      source.substring(rawReference.end, consumption.start),
    )) {
      final boundaryEnd = rawReference.end + boundary.end;
      if (boundaryEnd > start) start = boundaryEnd;
    }

    var end = sentenceEnd;
    final nextContrast = contrast.firstMatch(
      source.substring(consumption.end, sentenceEnd),
    );
    if (nextContrast != null) end = consumption.end + nextContrast.start;
    return (start: start, end: end);
  }

  int? _nextHardBoundaryOutsideQuotes(String source, int start, {int? end}) {
    var insideDoubleQuote = false;
    var insideSingleQuote = false;
    final limit = end ?? source.length;
    for (var index = 0; index < limit; index++) {
      final codeUnit = source.codeUnitAt(index);
      if (codeUnit == 0x201c) {
        insideDoubleQuote = true;
        continue;
      }
      if (codeUnit == 0x201d) {
        insideDoubleQuote = false;
        continue;
      }
      if (codeUnit == 0x22) {
        insideDoubleQuote = !insideDoubleQuote;
        continue;
      }
      if (codeUnit == 0x2018) {
        insideSingleQuote = true;
        continue;
      }
      if (codeUnit == 0x2019) {
        insideSingleQuote = false;
        continue;
      }
      if (index >= start &&
          !insideDoubleQuote &&
          !insideSingleQuote &&
          const {
            0x21,
            0x2e,
            0x3b,
            0x3f,
            0x3002,
            0xff01,
            0xff1b,
            0xff1f,
          }.contains(codeUnit)) {
        return index;
      }
    }
    return null;
  }

  bool _isSafeConsumptionEvent(
    String source,
    RegExpMatch consumption, {
    required int start,
    required int end,
  }) {
    final prefix = _normalize(source.substring(start, consumption.start));
    final suffix = _normalize(source.substring(consumption.end, end));
    final surface = _normalize(consumption.group(0)!);

    if (RegExp(r'(?:안|못)$').hasMatch(prefix)) return true;
    if (surface.startsWith('먹으려') &&
        (suffix.startsWith('했') ||
            RegExp(
              r'^다(?:가)?[가-힣a-z0-9]{0,12}'
              r'(?:(?:그만|말았|포기|취소)|(?:안|못)먹)',
            ).hasMatch(suffix))) {
      return true;
    }
    if (RegExp(
      r'^(?:적(?:이|은|도)?(?:전혀|절대|한번도|아예)?없|'
      r'(?:건|게|것(?:이|은)?)(?:전혀|절대|아예)?아니)',
    ).hasMatch(suffix)) {
      return true;
    }
    if (RegExp(
      r'^(?:어)?[.!?。！？;；]?[”"’]?(?:라고|라는|다고|다는)(?:'
      r'(?:말)?한?(?:건|게|것(?:이|은)?)|'
      r'말(?:은|이|을)?(?:사실이)?)(?:전혀|절대|아예)?아니',
    ).hasMatch(suffix)) {
      return true;
    }
    return _hasCompletedPreparation(prefix);
  }

  bool _hasCompletedPreparation(String prefix) {
    final prepared = RegExp(
      r'(?:익혀|익힌|구워|구운|볶아|볶은|삶아|삶은|데쳐|데친|'
      r'조리해|조리한|요리해|요리한)',
    );
    for (final preparation in prepared.allMatches(prefix)) {
      final before = prefix.substring(0, preparation.start);
      if (RegExp(r'(?:(?:안|못)다?|덜|미처)$').hasMatch(before)) continue;
      final gap = prefix.substring(preparation.end);
      if (gap.length <= 12 &&
          RegExp(r'^[가-힣a-z0-9]*$').hasMatch(gap) &&
          !RegExp(
            r'(?:안|못|않|말|척|예정|야|려고|필요|'
            r'줄(?:알|착각|믿)|것으로(?:알|착각|믿)|것같|'
            r'듯(?:싶|하)|거라(?:고)?(?:알|생각|착각|믿))',
          ).hasMatch(gap)) {
        return true;
      }
    }
    return false;
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
    ];
    final predicates = _jjaPredicates(
      lowerTranscript,
      ingredientTokens,
    ).toList();
    if (predicates.any(
      (predicate) => _hasExplicitTasteExpression(
        lowerTranscript,
        predicate,
        ingredientTokens,
      ),
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

  Iterable<RegExpMatch> _jjaPredicates(
    String lowerTranscript,
    Set<String> ingredientTokens,
  ) sync* {
    for (final match in RegExp(
      r'짭(?:니다|니까)|짰|짠|짜',
    ).allMatches(lowerTranscript)) {
      if (!_isLexicalJja(lowerTranscript, match, ingredientTokens)) {
        yield match;
      }
    }
  }

  bool _isLexicalJja(
    String lowerTranscript,
    RegExpMatch match,
    Set<String> ingredientTokens,
  ) {
    final surface = match.group(0)!;
    final wordPrefix = _hangulWordPrefix(lowerTranscript, match.start);
    final wordSuffix = _hangulWordSuffix(lowerTranscript, match.end);
    final prefix = lowerTranscript.substring(0, match.start);
    final hasTasteLead = _hasTasteLead(prefix, ingredientTokens);

    if (surface == '짜') {
      if (!_isJjaPresentEnding(wordSuffix)) return true;
      if (_isJjaCreationImperative(lowerTranscript, match) && !hasTasteLead) {
        return true;
      }
    }
    if (surface == '짠') {
      if (_isJjaCreationAttributive(
        lowerTranscript,
        match,
        hasTasteLead: hasTasteLead,
      )) {
        return true;
      }
      if (wordSuffix.startsWith('돌이') ||
          wordSuffix.startsWith('해') ||
          wordSuffix.startsWith('하')) {
        return true;
      }
    }
    if (surface.startsWith('짭')) {
      final isComposableFormalEnding = surface == '짭니다' && wordSuffix == '만';
      if (wordSuffix.isNotEmpty && !isComposableFormalEnding) return true;
    }

    if (wordPrefix.isEmpty) return false;
    return !_tasteDegreeMarkers.any(wordPrefix.endsWith) && !hasTasteLead;
  }

  bool _isJjaCreationAttributive(
    String lowerTranscript,
    RegExpMatch predicate, {
    required bool hasTasteLead,
  }) {
    if (hasTasteLead ||
        _hangulWordSuffix(lowerTranscript, predicate.end).isNotEmpty) {
      return false;
    }
    final localPrefix = lowerTranscript.substring(0, predicate.start);
    final subject = RegExp(r'([가-힣]+)\s*$').firstMatch(localPrefix)?.group(1);
    if (subject == null || !RegExp(r'(?:이|가|은|는)$').hasMatch(subject)) {
      return false;
    }
    return RegExp(
      r'^\s+[가-힣]+',
    ).hasMatch(lowerTranscript.substring(predicate.end));
  }

  bool _isJjaPresentEnding(String wordSuffix) {
    // Match productive adjective/verb endings, not nouns that merely start
    // with the same syllable (for example, "짜임새").
    return RegExp(
      r'^(?:요|다|서(?:요)?|고(?:요)?|지만(?:요)?|니까(?:요)?|면(?:요)?|게|'
      r'지(?:요)?|죠|네(?:요)?|잖아(?:요)?|겠(?:다|어(?:요)?)?|'
      r'줘(?:요)?|주세요|주라|려고|려면|면서|도록|는데(?:요)?|도|거나|'
      r'져(?:요)?|졌(?:어(?:요)?|다|네(?:요)?|는데(?:요)?|지만(?:요)?|고|'
      r'습니다|습니까)|더라(?:고(?:요)?)?|던데(?:요)?|더니|대요|'
      r'구나(?:요)?|다고(?:요)?)?$',
    ).hasMatch(wordSuffix);
  }

  bool _isJjaCreationImperative(String lowerTranscript, RegExpMatch predicate) {
    return RegExp(
      r'^\s*(?:줘(?:요)?|주세요|주라)(?=$|[^가-힣a-z0-9])',
    ).hasMatch(lowerTranscript.substring(predicate.end));
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
          _isPlanningTargetAt(
            lowerTranscript,
            markerIndex,
            stem,
            beforeIndex: predicate.start,
          )) {
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
    int? beforeIndex,
  }) {
    final suffixStart = index + stem.length;
    final suffixSource = beforeIndex == null
        ? text.substring(suffixStart)
        : text.substring(suffixStart, beforeIndex);
    // STT may omit spaces around a particle or degree marker. Inspect only
    // the morphology attached before this predicate so "일정을좀짜" remains
    // a plan while adjective forms such as "일정하게" fail closed.
    final wordSuffix =
        RegExp(r'^[가-힣]+').firstMatch(suffixSource)?.group(0) ?? '';
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
    final degree = _alternation(_tasteDegreeMarkers);
    final particleSequence = '(?:$primary)(?:$auxiliary){0,2}';
    final degreeSequence = '(?:$degree)(?:더)?';
    const attachedAdverbial = r'[가-힣]{1,8}(?:게|히|으로|로)';
    return RegExp(
      '^(?:$degreeSequence|'
      '$particleSequence(?:$degreeSequence)?|'
      '$particleSequence(?:$attachedAdverbial){1,2}'
      '(?:$degreeSequence)?)\$',
    ).hasMatch(wordSuffix);
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
    Set<String> ingredientTokens,
  ) {
    return _hasTasteLead(
      lowerTranscript.substring(0, predicate.start),
      ingredientTokens,
    );
  }

  bool _hasTasteLead(String prefix, Set<String> ingredientTokens) {
    final subjects = _alternation({..._tasteSubjectStems, ...ingredientTokens});
    final degrees = _alternation(_tasteDegreeMarkers);
    return RegExp(
      '(^|[^가-힣a-z0-9])(?:$subjects)'
      '(?:(?:이|가|은|는|도|만)){0,2}\\s*'
      '(?:(?:$degrees)\\s*)?\$',
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
        if (RegExp(r'^[가-힣]+$').hasMatch(token)) {
          if (_hasMultiKoreanContextToken(lower, token)) return true;
        } else if (normalized.contains(token)) {
          return true;
        }
        continue;
      }
      // A one-letter ingredient must begin a spoken word. This keeps
      // "물 더 넣어", "물이 없어" and "파를 썰어" while preventing a
      // recipe containing "파" from treating "파티 어때?" as cooking context.
      if (_hasSingleKoreanWordToken(lower, token)) return true;
    }
    return false;
  }

  bool _hasMultiKoreanContextToken(String lower, String token) {
    for (final candidate in RegExp(RegExp.escape(token)).allMatches(lower)) {
      final joinedPrefix = _hangulWordPrefix(lower, candidate.start);
      if (joinedPrefix.isNotEmpty &&
          !_hasAllowedSingleTokenCollisionPrefix(lower, candidate.start)) {
        continue;
      }

      final wordSuffix = _hangulWordSuffix(lower, candidate.end);
      if (wordSuffix.isNotEmpty) {
        final particleEnd = _koreanNominalParticleEnd(token, wordSuffix);
        if (particleEnd != null) {
          final continuation = wordSuffix.substring(particleEnd);
          final followingText = lower.substring(
            candidate.end + wordSuffix.length,
          );
          if (continuation == '요' ||
              _isIngredientCookingContinuation(continuation)) {
            return true;
          }
          if (continuation.isEmpty &&
              (_isIngredientCookingContinuation(followingText) ||
                  RegExp(r'^\s*(?:요\s*)?[?？]').hasMatch(followingText))) {
            return true;
          }
        }
        if (_isIngredientCookingContinuation(wordSuffix)) return true;
        continue;
      }

      if (_isIngredientCookingContinuation(lower.substring(candidate.end))) {
        return true;
      }
    }
    return false;
  }

  int? _koreanNominalParticleEnd(String token, String suffix) {
    final patterns = _koreanNounSuffixPatterns(token);
    return RegExp(
      '^(?:${patterns.primary})(?:${patterns.auxiliary}){0,2}',
    ).firstMatch(suffix)?.end;
  }

  ({String primary, String auxiliary, String copular})
  _koreanNounSuffixPatterns(String token) {
    final finalConsonant = (token.runes.last - 0xAC00) % 28;
    final hasFinalConsonant = finalConsonant != 0;
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
    const auxiliaryParticles = <String>{
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
    return (
      primary: _alternation(primaryParticles),
      auxiliary: _alternation(auxiliaryParticles),
      copular: _alternation(copularEndings),
    );
  }

  bool _isIngredientCookingContinuation(String value) {
    final continuation = value.replaceFirst(RegExp(r'^[\s,，]+'), '');
    return RegExp(
      r'^(?:(?:더|좀|조금|약간|많이|적게|얼마나|어떻게|다|전부|모두|'
      r'이미|거의|완전히)\s*)*'
      r'(?:넣|추가|빼|제외|사용|준비|손질|썰|다듬|씻|볶|굽|구우|'
      r'익|삶|데치|끓|섞|갈|다지|자르|먹|양념|없|부족|모자라|'
      r'떨어졌|다썼|상했|상한|탔|짜|싱거|괜찮|어때)',
    ).hasMatch(continuation);
  }

  bool _hasSingleKoreanWordToken(
    String lower,
    String token, {
    bool allowCopular = false,
  }) {
    final patterns = _koreanNounSuffixPatterns(token);
    final tokenPattern = RegExp('(^|[^가-힣a-z0-9])${RegExp.escape(token)}');
    final particlePattern =
        '(?:(?:${patterns.primary})?(?:${patterns.auxiliary}){0,2}요?)';
    final suffixAlternatives = allowCopular
        ? '(?:${patterns.copular})|$particlePattern'
        : particlePattern;
    final suffixPattern = RegExp(
      '^(?:$suffixAlternatives)?'
      r'(?=$|[^가-힣a-z0-9])',
    );
    if (_hasStrongSingleTokenCollisionContext(lower, token)) return true;
    for (final candidate in tokenPattern.allMatches(lower)) {
      final wordSuffix = _hangulWordSuffix(lower, candidate.end);
      if (_isKnownSingleTokenLexeme(token, wordSuffix)) continue;
      if (suffixPattern.hasMatch(lower.substring(candidate.end))) return true;
    }
    return false;
  }

  List<String> _singleTokenLexicalRoots(String token) {
    return switch (token) {
      '불' => const ['만', '과', '의'],
      '파' => const ['도'],
      _ => const <String>[],
    };
  }

  bool _isKnownSingleTokenLexeme(String token, String wordSuffix) {
    for (final root in _singleTokenLexicalRoots(token)) {
      if (!wordSuffix.startsWith(root)) continue;
      final tail = wordSuffix.substring(root.length);
      if (tail.isEmpty ||
          RegExp(r'^(?:(?:이|가|은|는|을|를|의|도|만)){1,2}요?$').hasMatch(tail)) {
        return true;
      }
    }
    return false;
  }

  bool _hasStrongSingleTokenCollisionContext(String lower, String token) {
    final lexicalRoots = _singleTokenLexicalRoots(token);
    if (lexicalRoots.isEmpty) return false;

    for (final candidate in RegExp(RegExp.escape(token)).allMatches(lower)) {
      if (!_hasAllowedSingleTokenCollisionPrefix(lower, candidate.start)) {
        continue;
      }
      final suffix = lower.substring(candidate.end);
      for (final lexicalRoot in lexicalRoots) {
        if (!suffix.startsWith(lexicalRoot)) continue;
        final continuation = suffix
            .substring(lexicalRoot.length)
            .replaceFirst(RegExp(r'^[\s,，]+'), '');
        if (_isStrongSingleTokenCookingContinuation(
          token,
          lexicalRoot,
          continuation,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasAllowedSingleTokenCollisionPrefix(String lower, int tokenStart) {
    final prefix = lower.substring(0, tokenStart);
    var clauseStart = 0;
    for (final boundary in RegExp(r'[.!?。！？;；]').allMatches(prefix)) {
      clauseStart = boundary.end;
    }
    final rawClausePrefix = prefix.substring(clauseStart);
    final clausePrefix = rawClausePrefix.replaceAll(RegExp(r'[\s,，]+'), '');
    if (clausePrefix.isEmpty) return true;
    final separatedPrefix = RegExp(r'[\s,，]$').hasMatch(rawClausePrefix);
    const unambiguousMarkers = <String>[
      '지금',
      '이제',
      '현재',
      '우선',
      '먼저',
      '여기',
      '이거',
      '이것',
      '그거',
      '그것',
      '저거',
      '저것',
      '이쪽',
      '그쪽',
      '저쪽',
      '조금',
      '약간',
    ];
    const shortMarkers = <String>['이', '그', '저', '좀', '더'];
    final unambiguous = _alternation(unambiguousMarkers);
    final allMarkers = _alternation({...unambiguousMarkers, ...shortMarkers});
    if (separatedPrefix) {
      return RegExp('^(?:$allMarkers){1,3}\$').hasMatch(clausePrefix);
    }

    // A joined prefix must begin with an unambiguous multi-syllable marker;
    // this admits "지금불..." while keeping lexical words such as "이불" closed.
    return RegExp(
      '^(?:$unambiguous)(?:$allMarkers){0,2}\$',
    ).hasMatch(clausePrefix);
  }

  bool _isStrongSingleTokenCookingContinuation(
    String token,
    String lexicalRoot,
    String continuation,
  ) {
    if (token == '불' && lexicalRoot == '의') {
      return RegExp(r'^(세기|강도|크기|온도)').hasMatch(continuation);
    }
    if (token == '불' && lexicalRoot == '만') {
      return RegExp(
        r'^(?:(?:더|좀|조금|약간)\s*)?'
        r'(?:줄|낮추|키우|높이|끄|켜|조절)',
      ).hasMatch(continuation);
    }
    if (token == '파' && lexicalRoot == '도') {
      return RegExp(
        r'^(?:(?:더|좀|조금|약간)\s*)?'
        r'(?:넣|추가|썰|다듬|씻|볶|굽|익히|빼|제외|사용)',
      ).hasMatch(continuation);
    }
    return false;
  }

  String _hangulWordPrefix(String value, int end) {
    return RegExp(r'[가-힣]+$').firstMatch(value.substring(0, end))?.group(0) ??
        '';
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
    if (_isFinishCommand(text)) {
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

  bool _isFinishCommand(String text) {
    final command = text.replaceFirst(RegExp(r'^(?:이제|드디어|정말)'), '');
    if (_explicitFinishPhrases.any(command.startsWith)) return true;
    return RegExp(
      r'^(?:(?:조리|요리|다|전부|모두))?(?:완성|완료)했'
      r'(?:어(?:요)?|다|습니다|네(?:요)?|지(?:요)?|죠)?[.!?。！？]*$',
    ).hasMatch(command);
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
    final replacementCutoff = _extensionReplacementCutoff(
      source,
      durationParts,
    );
    for (final signal in _extensionSignalMatches(source)) {
      if (signal.start < replacementCutoff) continue;
      if (_isRejectedExtensionSignal(source, signal)) continue;

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

  int _extensionReplacementCutoff(
    String source,
    List<({int start, int end, int seconds})> durationParts,
  ) {
    var cutoff = 0;
    final extensionSignals = _extensionSignalMatches(source)
        .where(
          (signal) => _isDurationAssociatedExtensionSignal(
            source,
            signal,
            durationParts,
          ),
        )
        .toList();
    final replacementMarkers = <RegExp>[
      RegExp(r'말고(?=$|[\s,，]|\d)'),
      RegExp(r'대신(?:에)?(?=$|[\s,，]|\d)'),
      RegExp(r'취소(?=$|[\s,，]|\d|하|해)'),
      RegExp(r'(?:^|[\s,，])아니(?=$|[\s,，]|\d)'),
    ];
    for (final pattern in replacementMarkers) {
      for (final marker in pattern.allMatches(source)) {
        if (_isNegatedReplacementMarker(source, marker)) continue;
        if (!_isExtensionReplacementMarker(source, marker, extensionSignals)) {
          continue;
        }
        if (marker.end > cutoff) cutoff = marker.end;
      }
    }
    return cutoff;
  }

  bool _isDurationAssociatedExtensionSignal(
    String source,
    RegExpMatch signal,
    List<({int start, int end, int seconds})> durationParts,
  ) {
    for (final part in durationParts) {
      if (part.end <= signal.start &&
          _isExtensionSignalGap(source.substring(part.end, signal.start))) {
        return true;
      }
      if (part.start >= signal.end &&
          _isExtensionSignalGap(source.substring(signal.end, part.start))) {
        return true;
      }
    }
    return false;
  }

  bool _isExtensionReplacementMarker(
    String source,
    RegExpMatch marker,
    List<RegExpMatch> extensionSignals,
  ) {
    RegExpMatch? previousSignal;
    for (final signal in extensionSignals) {
      if (signal.end > marker.start) break;
      previousSignal = signal;
    }
    if (previousSignal == null) return false;

    final gap = source
        .substring(previousSignal.end, marker.start)
        .replaceAll(RegExp(r'[\s,，]'), '');
    return gap.isEmpty ||
        _isExtensionSignalSuffix(previousSignal.group(0)!, gap);
  }

  bool _isNegatedReplacementMarker(String source, RegExpMatch marker) {
    final tail = _normalize(source.substring(marker.end));
    return RegExp(
      r'^(?:'
      r'(?:는|은|도)?(?:안|못)(?:하|해|했|할)|'
      r'(?:하|해)?지(?:는)?(?:마|말|않)|'
      r'(?:하|해)?(?:는)?건아니)',
    ).hasMatch(tail);
  }

  Iterable<RegExpMatch> _extensionSignalMatches(String source) sync* {
    final signalPattern = RegExp(
      _timerExtensionSignals.map(RegExp.escape).join('|'),
    );
    for (final signal in signalPattern.allMatches(source)) {
      final suffix = _hangulWordSuffix(source, signal.end);
      if (_isExtensionSignalSuffix(signal.group(0)!, suffix)) yield signal;
    }
  }

  bool _isExtensionSignalSuffix(String signal, String suffix) {
    if (suffix.isEmpty) return true;

    final actionSuffix = RegExp(
      r'^(?:로|해(?:줘|주세요|주라|서|도|요)?|'
      r'하(?:고|지|면|자|는|도록|려고|면서|세요)?|'
      r'할(?:게|까|까요|래)?|했(?:어|어요)?|줘|주세요|주라|요)$',
    );
    if (signal == '늘려') {
      return RegExp(r'^(?:줘|주세요|주라|서|도|요|볼까|야)$').hasMatch(suffix);
    }
    if (actionSuffix.hasMatch(suffix)) return true;

    // Joined STT output such as "1분더연장해줘" is still a command, while
    // lexical continuations such as "더덕" and "건더기" stay excluded.
    if (signal == '더') {
      for (final chainedSignal in const ['추가', '연장', '늘려']) {
        if (!suffix.startsWith(chainedSignal)) continue;
        return _isExtensionSignalSuffix(
          chainedSignal,
          suffix.substring(chainedSignal.length),
        );
      }
    }
    return false;
  }

  bool _isRejectedExtensionSignal(String source, RegExpMatch signal) {
    final tail = _normalize(source.substring(signal.end));
    return _isRejectedExtensionTail(tail);
  }

  bool _isRejectedExtensionTail(String tail) {
    if (RegExp(
          r'^(?:(?:하|해|늘리|주)(?:는|지)?)?'
          r'(?:는)?(?:말고|말자|말아|마|않|대신)',
        ).hasMatch(tail) ||
        RegExp(r'^안(?:하|해|늘리|주|할)').hasMatch(tail) ||
        RegExp(r'^할까[가-힣a-z0-9]{0,12}(?:안할|않|말)').hasMatch(tail)) {
      return true;
    }
    for (final chainedSignal in _timerExtensionSignals) {
      if (tail.startsWith(chainedSignal) &&
          _isRejectedExtensionTail(tail.substring(chainedSignal.length))) {
        return true;
      }
    }
    return false;
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
