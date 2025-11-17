import 'package:firebase/shared/user_service.dart';
import 'package:flutter/material.dart';
import 'admin_profile.dart';
import 'user_profile.dart';

class ProfileRedirector extends StatelessWidget {
  final UserService userService = UserService();

  ProfileRedirector({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: userService.getUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(body: Center(child: Text("Error loading profile")));
        }

        final role = snapshot.data!;
        return role == 'admin' ? AdminProfilePage() : UserProfilePage();
      },
    );
  }
}
