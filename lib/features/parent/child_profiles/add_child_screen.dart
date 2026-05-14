import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:risha_v01/shared/services/child_service.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  static const _maxImageSizeBytes = 350 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _childService = ChildService();
  final _imagePicker = ImagePicker();

  Uint8List? _selectedImageBytes;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isSubmitting) {
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxHeight: 512,
      maxWidth: 512,
    );

    if (picked == null) {
      return;
    }

    final path = picked.path.toLowerCase();
    final hasSupportedExtension =
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.heic') ||
        path.endsWith('.heif');

    if (!hasSupportedExtension) {
      _showError('الملف المحدد ليس صورة مدعومة.');
      return;
    }

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      _showError('تعذر قراءة الصورة. حاول اختيار صورة أخرى.');
      return;
    }

    if (bytes.lengthInBytes > _maxImageSizeBytes) {
      _showError('الصورة كبيرة جداً. اختر صورة أصغر من 350 كيلوبايت.');
      return;
    }

    setState(() => _selectedImageBytes = bytes);
  }

  Future<void> _submitAddChild() async {
    if (_isSubmitting) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final existingChildren = await _childService.getCachedChildren();
      final enteredName = _nameController.text.trim().toLowerCase();
      final nameExists = existingChildren.any(
        (c) => c.name.trim().toLowerCase() == enteredName,
      );

      if (nameExists) {
        if (!mounted) return;
        _showError('يوجد طفل مسجل مسبقاً بنفس هذا الاسم.');
        setState(() => _isSubmitting = false);
        return;
      }

      final avatarBase64 = _selectedImageBytes == null
          ? null
          : base64Encode(_selectedImageBytes!);

      final ageYears = int.tryParse(_ageController.text.trim());
      if (ageYears == null || ageYears < 3) {
        if (!mounted) return;
        _showError('العمر المسموح به هو من 3 وأكثر.');
        return;
      }

      await _childService.addChild(
        name: _nameController.text,
        ageYears: ageYears,
        avatarBase64: avatarBase64,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة الطفل بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          context.go('/child-home/profiles');
        }
      });
    } on ChildFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('تعذر إضافة الطفل حالياً. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'الرجاء إدخال اسم الطفل.';
    }
    if (name.length < 2) {
      return 'الاسم قصير جداً.';
    }
    if (name.length > 30) {
      return 'الاسم طويل جداً (الحد الأقصى 30 حرفاً).';
    }
    if (RegExp(r'^\d+$').hasMatch(name)) {
      return 'الاسم لا يمكن أن يكون أرقاماً فقط.';
    }
    if (!RegExp(
      r'^[A-Za-z\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\s]+$',
    ).hasMatch(name)) {
      return 'الاسم يجب أن يحتوي على حروف عربية أو إنجليزية فقط.';
    }
    return null;
  }

  String? _validateAge(String? value) {
    final ageText = value?.trim() ?? '';
    if (ageText.isEmpty) {
      return 'الرجاء إدخال عمر الطفل.';
    }
    final age = int.tryParse(ageText);
    if (age == null) {
      return 'العمر يجب أن يكون رقمًا صحيحًا.';
    }
    if (age < 3) {
      return 'العمر المسموح به هو من 3 وأكثر.';
    }
    return null;
  }

  int? get _enteredAge => int.tryParse(_ageController.text.trim());

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enteredAge = _enteredAge; // تعريف المتغير خارج قائمة children

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1E2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 720
                ? 72.0
                : constraints.maxWidth >= 480
                ? 40.0
                : 20.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 16,
                  ),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        final router = GoRouter.of(context);
                                        if (router.canPop()) {
                                          context.pop();
                                        } else {
                                          context.go('/child-home/profiles');
                                        }
                                      },
                                icon: const Icon(Icons.arrow_back),
                              ),
                              Expanded(
                                child: Text(
                                  'إضافة طفل جديد',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: const Color(0xFFD6A23C),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(
                          color: Color(0xFF8E8A7F),
                          thickness: 1,
                          height: 1,
                        ),
                        const SizedBox(height: 26),
                        _ChildAvatarPicker(
                          imageBytes: _selectedImageBytes,
                          onTap: _pickImage,
                          onClear: _selectedImageBytes == null || _isSubmitting
                              ? null
                              : () =>
                                    setState(() => _selectedImageBytes = null),
                        ),
                        const SizedBox(height: 22),
                        _ChildNameField(
                          controller: _nameController,
                          validator: _validateName,
                        ),
                        const SizedBox(height: 10),
                        _ChildAgeField(
                          controller: _ageController,
                          validator: _validateAge,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),

                        // ========== إشعارات العمر حسب القواعد الجديدة ==========
                        if (enteredAge != null) ...[
                          if (enteredAge < 5) ...[
                            const SizedBox(height: 10),
                            const _AgeNotice(
                              text: 'يُنصح بمساعدة ولي الأمر أثناء الاستخدام.',
                              icon: Icons.help_outline,
                            ),
                          ] else if (enteredAge > 12) ...[
                            const SizedBox(height: 10),
                            const _AgeNotice(
                              text:
                                  'هذا التطبيق مصمم بشكل أساسي للأطفال من عمر 5 إلى 12 سنة، ويمكن استخدامه من قبل الأعمار الأخرى.',
                              icon: Icons.info_outline,
                            ),
                          ],
                          // للأعمار من 5 إلى 12 لا يتم عرض أي شيء
                        ],

                        // =====================================================
                        const SizedBox(height: 10),
                        const _ChildInfoHint(),
                        const SizedBox(height: 40),
                        _AddChildButton(
                          onTap: _isSubmitting ? null : _submitAddChild,
                          isLoading: _isSubmitting,
                        ),
                      ],
                    ),
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

class _ChildAvatarPicker extends StatelessWidget {
  const _ChildAvatarPicker({
    required this.imageBytes,
    required this.onTap,
    required this.onClear,
  });

  final Uint8List? imageBytes;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(55),
              onTap: onTap,
              child: Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F1F1),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: imageBytes == null
                    ? const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: Color(0xFFA7D7BE),
                        size: 42,
                      )
                    : Image.memory(imageBytes!, fit: BoxFit.cover),
              ),
            ),
          ),
          if (onClear != null)
            Positioned(
              top: -6,
              left: -6,
              child: GestureDetector(
                onTap: onClear,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Color(0xFFB48C6A),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChildNameField extends StatelessWidget {
  const _ChildNameField({required this.controller, required this.validator});

  final TextEditingController controller;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      textAlign: TextAlign.right,
      style: const TextStyle(color: Color(0xFFB48C6A), fontSize: 16),
      decoration: InputDecoration(
        hintText: 'أدخل اسم الطفل',
        hintStyle: const TextStyle(color: Color(0xFFC49B6B), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD6A23C), width: 1.1),
        ),
        prefixIcon: Container(
          width: 62,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFFE8C864), width: 1.2),
            ),
          ),
          child: const Icon(
            FontAwesomeIcons.baby,
            color: Color(0xFFD6A23C),
            size: 22,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minHeight: 52,
          minWidth: 62,
        ),
      ),
    );
  }
}

class _ChildAgeField extends StatelessWidget {
  const _ChildAgeField({
    required this.controller,
    required this.validator,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.right,
      style: const TextStyle(color: Color(0xFFB48C6A), fontSize: 16),
      decoration: InputDecoration(
        hintText: 'أدخل عمر الطفل',
        hintStyle: const TextStyle(color: Color(0xFFC49B6B), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD6A23C), width: 1.1),
        ),
        prefixIcon: Container(
          width: 62,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFFE8C864), width: 1.2),
            ),
          ),
          child: const Icon(
            FontAwesomeIcons.calendarDays,
            color: Color(0xFFD6A23C),
            size: 20,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minHeight: 52,
          minWidth: 62,
        ),
      ),
    );
  }
}

class _ChildInfoHint extends StatelessWidget {
  const _ChildInfoHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFF62BBA0), Color(0xFF8FD0B9)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A57A6).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: Color(0xFFF5E19B), size: 14),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'يمكنك لاحقاً تعديل ملف الطفل وتخصيص صورة له.',
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.white, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddChildButton extends StatelessWidget {
  const _AddChildButton({required this.onTap, required this.isLoading});

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 230,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFF1F8A3D), Color(0xFF5DA57F)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A57A6).withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onTap,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'إضافة الطفل',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgeNotice extends StatelessWidget {
  const _AgeNotice({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFFFF4D7),
        border: Border.all(color: const Color(0xFFD6A23C), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFD6A23C), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF9C6D2C),
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
