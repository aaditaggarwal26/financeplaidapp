import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B3A55),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About Finsight',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: const Text(
                    'FinSight is a modern finance management app designed to make tracking your expenses, managing your income, and achieving financial goals easier than ever. With a user-friendly interface, FinSight is accessible to users of all backgrounds, providing powerful tools to effortlessly understand your financial landscape.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Features',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: const Text(
                    '- Link bank accounts securely and track transactions in real-time using Plaid integration.
- Set personalized financial goals and monitor progress effortlessly.
- Get detailed reports on your spending patterns and receive insights to help you save more effectively.
- Access intuitive visualizations, such as charts and graphs, for a better understanding of your finances.
- Benefit from Firebase-backed secure login and data storage, ensuring your information is always safe.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Benefits',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: const Text(
                    '- Easy to use for individuals of all ages, making finance management accessible to everyone.
- Secure integration with Firebase for reliable data storage and authentication.
- Comprehensive budgeting tools to help you manage spending and save towards your goals.
- Gain financial clarity and reduce the stress of managing money by seeing all your accounts in one place.
- Real-time updates on your financial status, giving you up-to-date insights at your fingertips.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Meet the Developers',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: const Text(
                    'FinSight was created by Aadit Aggarwal and Ritvik Bansal, two passionate developers dedicated to making financial literacy and management accessible to everyone.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      primary: const Color(0xFFE5BA73),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () {
                      // Placeholderr
                    },
                    child: const Text(
                      'Learn More',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
