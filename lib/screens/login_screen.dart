// This screen handles user authentication, including login, signup, Google sign-in, and password reset.
import 'dart:async';
import 'package:finsight/tabs.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Main widget for the login screen, using a stateful widget for dynamic UI updates.
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

// State class managing authentication logic and UI state.
class _LoginScreenState extends State<LoginScreen> {
  // Toggle between login and signup modes.
  bool isLogin = true;
  // Control password visibility for input fields.
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  // Flag to show loading state during authentication.
  bool isLoading = false;

  // Controllers for email, password, and confirm password input fields.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Firebase Auth instance for authentication operations.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stores any error messages from authentication attempts.
  String? errorMessage;

  // Subscription to listen for auth state changes.
  late StreamSubscription<User?> _authStateSubscription;

  // Google Sign-In instance configured for email scope.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    signInOption: SignInOption.standard,
  );

  // Handle Google Sign-In authentication.
  Future<void> _signInWithGoogle() async {
    print('entered method');
    // Show loading state and clear any previous errors.
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    print('finished set state');

    try {
      // Initiate Google Sign-In and handle potential errors.
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn().catchError((error) {
        print('Google Sign In Error: $error');
        throw error;
      });

      print('sign in attempt completed');

      // Check if the user cancelled the sign-in process.
      if (googleUser == null) {
        print('User cancelled the sign-in process');
        setState(() {
          isLoading = false;
          errorMessage = 'Sign in cancelled';
        });
        return;
      }

      // Get Google authentication credentials.
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('got the tocken');

      // Sign in to Firebase with the Google credential.
      await _auth.signInWithCredential(credential);

      // Ensure the widget is still mounted before navigating.
      if (!mounted) return;

      print('about to push');

      // Navigate to the main app tabs and show a success message.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const Tabs(),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully logged in with Google!')),
      );
    } catch (e) {
      print('Error during Google Sign In: $e');
      // Display an error message if Google Sign-In fails.
      setState(() {
        errorMessage = 'Failed to sign in with Google';
      });
    } finally {
      // Always clear the loading state.
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Listen for auth state changes to automatically navigate if the user is already signed in.
    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (!mounted) return;

      if (user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Tabs()),
        );
      }
    });
  }

  @override
  void dispose() {
    // Clean up the auth state subscription to prevent memory leaks.
    _authStateSubscription.cancel();
    super.dispose();
  }

  // Handle email and password login.
  Future<void> _signIn() async {
    // Show loading state and clear previous errors.
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Attempt to sign in with Firebase Auth.
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Navigate to the main app tabs and show a success message.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const Tabs(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully logged in!')),
      );
    } on FirebaseAuthException catch (e) {
      // Display Firebase-specific error messages.
      setState(() {
        errorMessage = e.message;
      });
    } catch (e) {
      // Handle unexpected errors.
      setState(() {
        errorMessage = 'An error occurred';
      });
    } finally {
      // Always clear the loading state.
      setState(() {
        isLoading = false;
      });
    }
  }

  // Handle email and password signup.
  Future<void> _signUp() async {
    // Check if passwords match before proceeding.
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        errorMessage = 'Passwords do not match';
      });
      return;
    }

    // Show loading state and clear previous errors.
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Create a new user with Firebase Auth.
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Navigate to the main app tabs and show a success message.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const Tabs(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully signed up!')),
      );
    } on FirebaseAuthException catch (e) {
      // Display Firebase-specific error messages.
      setState(() {
        errorMessage = e.message;
      });
    } catch (e) {
      // Handle unexpected errors.
      setState(() {
        errorMessage = 'An error occurred';
      });
    } finally {
      // Always clear the loading state.
      setState(() {
        isLoading = false;
      });
    }
  }

  // Send a password reset email to the user.
  Future<void> _resetPassword() async {
    // Ensure an email is provided before sending the reset email.
    if (_emailController.text.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your email';
      });
      return;
    }

    try {
      // Send password reset email via Firebase Auth.
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    } on FirebaseAuthException catch (e) {
      // Display Firebase-specific error messages.
      setState(() {
        errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Main scaffold with a split-color background and authentication form.
    return Scaffold(
      backgroundColor: const Color(0xFF2B3A55),
      body: Stack(
        children: [
          // Top section with a darker background for visual separation.
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 23, 31, 45),
            ),
          ),
          Column(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Get Started now',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create an account or log in to explore about our app',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              // Bottom section with the authentication form.
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Toggle between login and signup modes.
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => isLogin = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isLogin
                                            ? Colors.white
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: isLogin
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFD4AF37)
                                                      .withOpacity(0.2),
                                                  spreadRadius: 1,
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Log In',
                                          style: TextStyle(
                                            color: isLogin
                                                ? Colors.black
                                                : Colors.grey[600],
                                            fontWeight: isLogin
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => isLogin = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: !isLogin
                                            ? Colors.white
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: !isLogin
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFFFD700)
                                                      .withOpacity(0.2),
                                                  spreadRadius: 1,
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Sign Up',
                                          style: TextStyle(
                                            color: !isLogin
                                                ? Colors.black
                                                : Colors.grey[600],
                                            fontWeight: !isLogin
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Email input field.
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'Email',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFD4AF37)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD4AF37),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Password input field with visibility toggle.
                          TextField(
                            controller: _passwordController,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFD4AF37)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD4AF37),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFFD4AF37),
                                ),
                                onPressed: () => setState(
                                    () => obscurePassword = !obscurePassword),
                              ),
                            ),
                          ),
                          // Confirm password field, shown only in signup mode.
                          if (!isLogin) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: obscureConfirmPassword,
                              decoration: InputDecoration(
                                hintText: 'Confirm Password',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFD4AF37)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD4AF37),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: const Color(0xFFD4AF37),
                                  ),
                                  onPressed: () => setState(() =>
                                      obscureConfirmPassword =
                                          !obscureConfirmPassword),
                                ),
                              ),
                            ),
                          ],
                          // Forgot password link, shown only in login mode.
                          if (isLogin) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _resetPassword,
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(color: Color(0xFFD4AF37)),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          // Main action button for login or signup.
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2B3A55),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFD4AF37),
                                  width: 1,
                                ),
                              ),
                              onPressed: isLoading
                                  ? null
                                  : (isLogin ? _signIn : _signUp),
                              child: isLoading
                                  ? const CircularProgressIndicator(
                                      color: Color(0xFFD4AF37))
                                  : Text(
                                      isLogin ? 'Log In' : 'Sign Up',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Divider for alternative sign-in options.
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.grey[400],
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.grey[400],
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Google Sign-In button.
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                                backgroundColor: Colors.white,
                              ),
                              onPressed: isLoading ? null : _signInWithGoogle,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/google_logo.png',
                                    height: 24,
                                    width: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Sign in with Google',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Display error messages if any.
                          if (errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}