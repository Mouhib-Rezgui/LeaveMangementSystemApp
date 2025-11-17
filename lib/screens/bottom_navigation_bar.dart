import 'package:firebase/screens/demandeconge.dart';
import 'package:firebase/screens/user_profile.dart';
import 'package:flutter/material.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  _UserHomePageState createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    UserProfilePage(),
    DemandeCongePage(typeConge: ''),
    //LeaveHistoryPage(), // if you have one
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
          BottomNavigationBarItem(
            icon: Icon(Icons.request_page),
            label: "Demande",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "Historique",
          ),
        ],
      ),
    );
  }
}
