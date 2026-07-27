import 'package:cookpilot/core/network/dio_provider.dart';
import 'package:cookpilot/data/models/personal_recipe_version.dart';
import 'package:cookpilot/data/models/recipe.dart';
import 'package:cookpilot/data/models/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// recipe / personalrecipe / user — 조회 전용 엔드포인트 (backend docs/08).
class RecipeRepository {
  const RecipeRepository(this._dio);

  final Dio _dio;

  Future<User> me() => guardApi(() async {
    final res = await _dio.get<Map<String, dynamic>>('/users/me');
    return User.fromJson(res.data!);
  });

  Future<List<RecipeSummary>> recipes() => guardApi(() async {
    final res = await _dio.get<List<dynamic>>('/recipes');
    return res.data!
        .map((e) => RecipeSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  Future<Recipe> recipe(String recipeId) => guardApi(() async {
    final res = await _dio.get<Map<String, dynamic>>('/recipes/$recipeId');
    return Recipe.fromJson(res.data!);
  });

  Future<List<PersonalRecipeVersion>> personalVersions(String recipeId) =>
      guardApi(() async {
        final res = await _dio.get<List<dynamic>>(
          '/recipes/$recipeId/personal-versions',
        );
        return res.data!
            .map((e) => PersonalRecipeVersion.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<PersonalRecipeVersion> personalVersion(String versionId) =>
      guardApi(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/personal-versions/$versionId',
        );
        return PersonalRecipeVersion.fromJson(res.data!);
      });
}

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => RecipeRepository(ref.watch(dioProvider)),
);
