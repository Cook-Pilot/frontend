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

  // 문제·질문 판정은 정밀 형태소 분석 없이 넓은 게이트만 둔다. 판정 본체와
  // 안전 응답은 백엔드 F-08이 소유하므로, 여기서 오탐의 비용은 코치 호출
  // 1번이고 미탐의 비용은 위험 발화가 서버 안전망에 닿지 못하는 것이다.
  // 행동을 일으키는 로컬 명령은 좁게, 서버로 보내는 게이트는 넓게 유지한다.
  static const _problemSignals = <String>[
    // 조리 실패
    '안끓',
    '끓지않',
    '덜익',
    '안익',
    '설익',
    '눌어붙',
    '타고있',
    '타요',
    '탔',
    '태웠',
    '탄내',
    '싱거',
    '묽',
    // 안전
    '불나',
    '불이나',
    '불붙',
    '불이붙',
    '연기',
    '가스',
    '냄새',
    '상한',
    '상했',
    '곰팡이',
    '데었',
    '데였',
    '화상',
    '베였',
    '베었',
    '위험',
  ];

  static const _missingSignals = <String>['없어', '없는데', '다썼', '다사용', '떨어졌'];

  // 짠맛 신호는 어미를 열거하는 대신 느슨한 포함으로 잡되, 조리와 무관하게
  // 흔한 어휘만 걷어낸다. 걷어낸 뒤 남는 '짜/짠'은 살아 있어야 한다
  // ("국물이 진짜 짜"). 남는 오탐("월급이 짜")의 비용은 코치 호출 1번이다.
  static const _saltyLexicalBlocklist = <String>[
    '진짜',
    '가짜',
    '짜증',
    '짜장',
    '짜릿',
    '날짜',
    '짜임',
    '짜파',
    '짠해',
    '짠돌',
  ];

  // 한 글자 조리 단어는 단어 시작 + (조사 1글자)(+요) + 경계일 때만 문맥으로
  // 본다. '불가능'/'이불'/'인간관계'는 걸러지고, '불만'(불+만) 같은 진성
  // 동형어 오탐은 허용한다.
  static const _singleCharContextWords = <String>['불', '간', '팬'];

  VoiceIntent route(
    String transcript, {
    required String recipeTitle,
    required Iterable<String> ingredientNames,
    required String currentStepInstruction,
  }) {
    final text = _normalize(transcript);
    if (text.isEmpty) return const VoiceIntent(VoiceIntentType.ignore);
    final lowerTranscript = transcript.toLowerCase();

    final contextTokens = _lightContextTokens(
      recipeTitle,
      currentStepInstruction,
      ingredientNames,
    );
    final singleCharWords = <String>{
      ..._singleCharContextWords,
      for (final ingredient in ingredientNames)
        if (RegExp(r'^[가-힣]$').hasMatch(ingredient.trim())) ingredient.trim(),
    };
    final extensionSeconds = _extensionSeconds(transcript, text);
    final mutatingIntent = _mutatingIntent(text, extensionSeconds);

    // 문제 서술과 (조리 문맥 또는 명령 소재를 동반한) 질문은 코치로 보낸다.
    // 질문을 로컬 substring 명령보다 먼저 검사해야 "다음에 소금 넣는 게
    // 맞아?"가 next로 새지 않는다.
    if (_hasProblemSignal(text, lowerTranscript, contextTokens) ||
        (_hasQuestionSignal(text) &&
            (mutatingIntent != null ||
                _hasLightCookingContext(
                  text,
                  lowerTranscript,
                  contextTokens,
                  singleCharWords,
                )))) {
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

  bool _hasQuestionSignal(String text) => _questionSignals.any(text.contains);

  bool _hasProblemSignal(
    String text,
    String lowerTranscript,
    Set<String> contextTokens,
  ) {
    if (_problemSignals.any(text.contains)) return true;
    if (_hasSaltySignal(lowerTranscript)) return true;
    // 생고기 취식은 조합으로만 잡는다. 부정·인용의 정밀 판정은 서버 몫이다.
    if ((text.contains('생고기') || text.contains('생으로')) && text.contains('먹')) {
      return true;
    }
    // 재료 부족: 재료명(또는 '재료')과 부족 술어가 함께 있을 때만 인정한다.
    // "오늘 시간이 없어" 같은 일상 발화가 전부 코치로 가는 것을 막는 최소 장치.
    if (_missingSignals.any(text.contains)) {
      return text.contains('재료') || contextTokens.any(text.contains);
    }
    return false;
  }

  bool _hasSaltySignal(String lowerTranscript) {
    // 공백을 보존한 원문에서 걷어낸다. 정규화 텍스트에서는 "소스가 짜더라"가
    // "가짜"로 붙어 블록리스트에 잘못 걸린다.
    var stripped = lowerTranscript;
    for (final blocked in _saltyLexicalBlocklist) {
      stripped = stripped.replaceAll(blocked, '');
    }
    return stripped.contains('짜') || stripped.contains('짠');
  }

  bool _hasLightCookingContext(
    String text,
    String lowerTranscript,
    Set<String> contextTokens,
    Set<String> singleCharWords,
  ) {
    return _staticCookingContext.any(text.contains) ||
        contextTokens.any(text.contains) ||
        singleCharWords.any(
          (word) => _isStandaloneSingleCharWord(lowerTranscript, word),
        );
  }

  bool _isStandaloneSingleCharWord(String lowerTranscript, String word) {
    return RegExp(
      '(?:^|\\s)${RegExp.escape(word)}'
      '(?:[이가은는을를도만의에로와과])?(?:요)?'
      r'(?=\s|$|[^가-힣])',
    ).hasMatch(lowerTranscript);
  }

  /// 레시피 제목·현재 단계·재료명의 두 글자 이상 토큰. 한 글자 재료('물',
  /// '파')의 조사 경계 판정은 삭제했다 — 그 정밀도가 사던 것은 게이트의
  /// 정확도뿐인데, 판정 본체가 서버로 넘어가면서 값어치가 사라졌다.
  Set<String> _lightContextTokens(
    String recipeTitle,
    String currentStepInstruction,
    Iterable<String> ingredientNames,
  ) {
    final tokens = <String>{};
    for (final source in [
      recipeTitle,
      currentStepInstruction,
      ...ingredientNames,
    ]) {
      for (final match in RegExp(
        r'[가-힣a-z0-9]{2,}',
      ).allMatches(source.toLowerCase())) {
        tokens.add(match[0]!);
      }
    }
    return tokens;
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

    if (!_isNegatedTimerStartCommand(text) &&
        _hasAny(text, const [
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
    if (_isNegatedFinishCommand(command)) return false;
    if (_explicitFinishPhrases.any(command.startsWith)) return true;
    return RegExp(
      r'^(?:(?:조리|요리)(?:가|는|은)?|다|전부|모두)?(?:완성|완료)'
      r'(?:했|됐|되었)'
      r'(?:어(?:요)?|다|습니다|네(?:요)?|지(?:요)?|죠)?[.!?。！？]*$',
    ).hasMatch(command);
  }

  bool _isNegatedFinishCommand(String command) {
    const particles = r'(?:(?:이라도|라도|이|가|은|는|을|를|도|만|까지|조차|마저)){0,2}';
    const emphasis = r'(?:(?:아직|전혀|절대|아예|결코))*';
    for (final completion in RegExp(r'완성|완료|끝').allMatches(command)) {
      final tail = command.substring(completion.end);
      if (RegExp(
            '^$particles$emphasis'
            r'(?:(?:안|못)(?:했|됐|끝냈|끝났)|'
            r'(?:하|되|내)?지(?:는)?(?:마|말|않|못)|'
            r'(?:말고|금지))',
          ).hasMatch(tail) ||
          RegExp(
            '^$particles'
            r'(?:되었던|됐던|했던|났던|되었|했|됐|났|낸|한|된|난)?'
            r'(?:건|게|것(?:이|은)?)(?:전혀|절대|아예)?아니',
          ).hasMatch(tail) ||
          RegExp(
            '^$particles'
            r'(?:되었던|됐던|했던|났던|되었|했|됐|났|낸|한|된|난)?'
            r'(?:이라는|라는|이?라고|다고|다는)'
            r'(?:(?:말)?(?:했던|했|한)?'
            r'(?:건|게|것(?:이|은)?)(?:전혀|절대|아예)?아니|'
            r'말(?:은|이|도)?(?:전혀|절대|아예)?아니)',
          ).hasMatch(tail)) {
        return true;
      }
    }
    return false;
  }

  bool _isNegatedTimerStartCommand(String command) {
    const particles = r'(?:(?:이라도|라도|이|가|은|는|을|를|도|만|까지|조차|마저)){0,2}';
    const emphasis = r'(?:(?:아직|전혀|절대|아예|결코))*';
    return RegExp(
      r'(?:타이머(?:시작|켜)|시간재기|조리시작|요리시작)'
      '$particles$emphasis'
      r'(?:(?:하)?지(?:는)?(?:마|말|않|못)|'
      r'(?:안|못)(?:해|하|할|했|켜|켰|시작)|'
      r'(?:하|한|하는)?(?:건|게|것(?:이|은)?)아니|'
      r'아니|말고|금지)',
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
    final extensionSignals = _extensionSignalMatches(source).toList();
    final replacedSignalStarts = _replacedExtensionSignalStarts(
      source,
      extensionSignals,
      durationParts,
    );
    for (final signal in extensionSignals) {
      if (replacedSignalStarts.contains(signal.start)) continue;
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

  Set<int> _replacedExtensionSignalStarts(
    String source,
    List<RegExpMatch> extensionSignals,
    List<({int start, int end, int seconds})> durationParts,
  ) {
    final durationSignals = extensionSignals
        .where(
          (signal) => _isDurationAssociatedExtensionSignal(
            source,
            signal,
            durationParts,
          ),
        )
        .toList();
    final replaced = <int>{};
    final replacementMarkers = <RegExp>[
      RegExp(r'말고(?=$|[\s,，]|\d)'),
      RegExp(r'대신(?:에)?(?=$|[\s,，]|\d)'),
      RegExp(r'취소(?=$|[\s,，]|\d|하|해)'),
      RegExp(r'(?:^|[\s,，])아니(?=$|[\s,，]|\d)'),
    ];
    for (final pattern in replacementMarkers) {
      for (final marker in pattern.allMatches(source)) {
        if (_isNegatedReplacementMarker(source, marker)) continue;
        if (!_isExtensionReplacementMarker(source, marker, durationSignals)) {
          continue;
        }
        RegExpMatch? previousSignal;
        for (final signal in durationSignals) {
          if (signal.end > marker.start) break;
          previousSignal = signal;
        }
        if (previousSignal != null) replaced.add(previousSignal.start);
      }
    }
    return replaced;
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
        .replaceAll(RegExp(r'[\s,，.!?。！？;；]'), '');
    final signal = previousSignal.group(0)!;
    if (gap.isEmpty || _isExtensionSignalSuffix(signal, gap)) return true;

    final referent = RegExp(r'(?:그건|그거는|그걸|그것은|그것을)$').firstMatch(gap);
    if (referent == null) return false;
    final action = gap.substring(0, referent.start);
    return action.isEmpty || _isExtensionSignalSuffix(signal, action);
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

  String _hangulWordSuffix(String value, int start) {
    return RegExp(r'^[가-힣]+').firstMatch(value.substring(start))?.group(0) ??
        '';
  }

  bool _hasAny(String value, Iterable<String> candidates) {
    return candidates.any(value.contains);
  }
}
