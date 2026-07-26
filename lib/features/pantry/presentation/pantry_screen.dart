import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../mvp/mvp_widgets.dart';
import '../data/pantry_api.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key, this.pantryRepository});

  final PantryDataSource? pantryRepository;

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  late final PantryDataSource _repository;
  late Future<_PantryData> _data;
  String? _pendingIngredient;

  @override
  void initState() {
    super.initState();
    _repository = widget.pantryRepository ?? PantryRepository();
    _data = _load();
  }

  Future<_PantryData> _load() async {
    final catalog = await _repository.findCatalog();
    final items = await _repository.findItems();
    return _PantryData(catalog: catalog, items: items);
  }

  void _retry() {
    setState(() => _data = _load());
  }

  Future<void> _addIngredient(String name) async {
    setState(() => _pendingIngredient = name);
    try {
      await _repository.addItem(name);
      if (!mounted) return;
      setState(() {
        _data = _load();
        _pendingIngredient = null;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _pendingIngredient = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('재료를 담지 못했어요. 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _removeItem(PantryItem item) async {
    try {
      await _repository.removeItem(item.id);
      if (!mounted) return;
      setState(() => _data = _load());
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제하지 못했어요. 다시 시도해 주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: '개인 재료',
      children: [
        FutureBuilder<_PantryData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.only(top: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: AppColors.muted,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '재료 정보를 불러오지 못했어요.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(onPressed: _retry, child: const Text('다시 시도')),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('냉장고에 뭐가 있나요?'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final catalogItem in data.catalog)
                      _IngredientChip(
                        catalogItem: catalogItem,
                        loading: _pendingIngredient == catalogItem.name,
                        onTap: () =>
                            unawaited(_addIngredient(catalogItem.name)),
                      ),
                  ],
                ),
                const SectionTitle('내가 담은 재료'),
                if (data.items.isEmpty)
                  const InfoStrip(
                    icon: Icons.kitchen_outlined,
                    title: '아직 담은 재료가 없어요',
                    body: '위 이모티콘을 눌러 냉장고 재료를 담아보세요.',
                  )
                else
                  for (final item in data.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PantryItemTile(
                        item: item,
                        onRemove: () => unawaited(_removeItem(item)),
                      ),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PantryData {
  const _PantryData({required this.catalog, required this.items});

  final List<PantryIngredientCatalogItem> catalog;
  final List<PantryItem> items;
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({
    required this.catalogItem,
    required this.loading,
    required this.onTap,
  });

  final PantryIngredientCatalogItem catalogItem;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(catalogItem.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                catalogItem.name,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (loading) ...[
                const SizedBox(width: 6),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 보유 재료 한 줄. 홈 화면 추천 카드에서도 같은 톤을 쓰기 위해 공개 위젯으로 둔다.
class PantryItemTile extends StatelessWidget {
  const PantryItemTile({super.key, required this.item, this.onRemove});

  final PantryItem item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final badgeColor = item.daysUntilExpiry <= 2
        ? AppColors.accent
        : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppShape.inner),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.ingredientName,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              dDayLabel(item.daysUntilExpiry),
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.muted,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

String dDayLabel(int daysUntilExpiry) {
  if (daysUntilExpiry < 0) {
    return '기한 ${-daysUntilExpiry}일 지남';
  }
  if (daysUntilExpiry == 0) {
    return 'D-DAY';
  }
  return 'D-$daysUntilExpiry';
}
