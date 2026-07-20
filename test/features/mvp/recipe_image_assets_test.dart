import 'dart:io';

import 'package:cookpilot/features/mvp/mock_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('화면에 노출되는 모든 레시피 이미지를 로컬 자산으로 제공한다', () {
    const visibleTitles = <String>{
      '두부 조림',
      '김치볶음밥',
      '된장찌개',
      '오일 파스타',
      '닭갈비',
      '크림 파스타',
      '매콤 제육',
      '치킨 샐러드',
      '마파두부',
      '두부 덮밥',
      '두부 된장국',
    };

    expect(recipeImageAssets.keys, containsAll(visibleTitles));

    for (final title in visibleTitles) {
      final assetPath = recipeImageAssets[title];
      expect(assetPath, isNotNull, reason: '$title 이미지 경로가 필요합니다.');
      expect(
        File(assetPath!).existsSync(),
        isTrue,
        reason: '$title 이미지 파일이 존재해야 합니다: $assetPath',
      );
      expect(recipeByTitle(title).imageAsset, assetPath);
    }
  });
}
