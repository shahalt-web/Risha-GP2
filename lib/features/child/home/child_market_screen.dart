import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/services/child_reward_service.dart';
import 'package:risha_v01/shared/widgets/child_mascot_avatar.dart';

class ChildMarketScreen extends StatefulWidget {
  const ChildMarketScreen({super.key});

  @override
  State<ChildMarketScreen> createState() => _ChildMarketScreenState();
}

class _ChildMarketScreenState extends State<ChildMarketScreen> {
  // تعليمات اختبار النقاط والسعر من الكود فقط:
  //
  // 1. _testChildCoinsOverride
  //    استخدمها لإعطاء الطفل رصيدًا تجريبيًا مؤقتًا عند فتح المتجر.
  //    مثال: 300
  //    إذا أردت استخدام الرصيد الحقيقي المحفوظ للطفل، اتركها null.
  //
  // 2. _testMarketPriceOverride
  //    استخدمها لتغيير سعر كل الملابس مؤقتًا أثناء الفحص.
  //    مثال: 10 أو 0
  //    إذا أردت استخدام السعر الافتراضي العام من ChildRewardService،
  //    اتركها null.
  static const int? _testChildCoinsOverride = null;
  static const int? _testMarketPriceOverride = null;

  static const List<_MarketItemData> _items = [
    _MarketItemData(
      assetPath: 'assets/market_clothes/hair_clip.png',
      category: _MarketCategory.accessory,
      price: 100,
    ),
    _MarketItemData(
      assetPath: 'assets/market_clothes/light_pink_dress.png',
      category: _MarketCategory.outfit,
      price: 700,
    ),
    _MarketItemData(
      assetPath: 'assets/market_clothes/pink_dress.png',
      category: _MarketCategory.outfit,
      price: 1300,
    ),
    _MarketItemData(
      assetPath: 'assets/market_clothes/black_dress.png',
      category: _MarketCategory.outfit,
      price: 1700,
    ),
    _MarketItemData(
      assetPath: 'assets/market_clothes/headband.png',
      category: _MarketCategory.accessory,
      price: 2000,
    ),
    _MarketItemData(
      assetPath: 'assets/market_clothes/wight_dress.png',
      category: _MarketCategory.outfit,
      price: 4500,
    ),
  ];

  final ChildRewardService _childRewardService = ChildRewardService();

  _MarketItemData? _selectedAccessory;
  _MarketItemData? _selectedOutfit;
  Set<String> _ownedItemAssetPaths = <String>{};
  int? _coinsBalance;
  bool _isLoadingCoins = true;
  bool _isUpdating = false;

  // هذه القيمة هي السعر النهائي الظاهر والمستخدم في الشراء داخل المتجر:
  // إذا وضعت _testMarketPriceOverride فسيستخدمها أولًا.
  // وإذا كانت null فسيعود للسعر الافتراضي العام من الخدمة.
  int get _marketItemPrice =>
      _testMarketPriceOverride ?? ChildRewardService.marketItemPrice;

  @override
  void initState() {
    super.initState();
    unawaited(_loadWalletState());
  }

  Future<void> _loadWalletState() async {
    if (mounted) {
      setState(() {
        _isLoadingCoins = true;
        _coinsBalance = null;
      });
    }

    try {
      final wallet = await _childRewardService.getSelectedChildWallet();
      // إذا وضعت رصيدًا تجريبيًا أعلى الملف، يتم فرضه هنا عند تحميل المتجر.
      // وإذا كانت القيمة null فسيستخدم التطبيق رصيد الطفل الحقيقي كما هو محفوظ.
      final effectiveWallet =
          _testChildCoinsOverride != null &&
              wallet.coins != _testChildCoinsOverride
          ? await _childRewardService.setSelectedChildCoins(
              coins: _testChildCoinsOverride!,
            )
          : wallet;

      if (!mounted) {
        return;
      }

      setState(() {
        _applyWalletState(effectiveWallet);
        _isLoadingCoins = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _coinsBalance = null;
        _isLoadingCoins = false;
      });
    }
  }

  void _applyWalletState(ChildWalletState wallet) {
    _coinsBalance = wallet.coins;
    _ownedItemAssetPaths = wallet.ownedMarketItemAssetPaths.toSet();
    _selectedAccessory = _findItemByAssetPath(
      wallet.equippedAccessoryAssetPath,
    );
    _selectedOutfit = _findItemByAssetPath(wallet.equippedOutfitAssetPath);
  }

  _MarketItemData? _findItemByAssetPath(String? assetPath) {
    if (assetPath == null || assetPath.isEmpty) {
      return null;
    }

    for (final item in _items) {
      if (item.assetPath == assetPath) {
        return item;
      }
    }

    return null;
  }

  bool _isOwned(_MarketItemData item) =>
      _ownedItemAssetPaths.contains(item.assetPath);

  Future<void> _selectItem(_MarketItemData item) async {
    if (_isUpdating) {
      return;
    }

    if (_isOwned(item)) {
      await _toggleOwnedItem(item);
      return;
    }

    final itemPrice = item.price;
    if ((_coinsBalance ?? 0) < itemPrice) {
      _showMessage('لا توجد نقاط كافية لشراء هذا العنصر الآن.');
      return;
    }

    setState(() => _isUpdating = true);
    try {
      final result = await _childRewardService.purchaseSelectedChildMarketItem(
        assetPath: item.assetPath,
        isAccessory: item.category == _MarketCategory.accessory,
        purchasePrice: item.price,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _applyWalletState(result.wallet);
        _isUpdating = false;
      });
      _showMessage(
        result.purchasedNow ? 'تم الشراء بنجاح!' : 'تم تجهيز العنصر.',
      );
    } on ChildRewardFailure catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _isUpdating = false);
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isUpdating = false);
      _showMessage('تعذر إتمام الشراء الآن. حاول مرة أخرى.');
    }
  }

  Future<void> _toggleOwnedItem(_MarketItemData item) async {
    final shouldEquip = !_isSelected(item);

    setState(() => _isUpdating = true);
    try {
      final wallet = await _childRewardService.setSelectedChildEquippedItem(
        isAccessory: item.category == _MarketCategory.accessory,
        assetPath: shouldEquip ? item.assetPath : null,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _applyWalletState(wallet);
        _isUpdating = false;
      });
    } on ChildRewardFailure catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _isUpdating = false);
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isUpdating = false);
      _showMessage('تعذر تحديث العنصر الآن. حاول مرة أخرى.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isSelected(_MarketItemData item) {
    if (item.category == _MarketCategory.accessory) {
      return identical(_selectedAccessory, item);
    }
    return identical(_selectedOutfit, item);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        context.go('/child-home/daily-home');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEFE5D4),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 318,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              'assets/wallpapers/rock_wallpaper.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 8,
                            child: _MarketCoinsBadge(
                              value: _coinsBalance,
                              isLoading: _isLoadingCoins,
                            ),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: SizedBox(
                                width: 188,
                                height: 238,
                                child: ChildMascotAvatar(
                                  poseAssetPath:
                                      'assets/risha/risha_normal.png',
                                  width: 188,
                                  height: 238,
                                  alignment: const Alignment(0, 0.22),
                                  scale: 0.82,
                                  outfitAssetPath: _selectedOutfit?.assetPath,
                                  accessoryAssetPath:
                                      _selectedAccessory?.assetPath,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFDFBF8),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.98,
                              ),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _MarketItemCard(
                              item: item,
                              price: item.price,
                              selected: _isSelected(item),
                              owned: _isOwned(item),
                              affordable:
                                  (_coinsBalance ?? 0) >= _marketItemPrice,
                              onTap: () => _selectItem(item),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const _MarketBottomMenuBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketItemCard extends StatelessWidget {
  const _MarketItemCard({
    required this.item,
    required this.price,
    required this.selected,
    required this.owned,
    required this.affordable,
    required this.onTap,
  });

  final _MarketItemData item;
  final int price;
  final bool selected;
  final bool owned;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLocked = !owned;
    final cardColor = owned ? const Color(0xFFF9F9F9) : const Color(0xFF9E9E9E);
    final borderColor = selected
        ? const Color(0xFF1096F3)
        : owned
        ? const Color(0xFFE9C754)
        : const Color(0xFF8B8B8B);
    final titleColor = owned
        ? const Color(0xFF2F8A55)
        : affordable
        ? Colors.white
        : const Color(0xFFFCE2DB);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 2.2 : 1),
          ),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Stack(
            children: [
              Column(
                children: [
                  Text(
                    '$price',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    owned
                        ? 'تم الشراء'
                        : affordable
                        ? price == 0
                              ? 'شراء مجاني'
                              : 'قم بالشراء'
                        : '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: owned
                          ? const Color(0xFF2F8A55)
                          : affordable
                          ? Colors.white
                          : const Color(0xFFFCE2DB),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Center(
                      child: Opacity(
                        opacity: owned ? 1 : 0.45,
                        child: Image.asset(item.assetPath, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ],
              ),
              if (isLocked)
                const Positioned(
                  top: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketBottomMenuBar extends StatelessWidget {
  const _MarketBottomMenuBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: const Color(0xFF5A9E79),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            'assets/icons/market_icon.png',
            width: 90,
            height: 90,
            fit: BoxFit.contain,
          ),
          GestureDetector(
            onTap: () => context.go('/child-home/daily-home'),
            child: Image.asset(
              'assets/icons/nest_icon.png',
              width: 96,
              height: 96,
              fit: BoxFit.contain,
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/child-home/settings'),
            child: Image.asset(
              'assets/icons/setting_icon.png',
              width: 60,
              height: 60,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketCoinsBadge extends StatelessWidget {
  const _MarketCoinsBadge({required this.value, required this.isLoading});

  final int? value;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8E6C3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4CAA0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/palm_icon.png',
            width: 15,
            height: 15,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 4),
          if (isLoading)
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Color(0xFF3F2F1D),
              ),
            )
          else
            Text(
              value?.toString() ?? '--',
              style: const TextStyle(
                color: Color(0xFF3F2F1D),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _MarketItemData {
  const _MarketItemData({
    required this.assetPath,
    required this.category,
    required this.price, // <-- أضف هذا السطر
  });

  final String assetPath;
  final _MarketCategory category;
  final int price; // <-- أضف هذا السطر
}

enum _MarketCategory { accessory, outfit }
