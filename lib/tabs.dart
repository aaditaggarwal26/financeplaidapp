// All the imports for our app
import 'package:flutter/material.dart';
import 'package:finsight/screens/settings_screen.dart';
import 'package:finsight/screens/spending_screen.dart';
import 'package:finsight/screens/transitions_screen.dart';
import 'package:finsight/screens/dashboard_screen.dart';
import 'package:finsight/screens/ai_chat_screen.dart';
import 'package:finsight/screens/forum_screen.dart';

/// A widget that manages the bottom tab (nav bar) navigation for the app
class Tabs extends StatefulWidget {
  const Tabs({super.key});

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  // Holds the index of the currently selected tab
  int _currentIndex = 0;

  // List of screens to display based on tab selection
  final List<Widget> _screens = [
    const DashboardScreen(),
    const SpendingScreen(),
    const TransactionScreen(),
    const CommunityForumScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // Displays the selected screen
      body: _screens[_currentIndex],

      // Floating chat button to access AI assistant screen
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AIChatScreen()),
          );
        },
        backgroundColor: const Color(0xFFE5BA73),
        child: const Icon(Icons.chat, color: Color(0xFF2B3A55)),
      ),

      // Bottom navigation bar to switch between different tabs
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2B3A55),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_rounded),
            label: 'Spending',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            label: 'Forum',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
