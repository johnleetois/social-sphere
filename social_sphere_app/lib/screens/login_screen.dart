import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../services/api_service.dart';
import 'register_flow_screen.dart';
import 'my_group_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String message = "";

  Future<void> login() async {
    setState(() {
      isLoading = true;
      message = "";
    });

    try {
      final result = await ApiService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (result != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", result["access_token"]);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => MyGroupsScreen()),
          );
        }
      } else {
        setState(() => message = "Invalid credentials");
      }
    } catch (e) {
      setState(() => message = "Connection error");
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      // 1. THE BACKGROUND
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [
              Color(0xFF1A0A3A), // Deep purple center
              Color(0xFF0A0A1A), // Very dark navy edge
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 20.0,
              ),

              // 📱 Web/Mobile Constraints
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                ), // Slightly wider to accommodate padding
                // 2. THE FORM CONTAINER (Neon dark card)
                child: Container(
                  padding: const EdgeInsets.all(35.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12102A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF8B3CFF),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(140, 60, 255, 0.4),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Color.fromRGBO(0, 207, 255, 0.15),
                        blurRadius: 50,
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min, // Wrap content height
                    children: [
                      // LOGO & APP NAME
                      Column(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Color.fromRGBO(255, 0, 150, 0.5),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: Color.fromRGBO(0, 200, 255, 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.chat_bubble_rounded,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFF00CFFF),
                                Color(0xFFBF5FFF),
                                Color(0xFFFF4ECD),
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              "SOCIAL SPHERE",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // TITLE
                      const Text(
                        "Log In",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.left,
                      ),

                      const SizedBox(height: 25),

                      // 🧊 EMAIL INPUT
                      buildInputField(
                        label: "Email Address",
                        hint: "Email Address",
                        controller: emailController,
                      ),

                      const SizedBox(height: 20),

                      // 🔒 PASSWORD INPUT
                      buildInputField(
                        label: "Password",
                        hint: "Strong password",
                        controller: passwordController,
                        isPassword: true,
                      ),

                      const SizedBox(height: 12),

                      // FORGOT PASSWORD
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {},
                          child: const Text(
                            "Forgot Password ?",
                            style: TextStyle(
                              color: Color(0xFF00CFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 35),

                      // LOGIN BUTTON with neon gradient
                      Container(
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(140, 60, 255, 0.5),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                          ],
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF00CFFF),
                              Color(0xFF8B3CFF),
                              Color(0xFFFF52A2),
                            ],
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Log in",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ❌ ERROR MESSAGE
                      if (message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      const SizedBox(height: 10),

                      // REGISTER LINK
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Color(0xFF9980CC),
                              fontSize: 14,
                            ),
                            children: [
                              const TextSpan(text: "Don't have an account? "),
                              TextSpan(
                                text: "Sign up",
                                style: const TextStyle(
                                  color: Color(0xFFFF52A2),
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const RegisterFlowScreen(),
                                      ),
                                    );
                                  },
                              ),
                            ],
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
    );
  }

  // INPUT FIELD BUILDER (neon dark style)
  Widget buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB8A4E8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1840),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF4A3080), width: 1.5),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF6650A4), fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
