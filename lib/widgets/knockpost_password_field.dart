import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/haptic_helper.dart';

enum PasswordStrength { none, weak, medium, strong }

class KnockPostPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<bool>? onValidityChanged;
  final bool autofocus;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;

  const KnockPostPasswordField({
    super.key,
    required this.controller,
    this.onValidityChanged,
    this.autofocus = false,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  @override
  State<KnockPostPasswordField> createState() => _KnockPostPasswordFieldState();
}

class _KnockPostPasswordFieldState extends State<KnockPostPasswordField> with TickerProviderStateMixin {
  bool _isObscured = true;
  bool _showErrors = false;
  
  PasswordStrength _strength = PasswordStrength.none;
  List<String> _errorMessages = [];
  bool _isValid = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  late AnimationController _strengthAnimController;
  late Animation<double> _strengthWidthAnimation;
  late Animation<Color?> _strengthColorAnimation;

  static const List<String> _commonPasswords = [
    '12345678', 'password', 'qwerty', 'admin123',
    '123456789', '1234567890', 'password123'
  ];

  @override
  void initState() {
    super.initState();
    
    // Shake animation
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_shakeController)
      ..addListener(() {
        setState(() {});
      });

    // Strength Bar animation
    _strengthAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _strengthWidthAnimation = Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(
      parent: _strengthAnimController,
      curve: Curves.easeOutCubic,
    ));
    _strengthColorAnimation = ColorTween(begin: Colors.transparent, end: Colors.transparent).animate(CurvedAnimation(
      parent: _strengthAnimController,
      curve: Curves.easeOutCubic,
    ));

    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _strengthAnimController.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  double get _shakeOffset {
    return sin(_shakeAnimation.value * pi * 6) * 6; // 3 shakes, max offset 6
  }

  void triggerShake() {
    if (!_shakeController.isAnimating) {
      _shakeController.forward(from: 0.0);
    }
    setState(() {
      _showErrors = true;
    });
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    _validate(text);
  }

  void _validate(String text) {
    List<String> errors = [];
    int score = 0;
    
    if (text.isEmpty) {
      _updateState(PasswordStrength.none, [], false, 0.0, Colors.transparent);
      return;
    }

    // Check common passwords
    if (_commonPasswords.contains(text.toLowerCase())) {
      errors.add("Password is too common");
    }

    // Length check
    if (text.length < 8 || text.length > 32) {
      errors.add("Password must be between 8 and 32 characters");
    } else {
      score += 1;
    }

    // Uppercase
    if (!RegExp(r'[A-Z]').hasMatch(text)) {
      errors.add("Must contain at least 1 uppercase letter");
    } else {
      score += 1;
    }

    // Lowercase
    if (!RegExp(r'[a-z]').hasMatch(text)) {
      errors.add("Must contain at least 1 lowercase letter");
    } else {
      score += 1;
    }

    // Number
    if (!RegExp(r'[0-9]').hasMatch(text)) {
      errors.add("Must contain at least 1 number");
    } else {
      score += 1;
    }

    // Special Char
    if (!RegExp(r'[!@#\$%^&*]').hasMatch(text)) {
      errors.add("Must contain at least 1 special character (!@#\$%^&*)");
    } else {
      score += 1;
    }

    bool isValid = errors.isEmpty;
    PasswordStrength strength;
    double targetWidthFactor;
    Color targetColor;

    if (_commonPasswords.contains(text.toLowerCase())) {
      score = 0;
    }

    if (score <= 2) {
      strength = PasswordStrength.weak;
      targetWidthFactor = 0.33;
      targetColor = Colors.red;
    } else if (score <= 4) {
      strength = PasswordStrength.medium;
      targetWidthFactor = 0.66;
      targetColor = Colors.orange;
    } else {
      strength = PasswordStrength.strong;
      targetWidthFactor = 1.0;
      targetColor = Colors.green;
    }

    if (text.isEmpty) {
      strength = PasswordStrength.none;
      targetWidthFactor = 0.0;
      targetColor = Colors.transparent;
    }

    _updateState(strength, errors, isValid, targetWidthFactor, targetColor);
  }

  void _updateState(PasswordStrength strength, List<String> errors, bool isValid, double targetWidth, Color targetColor) {
    if (_strength != strength || _isValid != isValid || _errorMessages.length != errors.length) {
      setState(() {
        _strength = strength;
        _errorMessages = errors;
        _isValid = isValid;
        
        // Show success animation logic when it becomes valid
        if (isValid && !_showErrors) {
          KnockHaptics.impact();
        }
      });
      
      if (widget.onValidityChanged != null) {
        widget.onValidityChanged!(isValid);
      }
    } else {
       // if errors list content changed but length is same, just update
       setState(() {
         _errorMessages = errors;
       });
    }

    // Animate strength bar
    final currentColor = _strengthColorAnimation.value ?? Colors.transparent;
    final currentWidth = _strengthWidthAnimation.value;
    
    _strengthWidthAnimation = Tween<double>(begin: currentWidth, end: targetWidth).animate(CurvedAnimation(
      parent: _strengthAnimController,
      curve: Curves.easeOutCubic,
    ));
    
    _strengthColorAnimation = ColorTween(begin: currentColor, end: targetColor).animate(CurvedAnimation(
      parent: _strengthAnimController,
      curve: Curves.easeOutCubic,
    ));
    
    _strengthAnimController.forward(from: 0.0);
  }

  String _getStrengthText() {
    switch (_strength) {
      case PasswordStrength.weak: return "Weak";
      case PasswordStrength.medium: return "Medium";
      case PasswordStrength.strong: return "Strong";
      default: return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.backgroundColor ?? (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2));
    final textCol = widget.textColor ?? (isDark ? Colors.white : Colors.black);
    
    final bool hasError = _showErrors && !_isValid;
    final Color currentBorderColor = hasError 
        ? Colors.red 
        : (_isValid ? Colors.green : (widget.borderColor ?? Colors.transparent));

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
            child: Column(
              children: [
                TextField(
                  controller: widget.controller,
                  autofocus: widget.autofocus,
                  obscureText: _isObscured,
                  style: TextStyle(color: textCol),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')), // no spaces
                  ],
                  decoration: InputDecoration(
                    hintText: "Password",
                    hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscured ? Icons.visibility_off : Icons.visibility,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      onPressed: () {
                        KnockHaptics.selection();
                        setState(() {
                          _isObscured = !_isObscured;
                        });
                      },
                    ),
                  ),
                ),
                
                // Strength Bar
                AnimatedBuilder(
                  animation: _strengthAnimController,
                  builder: (context, child) {
                    return Container(
                      height: 3,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black12,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _strengthWidthAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _strengthColorAnimation.value,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                ),
              ],
            ),
          ),
        ),
        
        // Strength Text & Success Status
        if (_strength != PasswordStrength.none)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getStrengthText(),
                  style: TextStyle(
                    color: _strengthColorAnimation.value ?? Colors.grey, 
                    fontSize: 13, 
                    fontWeight: FontWeight.w700
                  ),
                ),
                if (_isValid)
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
              ],
            ),
          ),
          
        // Error Messages
        if (_showErrors && _errorMessages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _errorMessages.map((err) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• ", style: TextStyle(color: Colors.red, fontSize: 13)),
                    Expanded(
                      child: Text(
                        err,
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }
}
