import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/system_nav_bar_fill.dart';

/// Data class for each social platform
class _SocialPlatform {
  final String key;
  final String name;
  final dynamic icon;
  final String hint;

  const _SocialPlatform({
    required this.key,
    required this.name,
    required this.icon,
    required this.hint,
  });
}

const _platforms = [
  _SocialPlatform(
    key: 'x',
    name: 'X',
    icon: FontAwesomeIcons.xTwitter,
    hint: 'username',
  ),
  _SocialPlatform(
    key: 'instagram',
    name: 'Instagram',
    icon: FontAwesomeIcons.instagram,
    hint: 'username',
  ),
  _SocialPlatform(
    key: 'linkedin',
    name: 'LinkedIn',
    icon: FontAwesomeIcons.linkedinIn,
    hint: 'profile URL or username',
  ),
  _SocialPlatform(
    key: 'youtube',
    name: 'Youtube',
    icon: FontAwesomeIcons.youtube,
    hint: 'channel name or URL',
  ),
];

class SocialLinksScreen extends StatefulWidget {
  final Map<String, String> initialLinks;

  const SocialLinksScreen({super.key, required this.initialLinks});

  @override
  State<SocialLinksScreen> createState() => _SocialLinksScreenState();
}

class _SocialLinksScreenState extends State<SocialLinksScreen>
    with TickerProviderStateMixin {
  late Map<String, String> _links;

  // Staggered entrance animation
  late AnimationController _staggerController;
  final List<Animation<double>> _itemAnimations = [];

  @override
  void initState() {
    super.initState();
    _links = Map.from(widget.initialLinks);

    _staggerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + (_platforms.length * 80)),
    );

    for (int i = 0; i < _platforms.length; i++) {
      final start = (i * 0.15).clamp(0.0, 0.7);
      final end = (start + 0.4).clamp(0.0, 1.0);
      _itemAnimations.add(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    }

    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  void _addLink(_SocialPlatform platform) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;
    final fieldBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2);

    final ctrl = TextEditingController(text: _links[platform.key]);

    KnockHaptics.selection();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: bg,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 22),
                      decoration: BoxDecoration(
                        color: subColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: platform.icon is IconData
                            ? Icon(platform.icon,
                                color: isDark ? Colors.white : Colors.black,
                                size: 18)
                            : FaIcon(platform.icon,
                                color: isDark ? Colors.white : Colors.black,
                                size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        platform.name,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        hintText: platform.hint,
                        hintStyle: TextStyle(
                          color: textColor.withValues(alpha: 0.25),
                          fontSize: 15,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: GestureDetector(
                      onTap: () {
                        KnockHaptics.impact();
                        final value = ctrl.text.trim();
                        setState(() {
                          if (value.isEmpty) {
                            _links.remove(platform.key);
                          } else {
                            _links[platform.key] = value;
                          }
                        });
                        Navigator.pop(sheetContext);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: textColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Save',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.5,
                            color: bg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        );
      },
    );
  }

  void _removeLink(String key) {
    KnockHaptics.selection();
    setState(() {
      _links.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            Navigator.pop(context, _links);
          }
        },
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: bg,
              appBar: AppBar(
                backgroundColor: bg,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: textColor,
                  ),
                  onPressed: () => Navigator.pop(context, _links),
                ),
                centerTitle: true,
                title: Text(
                  'Social Links',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              body: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  // Section header with fade-in
                  FadeTransition(
                    opacity: _itemAnimations.isNotEmpty
                        ? _itemAnimations[0]
                        : const AlwaysStoppedAnimation(1.0),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
                      child: Text(
                        'SOCIAL LINKS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: subColor,
                        ),
                      ),
                    ),
                  ),
                  // Platform rows with staggered animation
                  ...List.generate(_platforms.length, (index) {
                    final platform = _platforms[index];
                    final hasLink = _links.containsKey(platform.key) &&
                        _links[platform.key]!.isNotEmpty;

                    return AnimatedBuilder(
                      animation: _itemAnimations[index],
                      builder: (context, child) {
                        final value = _itemAnimations[index].value;
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          // Tap the entire row to add/edit
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _addLink(platform),
                              splashColor: textColor.withValues(alpha: 0.04),
                              highlightColor:
                                  textColor.withValues(alpha: 0.02),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    // Platform icon container
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      curve: Curves.easeOutCubic,
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.12)
                                            : Colors.black
                                                .withValues(alpha: 0.07),
                                        shape: BoxShape.circle,
                                      ),
                                      child: platform.icon is IconData
                                          ? Icon(
                                              platform.icon,
                                              size: 20,
                                              color: isDark ? Colors.white : Colors.black,
                                            )
                                          : FaIcon(
                                              platform.icon,
                                              size: 20,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Platform name and username
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            platform.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                          AnimatedSize(
                                            duration: const Duration(
                                                milliseconds: 250),
                                            curve: Curves.easeOutCubic,
                                            alignment: Alignment.topLeft,
                                            child: hasLink
                                                ? Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 3),
                                                    child: Text(
                                                      _links[platform.key]!,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: subColor,
                                                      ),
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Add/Remove button with animated switch
                                    GestureDetector(
                                      onTap: hasLink
                                          ? () => _removeLink(platform.key)
                                          : () => _addLink(platform),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 300),
                                        curve: Curves.easeOutCubic,
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: hasLink
                                                ? Colors.red.withValues(alpha: 0.5)
                                                : textColor,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                              milliseconds: 250),
                                          switchInCurve:
                                              Curves.easeOutCubic,
                                          switchOutCurve: Curves.easeIn,
                                          transitionBuilder: (child,
                                              animation) {
                                            return ScaleTransition(
                                              scale: animation,
                                              child: child,
                                            );
                                          },
                                          child: Icon(
                                            hasLink
                                                ? CupertinoIcons.minus
                                                : CupertinoIcons.plus,
                                            key: ValueKey(hasLink),
                                            size: 18,
                                            color: hasLink
                                                ? Colors.red.withValues(alpha: 0.8)
                                                : textColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SystemNavBarFill(color: bg),
            ),
          ],
        ),
      ),
    );
  }
}
