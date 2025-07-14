import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finsight/models/account_balance.dart';
import 'package:finsight/models/checking_account.dart';
import 'package:finsight/models/credit_card.dart';
import 'package:finsight/models/transaction.dart';
import 'package:finsight/services/data_service.dart';
import 'package:finsight/services/plaid_service.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:finsight/screens/spending_screen.dart';
import 'package:finsight/widgets/smart_features_dashboard_widget.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  final DataService _dataService = DataService();
  final PlaidService _plaidService = PlaidService();
  final User? _user = FirebaseAuth.instance.currentUser;
  
  late Future<List<AccountBalance>> _balancesFuture;
  late Future<List<Transaction>> _transactionsFuture;
  late Future<List<Map<String, dynamic>>> _plaidAccountsFuture;
  
  int _currentPage = 0;
  static bool _hasLoadedData = false;
  bool _showBalances = true;
  bool _isLoading = false;
  bool _usePlaidData = false;
  List<Map<String, dynamic>> _plaidAccounts = [];
  List<ConnectedAccount> _connectedAccounts = [];

  // Stream subscriptions for Plaid events
  late final StreamSubscription<LinkSuccess>? _successSubscription;
  late final StreamSubscription<LinkExit>? _exitSubscription;

  final Map<String, bool> _expandedSections = {
    'Checking': false,
    'Card Balance': false,
    'Net Cash': false,
    'Investments': false,
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _checkPlaidConnection();
    _initPlaidListeners();
  }

  void _initPlaidListeners() {
    _successSubscription = PlaidLink.onSuccess.listen((LinkSuccess success) async {
      print('=== Plaid success: ${success.publicToken} ===');
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        final result = await _plaidService.exchangePublicToken(success.publicToken);
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _usePlaidData = result;
          });
          
          if (result) {
            // Clear cache and reload data
            DataService.clearCache();
            await _loadPlaidData();
            await _loadConnectedAccounts();
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account connected successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to connect account'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('Error in success handler: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });

    _exitSubscription = PlaidLink.onExit.listen((LinkExit exit) {
      print('=== Plaid exit: ${exit.error?.displayMessage} ===');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (exit.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection cancelled: ${exit.error?.displayMessage ?? 'Unknown error'}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  Future<void> _checkPlaidConnection() async {
    try {
      final hasConnection = await _plaidService.hasPlaidConnection();
      if (hasConnection && mounted) {
        setState(() {
          _usePlaidData = true;
        });
        await _loadPlaidData();
        await _loadConnectedAccounts();
      }
    } catch (e) {
      print('Error checking Plaid connection: $e');
      // Continue with static data
    }
  }

  Future<void> _loadConnectedAccounts() async {
    try {
      final accounts = await _plaidService.getConnectedAccounts();
      if (mounted) {
        setState(() {
          _connectedAccounts = accounts;
        });
      }
    } catch (e) {
      print('Error loading connected accounts: $e');
    }
  }

  void _initializeData() {
    if (!_hasLoadedData) {
      setState(() {
        _balancesFuture = Future.value([]);
        _transactionsFuture = Future.value([]);
        _plaidAccountsFuture = Future.value([]);
      });
    } else {
      _loadData();
    }
  }

  void _loadData() {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _usePlaidData = false;
    });

    setState(() {
      _balancesFuture = _dataService.getAccountBalances();
      _transactionsFuture = _dataService.getTransactions();
      _hasLoadedData = true;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadPlaidData() async {
    print('=== Dashboard: _loadPlaidData called ===');
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Get Plaid accounts using context
      final accounts = await _plaidService.getAccounts(context);
      
      // Get Plaid transactions using context
      final transactions = await _dataService.getTransactions(
        context: context,
        forceRefresh: true,
      );
      
      // Get account balances
      final balances = await _dataService.getAccountBalances(
        context: context,
        forceRefresh: true,
      );
      
      if (!mounted) return;
      
      setState(() {
        _plaidAccounts = accounts;
        _transactionsFuture = Future.value(transactions);
        _balancesFuture = Future.value(balances);
        _usePlaidData = true;
        _hasLoadedData = true;
      });
      
      print('Dashboard: Successfully loaded Plaid data');
    } catch (e) {
      print('Dashboard: Error loading Plaid data: $e');
      if (mounted) {
        // Fall back to static data
        _loadData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using demo data: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double _getTotalBalanceByType(List<Map<String, dynamic>> accounts, String type) {
    double total = 0;
    for (var account in accounts) {
      if (account['type'] == type) {
        total += (account['balance']['current'] ?? 0).toDouble();
      }
    }
    return total;
  }

  Future<void> _refreshData() async {
    print('=== Dashboard: _refreshData called ===');
    
    // Clear cache to force fresh data
    DataService.clearCache();
    _plaidService.clearCaches();
    
    if (_usePlaidData) {
      await _loadPlaidData(); 
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _successSubscription?.cancel();
    _exitSubscription?.cancel();
    super.dispose();
  }

  Widget _buildWelcomeBanner() {
    final currentHour = DateTime.now().hour;
    String greeting;

    if (currentHour < 12) {
      greeting = "Good Morning, ${_user?.displayName ?? 'User'}!";
    } else if (currentHour < 17) {
      greeting = "Good Afternoon, ${_user?.displayName ?? 'User'}!";
    } else {
      greeting = "Good Evening, ${_user?.displayName ?? 'User'}!";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B3A55), Color(0xFF3D5377)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(0),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          DateFormat('EEEE, MMM d').format(DateTime.now()),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _usePlaidData ? Colors.green : const Color(0xFFE5BA73),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _usePlaidData ? 'Live Data' : 'Demo Mode',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _showBalances ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _showBalances = !_showBalances;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Total Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<AccountBalance>>(
              future: _balancesFuture,
              builder: (context, snapshot) {
                double totalBalance = 0;
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final latestBalance = snapshot.data!.last;
                  totalBalance = latestBalance.checking +
                      latestBalance.creditCardBalance +
                      latestBalance.investmentAccount + 
                      latestBalance.savings;
                }

                return Text(
                  _showBalances
                      ? '\$${NumberFormat('#,##0.00').format(totalBalance)}'
                      : '••••••',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickActionButton(
                  icon: Icons.add_circle_outline,
                  label: 'Add Money',
                  onTap: _showAddMoneyDialog,
                ),
                _buildQuickActionButton(
                  icon: Icons.money,
                  label: 'Send Money',
                  onTap: _showSendMoneyDialog,
                ),
                _buildQuickActionButton(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Link Account',
                  onTap: _handleAddAccount,
                ),
                _buildQuickActionButton(
                  icon: Icons.analytics_outlined,
                  label: 'Analytics',
                  onTap: _showAnalyticsDialog,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFFE5BA73),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Color(0xFF2B3A55),
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedAccountsSection() {
    if (_connectedAccounts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CONNECTED ACCOUNTS',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              TextButton(
                onPressed: _showAccountManagementDialog,
                child: const Text(
                  'Manage',
                  style: TextStyle(
                    color: Color(0xFF2B3A55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...(_connectedAccounts.map((account) => _buildConnectedAccountCard(account))),
        ],
      ),
    );
  }

  Widget _buildConnectedAccountCard(ConnectedAccount account) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2B3A55).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance,
                color: Color(0xFF2B3A55),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.institutionName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B3A55),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Connected ${_formatRelativeTime(account.connectedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  void _showAccountManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Connected Accounts'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_connectedAccounts.isEmpty)
                const Text('No accounts connected yet.')
              else
                ..._connectedAccounts.map((account) => ListTile(
                  leading: const Icon(Icons.account_balance),
                  title: Text(account.institutionName),
                  subtitle: Text('Connected ${_formatRelativeTime(account.connectedAt)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final confirmed = await _showDisconnectConfirmation(account.institutionName);
                      if (confirmed == true) {
                        await _disconnectAccount(account);
                        Navigator.pop(context);
                      }
                    },
                  ),
                )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAddAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B3A55),
            ),
            child: const Text('Add Account', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDisconnectConfirmation(String bankName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Account'),
        content: Text('Are you sure you want to disconnect from $bankName? This will remove all associated data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectAccount(ConnectedAccount account) async {
    try {
      setState(() => _isLoading = true);
      
      final success = await _plaidService.disconnectAccount(account.itemId);
      
      if (success) {
        await _loadConnectedAccounts();
        await _refreshData();
        
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

  void _showAddMoneyDialog() {
    final TextEditingController amountController = TextEditingController();
    
    List<String> accounts = [];
    if (_usePlaidData && _plaidAccounts.isNotEmpty) {
      accounts = _plaidAccounts
          .where((account) => account['type'] == 'depository')
          .map((account) => '${account['name']} (${account['mask'] ?? '****'})')
          .toList();
    }
    
    if (accounts.isEmpty) {
      accounts = ['Checking Account']; 
    }
    
    String selectedAccount = accounts.first;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Money'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: selectedAccount,
                isExpanded: true,
                items: accounts.map((account) {
                  return DropdownMenuItem<String>(
                    value: account,
                    child: Text(account),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedAccount = value;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('\$$amount added to $selectedAccount'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSendMoneyDialog() {
    final TextEditingController recipientController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    
    List<String> accounts = [];
    if (_usePlaidData && _plaidAccounts.isNotEmpty) {
      accounts = _plaidAccounts
          .where((account) => account['type'] == 'depository')
          .map((account) => '${account['name']} (${account['mask'] ?? '****'})')
          .toList();
    }
    
    if (accounts.isEmpty) {
      accounts = ['Checking Account']; 
    }
    
    String selectedAccount = accounts.first;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Send Money'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: recipientController,
                decoration: const InputDecoration(labelText: 'Recipient'),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: selectedAccount,
                isExpanded: true,
                items: accounts.map((account) {
                  return DropdownMenuItem<String>(
                    value: account,
                    child: Text(account),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedAccount = value;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0 && recipientController.text.isNotEmpty) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('\$$amount sent from $selectedAccount to ${recipientController.text}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnalyticsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SpendingScreen()),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/logo_cropped.png',
          height: 120,
          width: 120,
        ),
        const SizedBox(height: 20),
        const Text(
          'Connect your first account to get started!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2B3A55),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Link your bank account to see real-time\nfinancial data and insights.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _handleAddAccount,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Connect Account'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE5BA73),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountItemCard(
    String title,
    String amount,
    IconData icon, {
    Color? amountColor,
    bool expandable = true,
    bool showPlaceholder = false,
    required AccountBalance latestBalance,
  }) {
    final displayAmount = _showBalances ? amount : '••••••';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        color: Colors.white, 
        child: Column(
          children: [
            InkWell(
              onTap: expandable
                  ? () {
                      setState(() {
                        _expandedSections[title] = !_expandedSections[title]!;
                      });
                    }
                  : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B3A55).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF2B3A55),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          showPlaceholder
                              ? Container(
                                  width: 80,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                )
                              : Text(
                                  displayAmount,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: amountColor,
                                  ),
                                ),
                        ],
                      ),
                    ),
                    if (expandable)
                      Icon(
                        _expandedSections[title]!
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey,
                      ),
                  ],
                ),
              ),
            ),
            if (expandable && _expandedSections[title]!)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: _buildExpandedSection(title),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSection(String title) {
    if (_usePlaidData && (title == 'Checking' || title == 'Card Balance' || title == 'Investments')) {
      return _buildPlaidExpandedSection(title);
    }
    
    switch (title) {
      case 'Checking':
        return FutureBuilder<List<CheckingAccount>>(
          future: _dataService.getCheckingAccounts(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: Color(0xFFE5BA73),
                  ),
                ),
              );
            }
            return Column(
              children: snapshot.data!
                  .map((account) => _buildAccountSubItem(
                        name: account.name,
                        subtitle: '${account.bankName} - ${account.type}',
                        amount: '\$${account.balance.toStringAsFixed(2)}',
                      ))
                  .toList(),
            );
          },
        );

      case 'Card Balance':
        return FutureBuilder<List<CreditCard>>(
          future: _dataService.getCreditCards(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: Color(0xFFE5BA73),
                  ),
                ),
              );
            }
            return Column(
              children: snapshot.data!.map((card) => _buildCreditCardItem(card)).toList(),
            );
          },
        );

      case 'Investments':
        return _buildInvestmentSection();

      default:
        return const SizedBox();
    }
  }

  Widget _buildInvestmentSection() {
    if (_usePlaidData && _plaidAccounts.isNotEmpty) {
      final investmentAccounts = _plaidAccounts.where((account) => 
        account['type'] == 'investment' || 
        (account['subtype'] != null && 
          ['investment', '401k', 'ira', 'retirement'].contains(account['subtype'].toString().toLowerCase()))
      ).toList();

      if (investmentAccounts.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('No investment accounts connected'),
          ),
        );
      }

      return Column(
        children: investmentAccounts.map((account) {
          final balance = (account['balance']['current'] ?? 0).toDouble();
          return _buildInvestmentItem(
            name: account['name'] ?? 'Investment Account',
            subtitle: account['subtype'] != null ? 
                '${account['subtype'].toString().toUpperCase()} - ${account['mask'] ?? '****'}' : 
                'Investment Account',
            amount: '\$${balance.toStringAsFixed(2)}',
            returnRate: 6.5,
            showGraph: (account['subtype']?.toString().toLowerCase() == '401k'),
          );
        }).toList(),
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('No investment data available'),
      ),
    );
  }

  Widget _buildPlaidExpandedSection(String title) {
    if (_plaidAccounts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No Plaid accounts available'),
        ),
      );
    }

    List<Map<String, dynamic>> filteredAccounts = [];
    if (title == 'Checking') {
      filteredAccounts = _plaidAccounts.where((account) => 
        account['type'] == 'depository' || 
        (account['subtype'] != null && 
          ['checking', 'savings'].contains(account['subtype'].toString().toLowerCase()))
      ).toList();
    } else if (title == 'Card Balance') {
      filteredAccounts = _plaidAccounts.where((account) => 
        account['type'] == 'credit' || 
        (account['subtype'] != null && 
          ['credit', 'credit card'].contains(account['subtype'].toString().toLowerCase()))
      ).toList();
    } else if (title == 'Investments') {
      filteredAccounts = _plaidAccounts.where((account) => 
        account['type'] == 'investment' || 
        (account['subtype'] != null && 
          ['investment', '401k', 'ira', 'retirement'].contains(account['subtype'].toString().toLowerCase()))
      ).toList();
    }

    if (filteredAccounts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('No ${title.toLowerCase()} accounts connected'),
        ),
      );
    }

    if (title == 'Card Balance') {
      return Column(
        children: filteredAccounts.map((account) {
          final card = CreditCard(
            name: account['name'] ?? 'Credit Card',
            lastFour: account['mask'] ?? '****',
            balance: (account['balance']['current'] ?? 0).toDouble(),
            creditLimit: (account['balance']['limit'] ?? 1000).toDouble(),
            apr: 19.99,
            bankName: account['institution'] ?? 'Bank',
          );
          return _buildCreditCardItem(card);
        }).toList(),
      );
    } else if (title == 'Investments') {
      return Column(
        children: filteredAccounts.map((account) {
          final balance = (account['balance']['current'] ?? 0).toDouble();
          return _buildInvestmentItem(
            name: account['name'] ?? 'Investment Account',
            subtitle: account['subtype'] != null ? 
                '${account['subtype'].toString().toUpperCase()} - ${account['mask'] ?? '****'}' : 
                'Investment Account',
            amount: '\$${balance.toStringAsFixed(2)}',
            returnRate: 6.5,
            showGraph: (account['subtype']?.toString().toLowerCase() == '401k'),
          );
        }).toList(),
      );
    } else {
      return Column(
        children: filteredAccounts.map((account) {
          final balance = (account['balance']['available'] ?? account['balance']['current'] ?? 0).toDouble();
          return _buildAccountSubItem(
            name: account['name'] ?? 'Account',
            subtitle: '${account['subtype'] ?? 'Checking'} - ${account['mask'] ?? '****'}',
            amount: '\$${balance.toStringAsFixed(2)}',
          );
        }).toList(),
      );
    }
  }

  Widget _buildAccountSubItem({
    required String name,
    required String subtitle,
    required String amount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _showBalances ? amount : '••••••',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCardItem(CreditCard card) {
    final utilization = card.creditLimit > 0 ? card.balance / card.creditLimit : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2B3A55),
            const Color(0xFF2B3A55).withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  card.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Image.asset(
                'assets/images/just_logo.png',
                height: 30,
                width: 30,
                color: Colors.white.withOpacity(0.9),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '**** **** **** ${card.lastFour}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Balance',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _showBalances ? '\$${card.balance.toStringAsFixed(2)}' : '••••••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Available Credit',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _showBalances ? '\$${(card.creditLimit - card.balance).toStringAsFixed(2)}' : '••••••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Credit Used',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    height: 6,
                    width: (maxWidth * utilization).clamp(0, maxWidth),
                    decoration: BoxDecoration(
                      color: utilization > 0.7 ? Colors.red[400] : Colors.green[400],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(utilization * 100).toStringAsFixed(1)}% used',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                'Limit: \$${card.creditLimit.toStringAsFixed(0)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentItem({
    required String name,
    required String subtitle,
    required String amount,
    required double returnRate,
    bool showCDDetails = false,
    bool showGraph = false,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2B3A55),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _showBalances ? amount : '••••••',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_upward,
                      color: Colors.green,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$returnRate% return',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAccountItem(String title) {
    IconData icon;
    switch (title) {
      case 'Checking':
        icon = Icons.home_outlined;
        break;
      case 'Card Balance':
        icon = Icons.credit_card_outlined;
        break;
      case 'Net Cash':
        icon = Icons.attach_money_outlined;
        break;
      default:
        icon = Icons.account_balance_outlined;
    }

    return _buildAccountItemCard(
      title,
      'N/A',
      icon,
      showPlaceholder: true,
      expandable: false,
      latestBalance: AccountBalance(
        date: DateTime.now(),
        checking: 0,
        creditCardBalance: 0,
        savings: 0,
        investmentAccount: 0,
        netWorth: 0,
      ),
    );
  }

  Future<void> _handleAddAccount() async {
    print('=== Dashboard: _handleAddAccount called ===');
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('Starting Plaid Link process...');
      
      final linkToken = await _plaidService.createLinkToken();
      
      if (linkToken == null) {
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create link token. Please try again later.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      
      print('Successfully created link token, opening Plaid Link...');
      
      LinkTokenConfiguration configuration = LinkTokenConfiguration(
        token: linkToken,
      );
      
      await PlaidLink.create(configuration: configuration);
      await PlaidLink.open();
      
      // Note: Success and error handling is done in the stream listeners
            
    } catch (e) {
      print('Error in _handleAddAccount: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        String errorMessage = 'Failed to connect account. ';
        
        if (e.toString().contains('NETWORK_ERROR')) {
          errorMessage += 'Please check your internet connection and try again.';
        } else if (e.toString().contains('INVALID_CONFIG')) {
          errorMessage += 'Configuration error. Please contact support.';
        } else {
          errorMessage += 'Please try again later.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleAddAccount,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder(
      future: Future.wait([_balancesFuture, _transactionsFuture]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (!_hasLoadedData) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                _buildWelcomeBanner(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE5BA73),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              const Text(
                                'ACCOUNTS',
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildEmptyAccountItem('Checking'),
                              _buildEmptyAccountItem('Card Balance'),
                              _buildEmptyAccountItem('Net Cash'),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'ACTIONS',
                                    style: TextStyle(
                                      fontSize: 13,
                                      letterSpacing: 1,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.refresh, color: Color(0xFF2B3A55)),
                                        onPressed: _loadData,
                                      ),
                                      TextButton(
                                        onPressed: _handleAddAccount,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          foregroundColor: const Color(0xFF2B3A55),
                                        ),
                                        child: const Text(
                                          'Add Account',
                                          style: TextStyle(
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 80),
                              _buildEmptyState(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        }

        if (_isLoading) {
          return Scaffold(
            body: Column(
              children: [
                _buildWelcomeBanner(),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE5BA73),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final balances = snapshot.data![0] as List<AccountBalance>;
        final transactions = snapshot.data![1] as List<Transaction>;

        if (balances.isEmpty) {
          return Scaffold(
            body: Column(
              children: [
                _buildWelcomeBanner(),
                Expanded(
                  child: Center(
                    child: Text(
                      'No account data available',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final latestBalance = balances.last;

        return Scaffold(
          backgroundColor: Colors.white,
          body:           RefreshIndicator(
            color: const Color(0xFFE5BA73),
            onRefresh: _refreshData,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildWelcomeBanner(),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 24),
                      const SmartFeaturesDashboardWidget(),
                      _buildConnectedAccountsSection(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ACCOUNTS',
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Color(0xFF2B3A55)),
                                onPressed: _refreshData,
                              ),
                              TextButton(
                                onPressed: _handleAddAccount,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: const Color(0xFF2B3A55),
                                ),
                                child: const Text(
                                  'Add Account',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildAccountItemCard(
                        'Checking',
                        '\$${latestBalance.checking.toStringAsFixed(2)}',
                        Icons.account_balance_outlined,
                        latestBalance: latestBalance,
                      ),
                      _buildAccountItemCard(
                        'Card Balance',
                        '-\$${latestBalance.creditCardBalance.abs().toStringAsFixed(2)}',
                        Icons.credit_card_outlined,
                        latestBalance: latestBalance,
                        amountColor: Colors.red,
                      ),
                      _buildAccountItemCard(
                        'Net Cash',
                        '\$${(latestBalance.checking + latestBalance.creditCardBalance).toStringAsFixed(2)}',
                        Icons.attach_money_outlined,
                        latestBalance: latestBalance,
                        amountColor: Colors.green,
                        expandable: false,
                      ),
                      _buildAccountItemCard(
                        'Investments',
                        '\$${latestBalance.investmentAccount.toStringAsFixed(2)}',
                        Icons.show_chart_outlined,
                        latestBalance: latestBalance,
                      ),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            backgroundColor: const Color(0xFFE5BA73),
            child: const Icon(Icons.insights, color: Colors.white),
          ),
        );
      },
    );
  }
}