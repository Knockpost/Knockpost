import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';

enum UsernameStatus {
  idle,
  checking,
  invalid,
  available,
  taken,
}

class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}

class KnockpostUsernameField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<bool>? onValidityChanged;
  final String? initialUsername;
  final bool autofocus;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;

  const KnockpostUsernameField({
    super.key,
    required this.controller,
    this.onValidityChanged,
    this.initialUsername,
    this.autofocus = false,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  @override
  State<KnockpostUsernameField> createState() => _KnockpostUsernameFieldState();
}

class _KnockpostUsernameFieldState extends State<KnockpostUsernameField> with SingleTickerProviderStateMixin {
  Timer? _debounce;
  UsernameStatus _status = UsernameStatus.idle;
  String _errorMessage = '';
  List<String> _suggestions = [];
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_shakeController)
      ..addListener(() {
        setState(() {});
      });

    widget.controller.addListener(_onTextChanged);
    
    if (widget.initialUsername != null && widget.initialUsername!.isNotEmpty) {
      _validateLocally(widget.initialUsername!);
      if (_status != UsernameStatus.invalid) {
         _status = UsernameStatus.available; 
         if (widget.onValidityChanged != null) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) widget.onValidityChanged!(true);
           });
         }
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _shakeController.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  double get _shakeOffset {
    // 3 shakes, max offset 6
    return sin(_shakeAnimation.value * pi * 6) * 6;
  }

  void _setStatus(UsernameStatus status, String errorMessage) {
    setState(() {
      _status = status;
      _errorMessage = errorMessage;
      
      if (status == UsernameStatus.invalid || status == UsernameStatus.taken) {
        if (!_shakeController.isAnimating) {
          _shakeController.forward(from: 0.0);
        }
      } else {
        _suggestions.clear();
      }
    });

    if (widget.onValidityChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onValidityChanged!(status == UsernameStatus.available);
      });
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text.trim();
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _validateLocally(text);

    if (_status == UsernameStatus.checking) {
      _debounce = Timer(const Duration(milliseconds: 500), () {
        _checkAvailability(text);
      });
    }
  }

  void _validateLocally(String text) {
    if (text.isEmpty) {
      _setStatus(UsernameStatus.idle, '');
      return;
    }
    if (text.length < 4 || text.length > 20) {
      _setStatus(UsernameStatus.invalid, 'Username must be between 4 and 20 characters');
      return;
    }
    if (text.contains(' ')) {
      _setStatus(UsernameStatus.invalid, 'Username cannot contain spaces');
      return;
    }
    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(text)) {
      _setStatus(UsernameStatus.invalid, "Only lowercase letters, numbers, '.' and '_' are allowed");
      return;
    }
    if (text.startsWith('.') || text.startsWith('_') || text.endsWith('.') || text.endsWith('_')) {
      _setStatus(UsernameStatus.invalid, "Username cannot start or end with '.' or '_'");
      return;
    }
    if (text.contains('..') || text.contains('__') || text.contains('._') || text.contains('_.')) {
      _setStatus(UsernameStatus.invalid, "Username cannot contain consecutive '.' or '_'");
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(text)) {
      _setStatus(UsernameStatus.invalid, "Username must contain at least one letter");
      return;
    }
    
    _setStatus(UsernameStatus.checking, '');
  }

  Future<void> _checkAvailability(String username) async {
    if (_status != UsernameStatus.checking) return;
    try {
      if (widget.initialUsername != null && widget.initialUsername!.toLowerCase() == username) {
         _setStatus(UsernameStatus.available, '');
         return;
      }

      final isTaken = await DatabaseService.instance.checkUsernameTaken(username);
      if (!mounted || widget.controller.text.trim() != username) return; 
      
      if (isTaken) {
         _setStatus(UsernameStatus.taken, 'This username is unavailable');
         _generateSuggestions(username);
      } else {
         _setStatus(UsernameStatus.available, '');
      }
    } catch (e) {
      if (mounted && widget.controller.text.trim() == username) {
        _setStatus(UsernameStatus.invalid, 'Error checking availability');
      }
    }
  }

  Future<void> _generateSuggestions(String baseUsername) async {
    final List<String> newSuggestions = [];
    final random = Random();
    
    // Suggestion 1: append random number
    newSuggestions.add('$baseUsername${random.nextInt(99) + 1}');
    
    // Suggestion 2: insert underscore
    if (!baseUsername.contains('_')) {
      newSuggestions.add('${baseUsername}_');
    } else {
      newSuggestions.add('$baseUsername${random.nextInt(999) + 100}');
    }
    
    // Suggestion 3: append letters or specific number
    newSuggestions.add('${baseUsername}x');

    final List<String> validSuggestions = [];
    for (var sug in newSuggestions) {
      // Fix potential trailing underscore
      if (sug.endsWith('_')) sug = sug.replaceAll(RegExp(r'_$'), '1');
      if (sug.length > 20) sug = sug.substring(0, 20);
      
      final isTaken = await DatabaseService.instance.checkUsernameTaken(sug);
      if (!isTaken) {
        validSuggestions.add(sug);
      }
      if (validSuggestions.length >= 3) break;
    }
    
    if (mounted && widget.controller.text.trim() == baseUsername) {
      setState(() {
        _suggestions = validSuggestions;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.backgroundColor ?? (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2));
    final textCol = widget.textColor ?? (isDark ? Colors.white : Colors.black);
    
    final bool hasError = _status == UsernameStatus.invalid || _status == UsernameStatus.taken;
    final Color currentBorderColor = hasError 
        ? Colors.red 
        : (_status == UsernameStatus.available ? Colors.green : (widget.borderColor ?? Colors.transparent));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: Offset(_shakeOffset, 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: currentBorderColor, width: 1.5),
            ),
            child: TextField(
              controller: widget.controller,
              autofocus: widget.autofocus,
              style: TextStyle(color: textCol),
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')), // no spaces
                LowerCaseTextFormatter(), // auto lowercase
              ],
              decoration: InputDecoration(
                hintText: "Username",
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                suffixIcon: _buildSuffixIcon(),
              ),
            ),
          ),
        ),
        
        // Error Message
        if (hasError && _errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          
        // Suggestions
        if (_status == UsernameStatus.taken && _suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Suggestions:",
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions.map((sug) => GestureDetector(
                    onTap: () {
                      widget.controller.text = sug;
                      widget.controller.selection = TextSelection.fromPosition(TextPosition(offset: sug.length));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        sug,
                        style: TextStyle(color: textCol, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (_status == UsernameStatus.idle && widget.controller.text.isEmpty) {
      return null;
    }
    
    Widget icon;
    if (_status == UsernameStatus.checking) {
      icon = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_status == UsernameStatus.available) {
      icon = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22);
    } else if (_status == UsernameStatus.invalid || _status == UsernameStatus.taken) {
      icon = const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22);
    } else {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: KeyedSubtree(
          key: ValueKey(_status),
          child: icon,
        ),
      ),
    );
  }
}
