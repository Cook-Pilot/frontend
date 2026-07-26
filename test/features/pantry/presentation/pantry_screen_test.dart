import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/features/pantry/data/pantry_api.dart';
import 'package:cookpilot/features/pantry/presentation/pantry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('이모티콘을 누르면 재료가 담겨 목록에 나타나고, 삭제하면 사라진다', (
    tester,
  ) async {
    final repository = _FakePantryDataSource();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCookPilotTheme(),
        home: PantryScreen(pantryRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('아직 담은 재료가 없어요'), findsOneWidget);

    await tester.tap(find.text('계란'));
    await tester.pumpAndSettle();

    expect(find.text('아직 담은 재료가 없어요'), findsNothing);
    expect(find.textContaining('D-'), findsOneWidget);
    expect(repository.addedIngredients, ['계란']);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('아직 담은 재료가 없어요'), findsOneWidget);
    expect(repository.removedItemIds, hasLength(1));
  });
}

class _FakePantryDataSource implements PantryDataSource {
  final List<PantryItem> _items = [];
  final List<String> addedIngredients = [];
  final List<String> removedItemIds = [];

  @override
  Future<List<PantryIngredientCatalogItem>> findCatalog() async {
    return const [
      PantryIngredientCatalogItem(
        name: '계란',
        emoji: '🥚',
        defaultShelfLifeDays: 21,
      ),
    ];
  }

  @override
  Future<List<PantryItem>> findItems() async => List.of(_items);

  @override
  Future<PantryItem> addItem(String ingredientName) async {
    addedIngredients.add(ingredientName);
    final item = PantryItem(
      id: 'item-${_items.length + 1}',
      ingredientName: ingredientName,
      emoji: '🥚',
      daysUntilExpiry: 21,
    );
    _items.add(item);
    return item;
  }

  @override
  Future<void> removeItem(String itemId) async {
    removedItemIds.add(itemId);
    _items.removeWhere((item) => item.id == itemId);
  }

  @override
  Future<List<PantryRecipeSuggestion>> findRecipeSuggestions() async {
    return const [];
  }
}
