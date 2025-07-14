// Settings screen for user preferences and account management.
import 'package:finsight/screens/about_screen.dart';
import 'package:finsight/screens/help_qna_screen.dart';
import 'package:finsight/screens/login_screen.dart';
import 'package:finsight/services/plaid_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Stateless widget for the settings screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// State class for handling settings screen logic.
class _SettingsScreenState extends State<SettingsScreen> {
  // Firebase auth instance for user management.
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PlaidService _plaidService = PlaidService();
  
  List<ConnectedAccount> _connectedAccounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConnectedAccounts();
  }

  Future<void> _loadConnectedAccounts() async {
    try {
      final accounts = await _plaidService.getConnectedAccounts();
      if (mounted) {
        setState(() {
          _connectedAccounts = accounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading connected accounts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Signs the user out and redirects to the login screen.
  Future<void> _signOut(BuildContext context) async {
    try {
      // Disconnect all Plaid accounts first
      await _plaidService.disconnectAll();
      
      await _auth.signOut();
      // Navigate to login screen after signing out.
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => LoginScreen(),
      ));
    } catch (e) {
      // Show error if sign-out fails.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  // Shows a dialog for editing the user's display name.
  void _editNameDialog(BuildContext context) {
    final user = _auth.currentUser;
    final TextEditingController _nameController =
        TextEditingController(text: user?.displayName ?? '');

    // Display the dialog for name editing.
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Update Name'),
          content: TextField(
            controller: _nameController,
            decoration: InputDecoration(hintText: 'Enter your name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            // Save the new name to Firebase.
            ElevatedButton(
              onPressed: () async {
                final newName = _nameController.text.trim();
                if (newName.isNotEmpty) {
                  await user?.updateDisplayName(newName);
                  await user?.reload();
                  setState(() {});
                  Navigator.pop(context);
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDisconnectAccountDialog(ConnectedAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect ${account.institutionName}'),
        content: Text('Are you sure you want to disconnect this account? This will remove all associated data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _disconnectAccount(account);
    }
  }

  Future<void> _disconnectAccount(ConnectedAccount account) async {
    try {
      setState(() => _isLoading = true);
      
      final success = await _plaidService.disconnectAccount(account.itemId);
      
      if (success) {
        await _loadConnectedAccounts();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${account.institutionName} disconnected successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to disconnect ${account.institutionName}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // Builds the UI for the settings screen.
  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      // Dark background consistent with the app's theme.
      backgroundColor: const Color(0xFF2B3A55),
      body: SafeArea(
        child: Column(
          children: [
            // Header for the settings screen.
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // User info card if the user is logged in.
            if (user != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE5C87E).withOpacity(0.9),
                        Color(0xFFD4AF37).withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Color(0xFF2B3A55),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi ${user.displayName ?? 'User'}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B3A55),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                user.email ?? 'No email',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2B3A55).withOpacity(0.7),
                                ),
                              ),
                              // Connection status with better styling
                              if (_connectedAccounts.isNotEmpty) ...[
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF2B3A55).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Color(0xFF2B3A55),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        '${_connectedAccounts.length} account${_connectedAccounts.length == 1 ? '' : 's'} linked',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2B3A55),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Button to trigger name editing dialog.
                        GestureDetector(
                          onTap: () => _editNameDialog(context),
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.edit,
                                color: Color(0xFF2B3A55),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            // Main settings list with sections.
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.only(top: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: ListView(
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    // Connected Accounts section
                    if (_connectedAccounts.isNotEmpty)
                      _buildSettingsSection(
                        'CONNECTED ACCOUNTS',
                        _connectedAccounts.map((account) => 
                          _buildConnectedAccountTile(account)
                        ).toList(),
                      ),
                    
                    // Preferences section for app settings.
                    _buildSettingsSection(
                      'PREFERENCES',
                      [
                        _buildSettingsTile(
                          icon: Icons.dark_mode_outlined,
                          title: 'Dark Mode',
                          subtitle: 'Off',
                          isSwitch: true,
                          onTap: () {},
                        ),
                        _buildSettingsTile(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          subtitle: 'Manage alerts',
                          onTap: () {},
                        ),
                        _buildSettingsTile(
                          icon: Icons.language_outlined,
                          title: 'Language',
                          subtitle: 'English (US)',
                          onTap: () {},
                        ),
                      ],
                    ),
                    // Support section for help and info.
                    _buildSettingsSection(
                      'SUPPORT',
                      [
                        _buildSettingsTile(
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          subtitle: 'FAQs and contact info',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HelpQAScreen(),
                              ),
                            );
                          },
                        ),
                        _buildSettingsTile(
                          icon: Icons.info_outline,
                          title: 'About',
                          subtitle: 'App info and legal',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AboutScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    // Account section for user-related actions.
                    _buildSettingsSection(
                      'ACCOUNT',
                      [
                        _buildSettingsTile(
                          icon: Icons.security_outlined,
                          title: 'Privacy & Security',
                          subtitle: 'Password, data settings',
                          onTap: () {},
                        ),
                        _buildSettingsTile(
                          icon: Icons.logout_outlined,
                          title: 'Logout',
                          subtitle: 'Sign out of your account',
                          textColor: Colors.red[700],
                          iconColor: Colors.red[700],
                          onTap: () {
                            // Show logout confirmation dialog.
                            showDialog(
                              context: context,
                              builder: (context) => _buildLogoutDialog(context),
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    // App version info at the bottom.
                    Center(
                      child: Text(
                        'FinSight v1.0.2',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedAccountTile(ConnectedAccount account) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: ListTile(
          leading: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Color(0xFF2B3A55).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.account_balance,
                color: Color(0xFF2B3A55),
              ),
            ),
          ),
          title: Text(
            account.institutionName,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            'Connected ${_formatRelativeTime(account.connectedAt)}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showDisconnectAccountDialog(account),
                child: Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the logout confirmation dialog.
  Widget _buildLogoutDialog(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout,
                color: Colors.red[700],
                size: 28,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Are you sure you want to logout from your account? This will disconnect all linked bank accounts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                // Cancel button to dismiss the dialog.
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Confirm logout button.
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _signOut(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.red[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Builds a settings section with a title and list of tiles.
  Widget _buildSettingsSection(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2B3A55),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: tiles,
          ),
        ),
      ],
    );
  }

  // Builds an individual settings tile with icon, title, and optional switch.
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
    bool isSwitch = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: ListTile(
            leading: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: (iconColor ?? Color(0xFF2B3A55)).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: iconColor ?? Color(0xFF2B3A55),
                ),
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: textColor ?? Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: subtitle != null
                ? Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  )
                : null,
            trailing: isSwitch
                ? Switch(
                    value: false,
                    onChanged: (_) {},
                    activeColor: Color(0xFFE5BA73),
                    activeTrackColor: Color(0xFFE5BA73).withOpacity(0.3),
                  )
                : Container(
                    height: 30,
                    width: 30,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}