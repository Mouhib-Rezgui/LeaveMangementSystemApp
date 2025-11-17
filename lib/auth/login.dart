import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:firebase/components/customebuttauth.dart';
import 'package:firebase/components/customelogoauth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();

  Future signInWithGoogle() async {
    final GoogleSignInAccount googleUser =
        await GoogleSignIn.instance.authenticate();

    final GoogleSignInAuthentication? googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );

    // Once signed in, return the UserCredential
    await FirebaseAuth.instance.signInWithCredential(credential);
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil("ProfilePage", (route) => false);
  }

  bool show = false;
  bool obscurePassword = true;
  bool _isLoading = false;

  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 500), () {
      setState(() => show = true);
    });
  }

  void _validateFields() {
    setState(() {
      _emailError = null;
      _passwordError = null;

      if (email.text.isEmpty) {
        _emailError = 'Veuillez entrer votre email';
      } else if (!RegExp(
        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
      ).hasMatch(email.text)) {
        _emailError = 'Veuillez entrer un email valide';
      }

      if (password.text.isEmpty) {
        _passwordError = 'Veuillez entrer votre mot de passe';
      } else if (password.text.length < 6) {
        _passwordError = 'Le mot de passe doit contenir au moins 6 caractères';
      }
    });
  }

  Future<void> _login() async {
    _validateFields();

    if (_emailError == null && _passwordError == null) {
      setState(() => _isLoading = true);
      try {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: email.text,
              password: password.text,
            );

        if (credential.user!.emailVerified) {
          Navigator.of(context).pushReplacementNamed("ProfileRedirector");
        } else {
          // First show the dialog
          await AwesomeDialog(
            context: context,
            dialogType: DialogType.info,
            animType: AnimType.rightSlide,
            title: 'Vérification requise',
            desc:
                'Votre email n\'est pas vérifié. Veuillez vérifier votre boîte mail pour le lien de vérification.',
            btnOkOnPress: () {},
          ).show();

          // Then send verification email
          await credential.user!.sendEmailVerification();

          // Sign out the user since email isn't verified
          await FirebaseAuth.instance.signOut();
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        if (e.code == 'user-not-found') {
          errorMessage = 'Aucun utilisateur trouvé pour cet email.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Mot de passe incorrect.';
        } else if (e.code == 'user-disabled') {
          errorMessage = 'Ce compte a été désactivé.';
        } else {
          errorMessage = 'Mot de passe incorrect.';
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
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.rightSlide,
          title: 'Erreur',
          desc: 'Une erreur inattendue s\'est produite',
          btnOkOnPress: () {},
        ).show();
      } finally {
        setState(() => _isLoading = false);
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
                  constraints: BoxConstraints(maxWidth: 480),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Hero(
                            tag: "logo",
                            child: const CustomeLogoAuth(),
                          ),
                      SizedBox(height: 20),
                      Text(
                        "Content de te revoir",
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Connectez-vous pour continuer",
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 30),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: email,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: password,
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
                      SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            if (email.text == "") {
                              AwesomeDialog(
                                context: context,
                                dialogType: DialogType.error,
                                animType: AnimType.rightSlide,
                                title: 'Erreur',
                                desc:
                                    "Veuillez saisir votre adresse email et cliquer sur Mot de passe oublié pour recevoir un lien de réinitialisation",
                                btnOkOnPress: () {},
                              ).show();
                              return;
                            }
                            try {
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(email: email.text);
                              AwesomeDialog(
                                context: context,
                                dialogType: DialogType.success,
                                animType: AnimType.rightSlide,
                                title: 'Succès',
                                desc:
                                    "Consultez votre boîte mail (et vos spams) pour réinitialiser votre mot de passe.",
                                btnOkOnPress: () {},
                              ).show();
                            } catch (e) {
                              AwesomeDialog(
                                context: context,
                                dialogType: DialogType.error,
                                animType: AnimType.rightSlide,
                                title: 'Erreur',
                                desc:
                                    "Vérifiez que l'adresse email saisie est correcte et réessayez.",
                                btnOkOnPress: () {},
                              ).show();
                            }
                          },
                          child: Text("Mot de passe oublié?"),
                        ),
                      ),
                      SizedBox(height: 30),
                      _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : CustomeButtonAuth(
                            title: "Se connecter",
                            onPressed: _login,
                          ),
                      SizedBox(height: 20),
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
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 15),
                        ),
                        icon: Image.network(
                          "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3c/Google_Favicon_2025.svg/250px-Google_Favicon_2025.svg.png",
                          width: 24,
                        ),
                        label: Text(
                          "Connectez-vous avec Google",
                          style: TextStyle(color: Colors.black),
                        ),
                        onPressed: () {
                          signInWithGoogle();
                        },
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed("Signup");
                          },
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: "Vous n'avez pas de compte ? "),
                                TextSpan(
                                  text: "S'inscrire",
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

extension on GoogleSignInAuthentication? {
  get accessToken => null;
}
