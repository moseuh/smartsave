import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'package:flutter/services.dart';

/// Custom app bar with gradient
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Gradient? gradient;
  final Color? textColor;
  final double elevation;

  const GradientAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.gradient,
    this.textColor,
    this.elevation = 0,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: elevation,
                  offset: Offset(0, elevation / 2),
                ),
              ]
            : null,
      ),
      child: AppBar(
        title: Text(
          title,
          style: TextStyle(
            color: textColor ?? AppTheme.cardLight,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: centerTitle,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: leading,
        actions: actions,
        iconTheme: IconThemeData(color: textColor ?? AppTheme.cardLight),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
    );
  }
}

