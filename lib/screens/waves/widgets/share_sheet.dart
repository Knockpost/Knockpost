import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/user_model.dart';
import '../../../utils/haptic_helper.dart';
import '../../../utils/image_helper.dart';
import '../../../services/connection_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/database_service.dart';
import '../../../services/performance_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ShareSheet extends StatefulWidget {
  final String url;
  final String username;
  final String caption;
  final String contentType;

  const ShareSheet({
    super.key,
    required this.url,
    required this.username,
    required this.caption,
    this.contentType = 'post',
  });

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet>
    with SingleTickerProviderStateMixin {
  List<String> _allUids = [];
  final List<UserModel> _allUsers = [];
  List<UserModel> _filtered = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _isSending = false;
  bool _linkCopied = false;

  final Set<String> _selected = {};
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();
  final FocusNode _msgFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  late AnimationController _sendBtnCtrl;
  late Animation<double> _sendBtnScale;

  @override
  void initState() {
    super.initState();

    _sendBtnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _sendBtnScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _sendBtnCtrl, curve: Curves.easeInOut),
    );

    _searchCtrl.addListener(_onSearch);
    _scrollCtrl.addListener(_onScroll);
    _loadConnections();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _msgCtrl.dispose();
    _msgFocus.dispose();
    _scrollCtrl.dispose();
    _sendBtnCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMoreConnections();
    }
  }

  /// Phase S3: Virtualized Pagination
  Future<void> _loadConnections() async {
    try {
      _allUids = await ConnectionService.instance.streamMutualConnectionUids().first;
      await _loadMoreConnections();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreConnections() async {
    if (_isFetchingMore || _allUsers.length >= _allUids.length) return;
    
    setState(() => _isFetchingMore = true);
    const int nextBatchCount = 20;
    final startIndex = _allUsers.length;
    final endIndex = (startIndex + nextBatchCount).clamp(0, _allUids.length);
    final batchUids = _allUids.sublist(startIndex, endIndex);

    try {
      // Lazy load via cache layer
      final results = await Future.wait(
        batchUids.map((uid) => DatabaseService.instance.getUserById(uid)),
      );

      final users = results.whereType<UserModel>().toList();
      
      // S3 Telemetry
      PerformanceService.instance.incrementShareSheetPagesLoaded();
      for (int i=0; i<users.length; i++) {
        PerformanceService.instance.incrementShareSheetVirtualizedRows();
      }
      // Estimate memory savings: 1 UserModel = ~1024 bytes in memory. 
      // Savings = (Total UIDs - Loaded Users) * 1024 bytes
      final unloadedCount = _allUids.length - (_allUsers.length + users.length);
      PerformanceService.instance.addShareSheetMemorySavingsEstimate(unloadedCount * 1024);

      if (mounted) {
        setState(() {
          _allUsers.addAll(users);
          _isLoading = false;
          _isFetchingMore = false;
          _onSearch(); // Reapply search filter to new items
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _allUsers
          : _allUsers
              .where((u) =>
                  u.displayName.toLowerCase().contains(q) ||
                  u.username.toLowerCase().contains(q))
              .toList();
    });
  }

  void _toggleSelect(String uid) {
    KnockHaptics.selection();
    setState(() {
      if (_selected.contains(uid)) {
        _selected.remove(uid);
      } else {
        _selected.add(uid);
      }
    });
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _isSending) return;
    KnockHaptics.impact();

    _sendBtnCtrl.forward().then((_) => _sendBtnCtrl.reverse());
    setState(() => _isSending = true);

    final extra = _msgCtrl.text.trim();
    final text = [
      if (extra.isNotEmpty) extra,
      'Check out this ${widget.contentType} by @${widget.username} on KnockPost!',
      if (widget.caption.isNotEmpty) '"${widget.caption}"',
      widget.url,
    ].join('\n\n');

    try {
      // Phase S2: Hyper-Scale Fan-Out Architecture
      await FirebaseFunctions.instance.httpsCallable('sharePostToConnections').call({
        'text': text,
        'recipientUids': _selected.toList(),
      });
    } catch (e) {
      debugPrint('Cloud Function sharePostToConnections failed: $e. Falling back to local dispatch.');
      // Fallback: Legacy local parallel dispatch
      await Future.wait(
        _selected.map((uid) => ChatService.instance
            .sendMessage(otherUid: uid, text: text)
            .catchError((_) {})),
      );
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(_selected.length == 1
              ? 'Sent to 1 person'
              : 'Sent to ${_selected.length} people'),
        ]),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111118) : Colors.white;
    final surface =
        isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111118);
    final subColor =
        isDark ? Colors.white38 : const Color(0xFF111118).withValues(alpha: 0.38);
    final inputBg =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2);

    final canSend = _selected.isNotEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.87,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.12),
              blurRadius: 40,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: subColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 4),

            // ── Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: subColor, size: 22),
                    splashRadius: 20,
                  ),
                  Expanded(
                    child: Text(
                      'Share',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(color: subColor, fontSize: 14),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: subColor,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── User grid
            Flexible(
              child: _isLoading
                  ? _buildShimmer(isDark)
                  : _filtered.isEmpty
                      ? _buildEmpty(subColor)
                      : GridView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          physics: const BouncingScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 18,
                            crossAxisSpacing: 4,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final u = _filtered[i];
                            return _UserCell(
                              key: ValueKey(u.id),
                              user: u,
                              isSelected: _selected.contains(u.id),
                              isDark: isDark,
                              textColor: textColor,
                              subColor: subColor,
                              onTap: () => _toggleSelect(u.id),
                            );
                          },
                        ),
            ),

            // ── Divider
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.06),
            ),

            // ── Bottom area (message + send)
            Padding(
              padding: EdgeInsets.fromLTRB(
                16, 14, 16,
                24 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Message input
                  Container(
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _msgFocus.hasFocus
                            ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
                            : (isDark ? Colors.white10 : Colors.black12),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _msgCtrl,
                      focusNode: _msgFocus,
                      onTap: () => setState(() {}), // rebuild border color
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        height: 1.45,
                      ),
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Add a message…',
                        hintStyle:
                            TextStyle(color: subColor, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Send button
                  ScaleTransition(
                    scale: _sendBtnScale,
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          gradient: canSend
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF6C63FF),
                                    Color(0xFF48CAE4),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : null,
                          color: canSend ? null : inputBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canSend ? _send : null,
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: _isSending
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: KnockPostLoadingIndicator(),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.send_rounded,
                                          size: 18,
                                          color: canSend
                                              ? Colors.white
                                              : subColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Send',
                                          style: TextStyle(
                                            color: canSend
                                                ? Colors.white
                                                : subColor,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Copy + Share via row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Copy Link with animated ✓ feedback ──
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _linkCopied
                            ? null
                            : () async {
                                KnockHaptics.selection();
                                await Clipboard.setData(
                                    ClipboardData(text: widget.url));
                                if (!mounted) return;
                                setState(() => _linkCopied = true);
                                await Future.delayed(
                                    const Duration(milliseconds: 2500));
                                if (mounted) setState(() => _linkCopied = false);
                              },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: _linkCopied
                              ? Row(
                                  key: const ValueKey('copied'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 15,
                                      color: textColor,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Copied!',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  key: const ValueKey('copy'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.link_rounded,
                                        size: 15, color: textColor),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Copy Link',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 14,
                        color: subColor.withValues(alpha: 0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      _QuickAction(
                        icon: Icons.share_rounded,
                        label: 'More options',
                        color: textColor,
                        onTap: () {
                          KnockHaptics.selection();
                          Navigator.pop(context);
                          Share.share(
                            'Check out this ${widget.contentType} by @${widget.username} on KnockPost!\n\n'
                            '${widget.caption.isNotEmpty ? '"${widget.caption}"\n\n' : ''}'
                            '${widget.url}',
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer(bool isDark) {
    final shimmerColor =
        isDark ? const Color(0xFF252535) : const Color(0xFFEEEEF5);
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 18,
        crossAxisSpacing: 4,
        childAspectRatio: 0.72,
      ),
      itemCount: 8,
      itemBuilder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ShimmerBox(width: 58, height: 58, radius: 29, color: shimmerColor),
          const SizedBox(height: 7),
          _ShimmerBox(width: 44, height: 9, radius: 5, color: shimmerColor),
          const SizedBox(height: 4),
          _ShimmerBox(width: 36, height: 8, radius: 4, color: shimmerColor),
        ],
      ),
    );
  }

  Widget _buildEmpty(Color subColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_alt_outlined,
              size: 48, color: subColor.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            _searchCtrl.text.isEmpty
                ? 'No connections yet'
                : 'No match found',
            style: TextStyle(
              color: subColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── User Cell ─────────────────────────────────────────────────────────────────

class _UserCell extends StatefulWidget {
  final UserModel user;
  final bool isSelected;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final VoidCallback onTap;

  const _UserCell({
    super.key,
    required this.user,
    required this.isSelected,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.onTap,
  });

  @override
  State<_UserCell> createState() => _UserCellState();
}

class _UserCellState extends State<_UserCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.04), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _UserCell old) {
    super.didUpdateWidget(old);
    if (widget.isSelected != old.isSelected) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = ImageHelper.resolveAvatar(widget.user.avatarAsset);
    const s = 60.0;

    final palette = [
      const Color(0xFF6C63FF),
      const Color(0xFFFF6584),
      const Color(0xFF43C6AC),
      const Color(0xFFFFBE7B),
      const Color(0xFF5ECFE8),
      const Color(0xFFFC5C7D),
    ];
    final fallback =
        palette[widget.user.username.hashCode.abs() % palette.length];

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Avatar with animated ring
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isSelected ? widget.textColor : null,
                    border: widget.isSelected
                        ? null
                        : Border.all(
                            color: widget.isDark
                                ? Colors.white10
                                : Colors.black12,
                            width: 1,
                          ),
                    boxShadow: widget.isSelected
                        ? [
                            BoxShadow(
                              color: widget.textColor.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  padding:
                      widget.isSelected ? const EdgeInsets.all(2.5) : null,
                  child: ClipOval(
                    child: img != null
                        ? Image(
                            image: img,
                            width: s,
                            height: s,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: fallback,
                            alignment: Alignment.center,
                            child: Text(
                              widget.user.displayName.isNotEmpty
                                  ? widget.user.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                ),

                // ✓ badge
                if (widget.isSelected)
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: widget.textColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isDark
                              ? const Color(0xFF111118)
                              : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: widget.isDark ? Colors.black : Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 7),

            Text(
              widget.user.displayName.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.textColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '@${widget.user.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.subColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer placeholder ────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width, height, radius;
  final Color color;
  const _ShimmerBox(
      {required this.width,
      required this.height,
      required this.radius,
      required this.color});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ── Quick action link ─────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
