// Custom button widget for testing architecture rules
import 'package:flutter/material.dart';

/// Custom button widget that follows architecture patterns
/// This file should trigger architecture-specific Flutter rules
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonType type;
  final ButtonSize size;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _getColors(theme);
    final dimensions = _getDimensions();

    return SizedBox(
      height: dimensions.height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.backgroundColor,
          foregroundColor: colors.textColor,
          padding: padding ?? dimensions.padding,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? dimensions.borderRadius,
          ),
          elevation: type == ButtonType.primary ? 2 : 0,
        ),
        child: _buildContent(colors.textColor),
      ),
    );
  }

  Widget _buildContent(Color textColor) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 8), Text(text)],
      );
    }

    return Text(text);
  }

  _ButtonColors _getColors(ThemeData theme) {
    switch (type) {
      case ButtonType.primary:
        return _ButtonColors(
          backgroundColor: backgroundColor ?? theme.colorScheme.primary,
          textColor: textColor ?? theme.colorScheme.onPrimary,
        );
      case ButtonType.secondary:
        return _ButtonColors(
          backgroundColor: backgroundColor ?? theme.colorScheme.secondary,
          textColor: textColor ?? theme.colorScheme.onSecondary,
        );
      case ButtonType.outline:
        return _ButtonColors(
          backgroundColor: Colors.transparent,
          textColor: textColor ?? theme.colorScheme.primary,
        );
      case ButtonType.text:
        return _ButtonColors(
          backgroundColor: Colors.transparent,
          textColor: textColor ?? theme.colorScheme.primary,
        );
    }
  }

  _ButtonDimensions _getDimensions() {
    switch (size) {
      case ButtonSize.small:
        return _ButtonDimensions(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          borderRadius: BorderRadius.circular(6),
        );
      case ButtonSize.medium:
        return _ButtonDimensions(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          borderRadius: BorderRadius.circular(8),
        );
      case ButtonSize.large:
        return _ButtonDimensions(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          borderRadius: BorderRadius.circular(10),
        );
    }
  }
}

/// Button type enumeration
enum ButtonType { primary, secondary, outline, text }

/// Button size enumeration
enum ButtonSize { small, medium, large }

/// Internal classes for button styling
class _ButtonColors {
  final Color backgroundColor;
  final Color textColor;

  const _ButtonColors({required this.backgroundColor, required this.textColor});
}

class _ButtonDimensions {
  final double height;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const _ButtonDimensions({
    required this.height,
    required this.padding,
    required this.borderRadius,
  });
}
