import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/services/auth_service.dart';
import 'package:risha_v01/shared/services/child_behavior_service.dart';
import 'package:risha_v01/shared/services/child_service.dart';
import 'package:risha_v01/shared/services/local_notification_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';

enum _ChildAction { edit, selectSavedSetup, selectWithSetup, delete }

class ChildProfileSelectionScreen extends StatefulWidget {
  const ChildProfileSelectionScreen({super.key});

  @override
  State<ChildProfileSelectionScreen> createState() =>
      _ChildProfileSelectionScreenState();
}

class _ChildProfileSelectionScreenState
    extends State<ChildProfileSelectionScreen> {
  final _authService = AuthService();
  final _childService = ChildService();
  final _childBehaviorService = ChildBehaviorService();
  final _selectedChildService = SelectedChildService();
  final _localNotificationService = LocalNotificationService.instance;
  final _sessionProgressService = SessionProgressService();
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    // دخول شاشة الملفات يعني العودة للواجهة الأساسية، لذلك نمسح نقطة الاستكمال.
    unawaited(_sessionProgressService.clearChildSetupRoute());
  }

  Future<void> _showChildActions(ChildProfile child) async {
    if (_isSigningOut) {
      return;
    }

    final hasSavedSetupFuture = _childBehaviorService.hasPreparedChildSetup(
      childId: child.id,
    );

    final action = await showModalBottomSheet<_ChildAction>(
      context: context,
      backgroundColor: const Color(0xFFF7F1E2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: FutureBuilder<bool>(
              future: hasSavedSetupFuture,
              builder: (context, snapshot) {
                final isCheckingSetup =
                    snapshot.connectionState != ConnectionState.done;
                final hasSavedSetup = snapshot.data == true;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'خيارات الطفل: ${child.name}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFFB48C6A),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ActionButton(
                      label: 'تعديل معلومات الطفل',
                      onTap: () => Navigator.of(context).pop(_ChildAction.edit),
                    ),
                    const SizedBox(height: 10),
                    _ActionButton(
                      label: isCheckingSetup
                          ? 'جارٍ فحص الإعدادات المحفوظة...'
                          : 'اختيار الطفل بالإعدادات المحفوظة',
                      height: 64,
                      fontSize: 14,
                      enabled: !isCheckingSetup && hasSavedSetup,
                      onTap: () => Navigator.of(
                        context,
                      ).pop(_ChildAction.selectSavedSetup),
                    ),
                    if (!isCheckingSetup && !hasSavedSetup) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'هذا الخيار يتطلب إعدادات مكتملة للطفل.',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Color(0xFFB48C6A),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _ActionButton(
                      label: 'اختيار الطفل وضبط الإعدادات',
                      height: 64,
                      fontSize: 14,
                      onTap: () => Navigator.of(
                        context,
                      ).pop(_ChildAction.selectWithSetup),
                    ),
                    const SizedBox(height: 10),
                    _DeleteActionButton(
                      label: 'حذف الطفل',
                      onTap: () =>
                          Navigator.of(context).pop(_ChildAction.delete),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == _ChildAction.edit) {
      context.go(
        '/child-home/edit-child/${Uri.encodeComponent(child.id)}',
        extra: child,
      );
      return;
    }

    if (action == _ChildAction.selectSavedSetup) {
      try {
        await _selectChildWithPreparedBehaviors(child);
      } catch (_) {
        if (!mounted) {
          return;
        }
        _showError('تعذر اختيار الطفل حالياً. حاول مرة أخرى.');
      }
      return;
    }

    if (action == _ChildAction.selectWithSetup) {
      try {
        await _selectChildAndOpenSetup(child);
      } catch (_) {
        if (!mounted) {
          return;
        }
        _showError('تعذر اختيار الطفل حالياً. حاول مرة أخرى.');
      }
      return;
    }

    if (action == _ChildAction.delete) {
      await _showDeleteConfirmation(child);
      return;
    }
  }

  Future<void> _selectChildWithPreparedBehaviors(ChildProfile child) async {
    await _selectedChildService.saveSelectedChildId(
      child.id,
      childName: child.name,
    );
    await _sessionProgressService.clearChildSetupRoute();
    await _sessionProgressService.setChildSetupCompleted(true);
    unawaited(
      _runPostSelectionBackgroundSync(
        child: child,
        syncSleepLock: true,
        syncNotifications: true,
      ),
    );
    if (!mounted) {
      return;
    }
    context.go('/child-home/daily-home');
  }

  Future<void> _selectChildAndOpenSetup(ChildProfile child) async {
    await _selectedChildService.saveSelectedChildId(
      child.id,
      childName: child.name,
    );
    await _sessionProgressService.setChildSetupCompleted(false);
    await _sessionProgressService.clearChildSetupRoute();
    unawaited(
      _runPostSelectionBackgroundSync(
        child: child,
        syncSleepLock: false,
        syncNotifications: false,
      ),
    );
    if (!mounted) {
      return;
    }
    context.go('/child-home/behaviors');
  }

  Future<void> _runPostSelectionBackgroundSync({
    required ChildProfile child,
    required bool syncSleepLock,
    required bool syncNotifications,
  }) async {
    if (syncNotifications) {
      _localNotificationService.syncSelectedChildNotificationsInBackground(
        delay: const Duration(milliseconds: 500),
      );
    }

    try {
      if (!syncSleepLock) {
        await _childBehaviorService.clearDeviceSleepLock();
        return;
      }
      await _childBehaviorService.syncDeviceSleepLockForChild(
        childId: child.id,
        childName: child.name,
      );
    } catch (_) {
      // Ignore native bedtime sync failures to avoid blocking child selection.
    }
  }

  Future<void> _showDeleteConfirmation(ChildProfile child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
            'هل أنت متأكد من حذف الطفل "${child.name}"؟\n\nسيتم حذف جميع بيانات الطفل نهائياً.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteChild(child);
    }
  }

  Future<void> _deleteChild(ChildProfile child) async {
    try {
      await _childService.deleteChild(child.id);
      // If the deleted child was selected, clear selection
      final selectedId = await _selectedChildService.getSelectedChildId();
      if (selectedId == child.id) {
        await _selectedChildService.clearSelectedChildId();
        await _localNotificationService.clearManagedNotifications();
      }
    } on ChildFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('تعذر حذف الطفل حالياً. حاول مرة أخرى.');
    }
  }

  Future<void> _signOutParent() async {
    if (_isSigningOut) {
      return;
    }

    setState(() => _isSigningOut = true);
    try {
      await _localNotificationService.clearManagedNotifications();
      await _selectedChildService.clearSelectedChildId();
      await _authService.signOut();
      if (!mounted) {
        return;
      }
      context.go('/auth/login');
    } on AuthFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('تعذر تسجيل الخروج حالياً. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1E2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F1E2),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 8,
        title: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: _isSigningOut
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: _signOutParent,
                        tooltip: 'Logout',
                        icon: Transform.flip(
                          flipX: true,
                          child: const Icon(Icons.logout),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'اختر ملف الطفل الشخصي للمتابعة',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: const Color(0xFFD6A23C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: Color(0xFF8E8A7F), thickness: 1, height: 1),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 720
                ? 72.0
                : constraints.maxWidth >= 480
                ? 40.0
                : 20.0;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      StreamBuilder<List<ChildProfile>>(
                        stream: _childService.watchChildren(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 48),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (snapshot.hasError) {
                            return _StateMessage(
                              message:
                                  'تعذر تحميل ملفات الأطفال حالياً. حاول مرة أخرى.',
                              actionLabel: 'إعادة المحاولة',
                              onTap: () => setState(() {}),
                            );
                          }

                          final children =
                              snapshot.data ?? const <ChildProfile>[];
                          if (children.isEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const _StateMessage(
                                  message: 'لا يوجد أطفال مضافون بعد.',
                                ),
                                const SizedBox(height: 20),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _AddChildCard(
                                    onTap: _isSigningOut
                                        ? () {}
                                        : () => context.go(
                                            '/child-home/add-child',
                                          ),
                                  ),
                                ),
                              ],
                            );
                          }

                          final cards = <Widget>[
                            ...children.map<Widget>(
                              (child) => _ChildCard(
                                child: child,
                                onTap: _isSigningOut
                                    ? () {}
                                    : () => _showChildActions(child),
                              ),
                            ),
                            _AddChildCard(
                              onTap: _isSigningOut
                                  ? () {}
                                  : () => context.go('/child-home/add-child'),
                            ),
                          ];

                          return Directionality(
                            textDirection: TextDirection.rtl,
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: cards.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    childAspectRatio: 170 / 190,
                                  ),
                              itemBuilder: (context, index) => cards[index],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.height = 52,
    this.fontSize = 16,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final double height;
  final double fontSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: enabled
                ? const [Color(0xFF1F8A3D), Color(0xFF77C19B)]
                : const [Color(0xFFBABABA), Color(0xFFD2D2D2)],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: enabled ? onTap : null,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: enabled ? Colors.white : const Color(0xFF6E6E6E),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteActionButton extends StatelessWidget {
  const _DeleteActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: Colors.red.shade400,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message, this.actionLabel, this.onTap});

  final String message;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x14B48C6A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFB48C6A),
            ),
          ),
          if (actionLabel != null && onTap != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onTap,
              child: Text(
                actionLabel!,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFD6A23C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.onTap});

  final ChildProfile child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 170,
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFEADFC8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A57A6).withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChildAvatar(avatarBase64: child.avatarBase64),
              const SizedBox(height: 12),
              Text(
                child.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB48C6A),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildAvatar extends StatefulWidget {
  const _ChildAvatar({required this.avatarBase64});

  final String? avatarBase64;

  @override
  State<_ChildAvatar> createState() => _ChildAvatarState();
}

class _ChildAvatarState extends State<_ChildAvatar> {
  static const int _maxAvatarBase64Length = 600 * 1024;
  Uint8List? _avatarBytes;
  String? _lastBase64;

  @override
  void initState() {
    super.initState();
    _decodeAvatarIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ChildAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarBase64 != widget.avatarBase64) {
      _decodeAvatarIfNeeded();
    }
  }

  void _decodeAvatarIfNeeded() {
    final avatarBase64 = widget.avatarBase64;
    if (avatarBase64 == _lastBase64) {
      return;
    }
    _lastBase64 = avatarBase64;

    if (avatarBase64 == null ||
        avatarBase64.isEmpty ||
        avatarBase64.length > _maxAvatarBase64Length) {
      if (_avatarBytes != null && mounted) {
        setState(() {
          _avatarBytes = null;
        });
      } else {
        _avatarBytes = null;
      }
      return;
    }

    unawaited(_decodeAvatarInBackground(avatarBase64));
  }

  Future<void> _decodeAvatarInBackground(String avatarBase64) async {
    final decoded = await compute(_decodeAvatarBase64, avatarBase64);
    if (!mounted || _lastBase64 != avatarBase64) {
      return;
    }
    setState(() {
      _avatarBytes = decoded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 38,
      backgroundColor: const Color(0xFFF5F5F5),
      backgroundImage: _avatarBytes == null ? null : MemoryImage(_avatarBytes!),
      child: _avatarBytes == null
          ? const Icon(Icons.child_care, color: Color(0xFFB48C6A), size: 34)
          : null,
    );
  }
}

Uint8List? _decodeAvatarBase64(String avatarBase64) {
  try {
    return base64Decode(avatarBase64);
  } catch (_) {
    return null;
  }
}

class _AddChildCard extends StatelessWidget {
  const _AddChildCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 170,
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5ABCA4), Color(0xFF9EDBC7)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A57A6).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0x80FFFFFF),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 44, color: Color(0xF2FFFFFF)),
                SizedBox(height: 8),
                Text(
                  'إضافة طفل',
                  style: TextStyle(
                    color: Color(0xF2FFFFFF),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
