import 'package:flutter/material.dart';
import 'package:fbla_coding_programming_app/screens/dashboard_screen.dart';
import 'package:fbla_coding_programming_app/screens/spending_screen.dart';

class HelpQAScreen extends StatefulWidget {
  const HelpQAScreen({Key? key}) : super(key: key);

  @override
  _HelpQAScreenState createState() => _HelpQAScreenState();
}

class _HelpQAScreenState extends State<HelpQAScreen> {
  final List<Map<String, dynamic>> _questionsAndAnswers = [
    {
      'question': 'How do I link my bank account?',
      'answer':
          'To link your bank account, go to the "Spending" section and tap on "Add Account". Follow the instructions provided.'
    },
    {
      'question': 'How can I track my expenses?',
      'answer':
          'You can track your expenses by going to the "Spending" tab. Here you will see detailed analytics of your transactions.'
    },
    {
      'question': 'What security measures are in place?',
      'answer':
          'We use state-of-the-art encryption and security practices to ensure that your data remains safe and private.'
    },
    {
      'question': 'How do I update my profile information?',
      'answer':
          'Go to the "Dashboard" and tap on the profile icon. Here you can update your personal information.'
    },
    {
      'question': 'Can I export my spending data?',
      'answer':
          'Yes, you can export your spending data by navigating to the "Spending" tab and tapping on the export icon in the top-right corner.'
    },
  ];

  Map<String, bool> _expandedQuestions = {};

  @override
  void initState() {
    super.initState();
    for (var qna in _questionsAndAnswers) {
      _expandedQuestions[qna['question']] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Help & Q&A',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2B3A55),
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: _questionsAndAnswers.length,
        itemBuilder: (context, index) {
          final qna = _questionsAndAnswers[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              title: Text(
                qna['question'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B3A55),
                ),
              ),
              trailing: Icon(
                _expandedQuestions[qna['question']]!
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: const Color(0xFF2B3A55),
              ),
              onExpansionChanged: (expanded) {
                setState(() {
                  _expandedQuestions[qna['question']] = expanded;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    qna['answer'],
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2B3A55),
        unselectedItemColor: Colors.grey,
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SpendingScreen()),
              );
              break;
            case 2:
              // alr on this screen, do nothing
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Spending',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            label: 'Help',
          ),
        ],
      ),
    );
  }
}
