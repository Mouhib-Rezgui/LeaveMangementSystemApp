import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase/components/customebuttauth.dart';
import 'package:firebase/components/customelogoauth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> with SingleTickerProviderStateMixin {
  final TextEditingController Username = TextEditingController();
  final TextEditingController Email = TextEditingController();
  final TextEditingController Password = TextEditingController();
  final TextEditingController ConfirmPassword = TextEditingController();
  final TextEditingController AdminPassword = TextEditingController();

  bool show = false;
  String? selectedRole;
  bool showAdminPasswordField = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool obscureAdminPassword = true;
  bool _isLoading = false;
  bool _isAdminPasswordValid = false;

  // Change this to your desired admin password
  final String _correctAdminPassword = "admin1234";

  // Validation errors
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _roleError;
  String? _adminPasswordError;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 500), () {
      setState(() => show = true);
    });
  }

  void _validateAdminPassword() {
    setState(() {
      _isAdminPasswordValid = AdminPassword.text == _correctAdminPassword;
      _adminPasswordError =
          _isAdminPasswordValid ? null : 'Mot de passe admin incorrect';
    });
  }

  void _validateForm() {
    setState(() {
      // Reset errors
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _roleError = null;
      _adminPasswordError = null;

      // Username validation
      if (Username.text.isEmpty) {
        _usernameError = 'Veuillez entrer un nom d\'utilisateur';
      } else if (Username.text.length < 3) {
        _usernameError = 'Le nom doit contenir au moins 3 caractères';
      }

      // Email validation
      if (Email.text.isEmpty) {
        _emailError = 'Veuillez entrer votre email';
      } else if (!RegExp(
        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
      ).hasMatch(Email.text)) {
        _emailError = 'Veuillez entrer un email valide';
      }

      // Password validation
      if (Password.text.isEmpty) {
        _passwordError = 'Veuillez entrer un mot de passe';
      } else if (Password.text.length < 6) {
        _passwordError = 'Le mot de passe doit contenir au moins 6 caractères';
      }

      // Confirm password validation
      if (ConfirmPassword.text.isEmpty) {
        _confirmPasswordError = 'Veuillez confirmer votre mot de passe';
      } else if (Password.text != ConfirmPassword.text) {
        _confirmPasswordError = 'Les mots de passe ne correspondent pas';
      }

      // Role validation
      if (selectedRole == null) {
        _roleError = 'Veuillez sélectionner un rôle';
      }

      // Admin password validation
      if (showAdminPasswordField) {
        if (AdminPassword.text.isEmpty) {
          _adminPasswordError = 'Veuillez entrer le mot de passe admin';
        } else if (!_isAdminPasswordValid) {
          _adminPasswordError = 'Mot de passe admin incorrect';
        }
      }
    });
  }

  Future<void> _submitForm() async {
    _validateForm();

    if (_usernameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null &&
        _roleError == null &&
        (!showAdminPasswordField || _isAdminPasswordValid)) {
      setState(() => _isLoading = true);
      try {
        // 1. Create the user
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: Email.text,
              password: Password.text,
            );

        // 2. Send email verification
        await credential.user!.sendEmailVerification();

        // 3. Save to Firestore
        // New users start with 0 leave balance (they need 1 year of service to get 30 days)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
              'name': Username.text,
              'email': Email.text,
              'role': selectedRole!.toLowerCase(), // 'admin' or 'utilisateur'
              'solde': 30, // Start with 30 days
              'createdAt': FieldValue.serverTimestamp(),
              'profileImageUrl': '',
            });

        // 4. Navigate to Login page
        Navigator.of(context).pushReplacementNamed("Login");
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);
        String errorMessage;
        if (e.code == 'weak-password') {
          errorMessage = 'Le mot de passe fourni est trop faible.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'Le compte existe déjà pour cet e-mail';
        } else {
          errorMessage = 'Une erreur est survenue. Veuillez réessayer.';
        }

        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.rightSlide,
          title: 'Erreur',
          desc: errorMessage,
          btnOkOnPress: () {},
        ).show();
      } catch (e) {
        setState(() => _isLoading = false);
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.rightSlide,
          title: 'Erreur',
          desc: 'Une erreur inattendue s\'est produite',
          btnOkOnPress: () {},
        ).show();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: Duration(milliseconds: 800),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TweenAnimationBuilder(
              tween: Tween<Offset>(begin: Offset(0, 0.2), end: Offset.zero),
              duration: Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (context, Offset offset, child) {
                return Transform.translate(offset: offset, child: child);
              },
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 520),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Hero(tag: "logo", child: const CustomeLogoAuth()),
                      SizedBox(height: 20),
                      Text(
                        "Créer un compte",
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Inscrivez-vous pour continuer",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 30),

                      // Role selection dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: selectedRole,
                            decoration: InputDecoration(
                              labelText: "Rôle",
                              prefixIcon: Icon(Icons.person),
                            ),
                            items:
                                ['Utilisateur', 'Admin'].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedRole = newValue;
                                showAdminPasswordField = newValue == 'Admin';
                                _roleError = null;
                              });
                            },
                            hint: Text("Sélectionnez votre rôle"),
                          ),
                          if (_roleError != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                                left: 12,
                              ),
                            child: Text(_roleError!, style: TextStyle(color: Colors.red, fontSize: 12)),
                            ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Admin password field (only visible when Admin is selected)
                      if (showAdminPasswordField) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: AdminPassword,
                              obscureText: obscureAdminPassword,
                              onChanged: (value) {
                                _validateAdminPassword();
                              },
                              decoration: InputDecoration(
                                labelText: "Mot de passe Admin",
                                prefixIcon: Icon(Icons.security),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isAdminPasswordValid)
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        obscureAdminPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          obscureAdminPassword =
                                              !obscureAdminPassword;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                errorText: _adminPasswordError,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                      ],

                      // Username field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: Username,
                            decoration: InputDecoration(
                              labelText: "Nom d'utilisateur",
                              prefixIcon: Icon(Icons.person),
                              errorText: _usernameError,
                            ),
                            onChanged:
                                (_) => setState(() => _usernameError = null),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Email field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: Email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: "E-mail",
                              prefixIcon: Icon(Icons.email),
                              errorText: _emailError,
                            ),
                            onChanged:
                                (_) => setState(() => _emailError = null),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Password field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: Password,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              labelText: "Mot de passe",
                              prefixIcon: Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                              ),
                              errorText: _passwordError,
                            ),
                            onChanged:
                                (_) => setState(() => _passwordError = null),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Confirm password field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: ConfirmPassword,
                            obscureText: obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: "Confirmez le mot de passe",
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscureConfirmPassword =
                                        !obscureConfirmPassword;
                                  });
                                },
                              ),
                              errorText: _confirmPasswordError,
                            ),
                            onChanged:
                                (_) => setState(
                                  () => _confirmPasswordError = null,
                                ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),

                      
                      SizedBox(height: 30),

                      // Sign up button
                      _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : CustomeButtonAuth(
                            title: "S'inscrire",
                            onPressed: _submitForm,
                          ),
                      SizedBox(height: 20),

                      // OR divider
                      Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text("OU"),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Login link
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed("Login");
                          },
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: "Vous avez déjà un compte ? "),
                                TextSpan(
                                  text: "Se connecter",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                ),
                              ],
                            ),
                          ),
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
        ),
      ),
    );
  }
}
