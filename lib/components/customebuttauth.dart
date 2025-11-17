import 'package:flutter/material.dart';

class CustomeButtonAuth extends StatelessWidget {
  final void Function()? onPressed;
  final String title;
  const CustomeButtonAuth({super.key, this.onPressed, required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(title),
      ),
    );
  }
}
