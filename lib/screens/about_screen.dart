// This screen provides an overview of the FinSight app, its features, and developers.
import 'package:flutter/material.dart';

// Main widget for the About screen, using a stateless widget since no state changes are needed.
class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Main scaffold with a scrollable column for app details.
    return Scaffold(
      backgroundColor: const Color(0xFF2B3A55),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 80),
            // App logo displayed in a centered, rounded container.
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    'assets/images/logo_cropped.png',
                    height: 100,
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // App title and description section.
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About FinSight',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Your all-in-one finance management solution for effortless expense tracking and smart financial planning.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Main content section with feature lists and developer info.
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Key Features section.
                    _buildSection(
                      'Key Features',
                      [
                        'Real-time bank sync with Plaid',
                        'Personalized financial goals',
                        'Detailed spending analytics',
                        'Smart budgeting tools',
                        'Secure Firebase authentication',
                      ],
                      Icons.star_outline,
                    ),
                    const SizedBox(height: 24),
                    // Why FinSight section.
                    _buildSection(
                      'Why FinSight?',
                      [
                        'Simple, intuitive interface',
                        'Comprehensive financial overview',
                        'Real-time transaction updates',
                        'Data-driven insights',
                        'Bank-level security',
                      ],
                      Icons.lightbulb_outline,
                    ),
                    const SizedBox(height: 24),
                    // Developers section.
                    _buildSection(
                      'Developers',
                      [
                        'Created by Ritvik Bansal and Aadit Aggarwal',
                        'Committed to making financial management accessible to everyone',
                      ],
                      Icons.people_outline,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build a section with a title, icon, and bulleted list of items.
  Widget _buildSection(String title, List<String> items, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title with an icon.
        Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF2B3A55),
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF2B3A55),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // List of items in a styled container.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2B3A55).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '•',
                            style: TextStyle(
                              color: Color(0xFF2B3A55),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: Color(0xFF2B3A55),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}