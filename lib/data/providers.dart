import 'dart:async';
import 'package:cookpilot/data/models/personal_recipe_version.dart';
import 'package:cookpilot/data/models/recipe.dart';
import 'package:cookpilot/data/models/user.dart';
import 'package:cookpilot/data/repositories/recipe_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// GET /users/me — 인증 미확정이라 서버 고정 목유저.
final currentUserProvider = FutureProvider<User>(
  (ref) => ref.watch(recipeRepositoryProvider).me(),
);

/// GET /recipes — 목록 + 내 버전 배지.
final recipesProvider = FutureProvider<List<RecipeSummary>>(
  (ref) => ref.watch(recipeRepositoryProvider).recipes(),
);

/// GET /recipes/{id} + GET /recipes/{id}/personal-versions 를 한 번에.
final recipeDetailProvider = FutureProvider.family<RecipeDetail, String>((
  ref,
  recipeId,
) async {
  final repo = ref.watch(recipeRepositoryProvider);
  final (recipe, versions) = await (
    repo.recipe(recipeId),
    repo.personalVersions(recipeId),
  ).wait;
  return RecipeDetail(recipe: recipe, versions: versions);
});

/// GET /personal-versions/{id}
final personalVersionProvider =
    FutureProvider.family<PersonalRecipeVersion, String>(
      (ref, versionId) =>
          ref.watch(recipeRepositoryProvider).personalVersion(versionId),
    );

/// 메모리 탭: 내 버전이 있는 레시피만 모아 버전 목록을 붙인다.
final memoriesProvider = FutureProvider<List<RecipeMemory>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  final recipes = await repo.recipes();

  final memories = <RecipeMemory>[];
  for (final recipe in recipes.where((r) => r.hasPersonalVersion)) {
    final versions = await repo.personalVersions(recipe.id);
    if (versions.isNotEmpty) {
      memories.add(RecipeMemory(recipe: recipe, versions: versions));
    }
  }
  return memories;
});

class RecipeDetail {
  const RecipeDetail({required this.recipe, required this.versions});

  final Recipe recipe;
  final List<PersonalRecipeVersion> versions;

  PersonalRecipeVersion? get latestVersion =>
      versions.isEmpty ? null : versions.last;
}

class RecipeMemory {
  const RecipeMemory({required this.recipe, required this.versions});

  final RecipeSummary recipe;
  final List<PersonalRecipeVersion> versions;
}
