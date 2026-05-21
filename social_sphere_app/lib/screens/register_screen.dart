// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  RegisterScreenState createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String message = "";
  bool isLoading = false;

  Future<void> register() async {
    setState(() {
      isLoading = true;
      message = "";
    });

    bool success = await ApiService.register(
      usernameController.text,
      emailController.text,
      passwordController.text,
    );

    setState(() => isLoading = false);

    if (success) {
      if (mounted) {
        Navigator.pop(context); // go back to login
      }
    } else {
      setState(() => message = "Registration failed");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [
              Color(0xFF1A0A3A),
              Color(0xFF0A0A1A),
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),

                // THE NEON DARK CARD
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
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // TITLE
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF00CFFF),
                            Color(0xFFBF5FFF),
                            Color(0xFFFF4ECD),
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 8),
                      const Text(
                        "Join Social Sphere today!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9980CC),
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 🧊 INPUTS
                      _buildInputField(
                        label: "Username",
                        hint: "cooluser",
                        controller: usernameController,
                      ),
                      const SizedBox(height: 15),
                      _buildInputField(
                        label: "Email Address",
                        hint: "you@example.com",
                        controller: emailController,
                      ),
                      const SizedBox(height: 15),
                      _buildInputField(
                        label: "Password",
                        hint: "Strong password",
                        controller: passwordController,
                        isPassword: true,
                      ),

                      const SizedBox(height: 35),

                      // SUBMIT BUTTON with neon gradient
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
                          onPressed: isLoading ? null : register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
                                  "Register",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      // ❌ ERROR MESSAGE
                      if (message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      const SizedBox(height: 30),

                      // BACK TO LOGIN LINK
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Color(0xFF9980CC),
                              fontSize: 14,
                            ),
                            children: [
                              const TextSpan(text: "Already have an account? "),
                              TextSpan(
                                text: "Log in",
                                style: const TextStyle(
                                  color: Color(0xFFFF52A2),
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.pop(context),
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

  // REUSABLE INPUT WIDGET (neon dark style)
  Widget _buildInputField({
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
