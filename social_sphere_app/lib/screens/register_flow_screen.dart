// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class RegisterFlowScreen extends StatefulWidget {
  const RegisterFlowScreen({super.key});

  @override
  RegisterFlowScreenState createState() => RegisterFlowScreenState();
}

class RegisterFlowScreenState extends State<RegisterFlowScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Controllers
  final username = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final fullName = TextEditingController();
  final bio = TextEditingController();
  final birthdate = TextEditingController();
  final address = TextEditingController();
  final mobile = TextEditingController();
  final hobbies = TextEditingController();
  final facebook = TextEditingController();

  String gender = "Male"; // default

  final List<String> _stepTitles = [
    "Account Info",
    "Personal Info",
    "Contact Info",
    "Social & Interests",
    "Review",
  ];

  void _nextPage() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context); // Go back to login if on step 1
    }
  }

  Future<void> _submitRegistration() async {
    setState(() => _isLoading = true);

    bool success = await ApiService.registerFull(
      username: username.text,
      email: email.text,
      password: password.text,
      fullName: fullName.text,
      birthdate: birthdate.text,
      gender: gender,
      mobile: mobile.text,
      address: address.text,
      facebook: facebook.text,
      hobbies: hobbies.text,
      bio: bio.text,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration failed"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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
                constraints: const BoxConstraints(maxWidth: 450),

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
                      // HEADER: Back Button & Step Counter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: _previousPage,
                            child: const Icon(
                              Icons.arrow_back_ios,
                              size: 20,
                              color: Color(0xFF00CFFF),
                            ),
                          ),
                          Text(
                            "Step ${_currentStep + 1} of 5",
                            style: const TextStyle(
                              color: Color(0xFFB8A4E8),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 20),
                        ],
                      ),

                      const SizedBox(height: 25),

                      // DYNAMIC TITLE with neon gradient
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF00CFFF),
                            Color(0xFFBF5FFF),
                            Color(0xFFFF4ECD),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          _stepTitles[_currentStep],
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      Text(
                        _currentStep == 4
                            ? "Please review your details before submitting."
                            : "Fill in the details below to continue.",
                        style: const TextStyle(
                          color: Color(0xFF9980CC),
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 🔄 ANIMATED SWITCHER FOR SMOOTH FORM TRANSITIONS
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey<int>(_currentStep),
                          child: _buildCurrentStepWidget(),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 🔘 NAVIGATION BUTTONS
                      Row(
                        children: [
                          // Back Button
                          if (_currentStep > 0) ...[
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                height: 55,
                                child: OutlinedButton(
                                  onPressed: _previousPage,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF00CFFF),
                                    side: const BorderSide(
                                      color: Color(0xFF8B3CFF),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text("Back"),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                          ],

                          // Next / Register Button with neon gradient
                          Expanded(
                            flex: 2,
                            child: Container(
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
                                onPressed: _isLoading
                                    ? null
                                    : (_currentStep == 4
                                          ? _submitRegistration
                                          : _nextPage),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _currentStep == 4 ? "Register" : "Next",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
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

  // 📄 STEP WIDGET ROUTER
  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case 0:
        return Column(
          children: [
            _buildInputField(
              label: "Username",
              hint: "cooluser",
              controller: username,
            ),
            const SizedBox(height: 15),
            _buildInputField(
              label: "Email",
              hint: "you@example.com",
              controller: email,
            ),
            const SizedBox(height: 15),
            _buildInputField(
              label: "Password",
              hint: "Strong password",
              controller: password,
              isPassword: true,
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            _buildInputField(
              label: "Full Name",
              hint: "John Doe",
              controller: fullName,
            ),
            const SizedBox(height: 15),
            _buildInputField(
              label: "Birthdate",
              hint: "YYYY-MM-DD",
              controller: birthdate,
            ),
            const SizedBox(height: 15),
            _buildGenderDropdown(),
          ],
        );
      case 2:
        return Column(
          children: [
            _buildInputField(
              label: "Mobile Number",
              hint: "+1 234 567 890",
              controller: mobile,
            ),
            const SizedBox(height: 15),
            _buildInputField(
              label: "Address",
              hint: "123 Main St",
              controller: address,
            ),
          ],
        );
      case 3:
        return Column(
          children: [
            _buildInputField(
              label: "Facebook Link",
              hint: "facebook.com/username",
              controller: facebook,
            ),
            const SizedBox(height: 15),
            _buildInputField(
              label: "Hobbies",
              hint: "Reading, Gaming, etc.",
              controller: hobbies,
            ),
            const SizedBox(height: 15),
            _buildInputField(
              label: "Bio",
              hint: "Tell us about yourself...",
              controller: bio,
              maxLines: 3,
            ),
          ],
        );
      case 4:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1840),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFF4A3080)),
          ),
          child: Column(
            children: [
              _buildReviewRow("Username", username.text),
              _buildReviewRow("Email", email.text),
              _buildReviewRow("Full Name", fullName.text),
              _buildReviewRow("Birthdate", birthdate.text),
              _buildReviewRow("Gender", gender),
              _buildReviewRow("Mobile", mobile.text),
              _buildReviewRow("Address", address.text),
              _buildReviewRow("Hobbies", hobbies.text),
            ],
          ),
        );
      default:
        return const SizedBox();
    }
  }

  // REUSABLE UI WIDGETS (neon dark style)
  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    int maxLines = 1,
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
            maxLines: isPassword ? 1 : maxLines,
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

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Gender",
          style: TextStyle(
            color: Color(0xFFB8A4E8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1840),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF4A3080), width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: gender,
              dropdownColor: const Color(0xFF1E1840),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00CFFF)),
              onChanged: (value) => setState(() => gender = value!),
              items: ["Male", "Female", "Other"]
                  .map(
                    (g) => DropdownMenuItem(
                      value: g,
                      child: Text(
                        g,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9980CC),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? "Not provided" : value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
