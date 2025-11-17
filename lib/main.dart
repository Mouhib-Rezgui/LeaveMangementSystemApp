import 'package:firebase/auth/login.dart';
import 'package:firebase/auth/sign_up.dart';
import 'package:firebase/homepage.dart';
import 'package:firebase/screens/EditUserProfilePage.dart';
import 'package:firebase/screens/ProfileRedirector.dart';
import 'package:firebase/screens/demandeconge.dart';
//import 'package:firebase/profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  get userData => null;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF4F46E5);
    final Color secondaryColor = const Color(0xFF6366F1);
    final Color backgroundColor = const Color(0xFFF8FAFC);
    final Color surfaceColor = Colors.white;
    final Color textColor = const Color(0xFF111827);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
          background: backgroundColor,
          surface: surfaceColor,
        ),
        scaffoldBackgroundColor: backgroundColor,
        textTheme: GoogleFonts.poppinsTextTheme().apply(
          bodyColor: textColor,
          displayColor: textColor,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardTheme(
          color: surfaceColor,
          elevation: 4,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        dividerTheme: const DividerThemeData(thickness: 1, space: 24),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home:
          (FirebaseAuth.instance.currentUser != null &&
                  FirebaseAuth.instance.currentUser!.emailVerified)
              ? Login()
              : Login(),
      routes: {
        "Signup": (context) => SignUp(),
        "Login": (context) => Login(),
        "HomePage": (context) => Homepage(),
        "ProfileRedirector": (context) => ProfileRedirector(),
        //'ProfilePage': (context) => ProfilePage(),
        "DemandeCongePage": (context) => DemandeCongePage(typeConge: ''),
        'EditUserProfilePage': (context) => EditUserProfilePage(),
      },
    );
  }
}
