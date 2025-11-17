import 'package:flutter/material.dart';

class CustomeLogoAuth extends StatelessWidget {
  const CustomeLogoAuth({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Container(
        alignment: Alignment.center,
        width: 120,
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(200),
          border: Border.all(color: primary.withOpacity(0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Image.asset("images/logo.png", height: 80, fit: BoxFit.contain),
      ),
    );
  }
}
