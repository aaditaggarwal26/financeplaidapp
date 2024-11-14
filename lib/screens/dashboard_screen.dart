import 'package:finsight/models/account_balance.dart';
import 'package:finsight/models/checking_account.dart';
import 'package:finsight/models/credit_card.dart';
import 'package:finsight/models/transaction.dart';
import 'package:finsight/services/data_service.dart';
import 'package:finsight/services/plaid_service.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  final DataService _dataService = DataService();
  late Future<List<AccountBalance>> _balancesFuture;
  late Future<List<Transaction>> _transactionsFuture;
  int _currentPage = 0;
  static bool _hasLoadedData = false;

  Map<String, bool> _expandedSections = {
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
  }

  void _initializeData() {
    if (!_hasLoadedData) {
      // Only initialize with empty state on first load
      setState(() {
        _balancesFuture = Future.value([]);
        _transactionsFuture = Future.value([]);
      });
    } else {
      // Load data if we've already shown it before
      _loadData();
    }
  }

  void _loadData() {
    setState(() {
      _balancesFuture = _dataService.getAccountBalances();
      _transactionsFuture = _dataService.getTransactions();
      _hasLoadedData = true;
    });
  }

  void _refreshData() {
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/logo_cropped.png',
          height: 200,
          width: 200,
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text('It seems like you have no accounts connected!'),
        ),
        const Center(
          child: Text('Connect an account now to get start.'),
        ),
      ],
    );
  }

  Widget _buildGraphCard({required bool isSpending}) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF2B3A55).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSpending ? 'Current spend this month' : 'Credit Score History',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  isSpending ? '\$4,345.67' : '739',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5BA73).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_upward,
                        color: Color(0xFFE5BA73),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSpending ? '\$88.89 above' : '+4 points',
                        style: const TextStyle(
                          color: Color(0xFFE5BA73),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 100,
              child: CustomPaint(
                size: const Size(double.infinity, 100),
                painter: isSpending
                    ? SpendingGraphPainter()
                    : CreditScoreGraphPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableAccountItem(
    IconData icon,
    String title,
    String amount,
    List<Transaction> transactions,
    AccountBalance balance, {
    Color? amountColor,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expandedSections[title] = !_expandedSections[title]!;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF2B3A55), size: 24),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16),
                ),
                const Spacer(),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 16,
                    color: amountColor ?? Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
        if (_expandedSections[title]!)
          Container(
            color: const Color(0xFFE5BA73).withOpacity(0.05),
            child: _buildExpandedSection(title, transactions, balance),
          ),
      ],
    );
  }

  Widget _buildExpandedSection(
    String title,
    List<Transaction> transactions,
    AccountBalance balance,
  ) {
    switch (title) {
      case 'Checking':
        return FutureBuilder<List<CheckingAccount>>(
          future: _dataService.getCheckingAccounts(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: snapshot.data!
                  .map((account) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 8),
                        child: Card(
                          color: Colors.white,
                          child: ListTile(
                            title: Text(account.name),
                            subtitle:
                                Text('${account.bankName} - ${account.type}'),
                            trailing: Text(
                              '\$${account.balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
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
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: snapshot.data!
                  .map((card) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 8),
                        child: Card(
                          color: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Color(0xFF2B3A55),
                              width: 0.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      card.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '-\$${card.balance.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${card.bankName} •••• ${card.lastFour}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: card.balance /
                                                  card.creditLimit,
                                              backgroundColor: Colors.grey[200],
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                card.balance /
                                                            card.creditLimit >
                                                        0.7
                                                    ? Colors.red
                                                    : const Color(0xFFE5BA73),
                                              ),
                                              minHeight: 8,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Credit Used: ${((card.balance / card.creditLimit) * 100).toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Credit Limit',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '\$${card.creditLimit.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'APR: ${card.apr}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        );
      case 'Investments':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Total Investment: \$${balance.investmentAccount.toStringAsFixed(2)}'),
            ],
          ),
        );
      default:
        return const SizedBox();
    }
  }

  Future<void> _handleAddAccount() async {
    final linkToken = await PlaidIntegrationService.createLinkToken();

    if (linkToken != null) {
      print('Link Token: $linkToken');

      LinkTokenConfiguration configuration = LinkTokenConfiguration(
        token: linkToken,
      );

      /// Creates a internal handler for Plaid Link. A one-time use object used to open a Link session. Should always be called before open.

      PlaidLink.create(configuration: configuration);

      /// Open Plaid Link by calling open on the handler.

      PlaidLink.open();

      // Here you should implement the Plaid Link flow using the generated link token.

      // Simulate user linking account and obtaining public token for now.

      final publicToken =
          linkToken; // This should be replaced by the real public token from Plaid Link

      final accessToken =
          await PlaidIntegrationService.exchangePublicToken(publicToken);

      if (accessToken != null) {
        print('Access Token: $accessToken');

        await PlaidIntegrationService.fetchTransactions(accessToken);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin

    return FutureBuilder(
      future: Future.wait([_balancesFuture, _transactionsFuture]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (!_hasLoadedData) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                    bottom: 16,
                    left: 16,
                    right: 16,
                  ),
                  color: const Color(0xFF2B3A55),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('E, MMM d').format(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 300, child: _buildEmptyState()),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
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
                                    icon: const Icon(Icons.refresh,
                                        color: Color(0xFF2B3A55)),
                                    onPressed:
                                        _loadData, // Changed from _refreshData to _loadData
                                  ),
                                  TextButton(
                                    onPressed: _handleAddAccount,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Text(
                                      'Add Account',
                                      style: TextStyle(
                                        color: Color(0xFF2B3A55),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildEmptyAccountItem('Checking'),
                        _buildEmptyAccountItem('Card Balance'),
                        _buildEmptyAccountItem('Net Cash'),
                      ],
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
          return const Scaffold(
            body: Center(child: Text('No account data available')),
          );
        }

        final latestBalance = balances.last;

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  bottom: 16,
                  left: 16,
                  right: 16,
                ),
                color: const Color(0xFF2B3A55),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E, MMM d').format(DateTime.now()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 300,
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: _buildGraphCard(isSpending: true),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: _buildGraphCard(isSpending: false),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPage == 0
                                  ? const Color(0xFF2B3A55)
                                  : Colors.grey.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPage == 1
                                  ? const Color(0xFF2B3A55)
                                  : Colors.grey.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
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
                                  icon: const Icon(Icons.refresh,
                                      color: Color(0xFF2B3A55)),
                                  onPressed: _refreshData,
                                ),
                                TextButton(
                                  onPressed: _handleAddAccount,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text(
                                    'Add Account',
                                    style: TextStyle(
                                      color: Color(0xFF2B3A55),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildExpandableAccountItem(
                        Icons.home_outlined,
                        'Checking',
                        '\$${latestBalance.checking.toStringAsFixed(2)}',
                        transactions,
                        latestBalance,
                      ),
                      _buildExpandableAccountItem(
                        Icons.credit_card_outlined,
                        'Card Balance',
                        '\$${latestBalance.creditCardBalance.toStringAsFixed(2)}',
                        transactions,
                        latestBalance,
                        amountColor: Colors.red,
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.attach_money_outlined,
                                color: const Color(0xFF2B3A55), size: 24),
                            const SizedBox(width: 16),
                            const Text(
                              'Net Cash',
                              style: TextStyle(fontSize: 16),
                            ),
                            const Spacer(),
                            Text(
                              '\$${(latestBalance.checking + latestBalance.creditCardBalance).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.show_chart_outlined,
                                color: const Color(0xFF2B3A55), size: 24),
                            const SizedBox(width: 16),
                            const Text(
                              'Investments',
                              style: TextStyle(fontSize: 16),
                            ),
                            const Spacer(),
                            Text(
                              '\$${latestBalance.investmentAccount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyAccountItem(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            title == 'Checking'
                ? Icons.home_outlined
                : title == 'Card Balance'
                    ? Icons.credit_card_outlined
                    : Icons.attach_money_outlined,
            color: const Color(0xFF2B3A55),
            size: 24,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
          const Spacer(),
          const Text(
            'N/A',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class SpendingGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2B3A55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.lineTo(size.width * 0.4, size.height * 0.8);
    path.lineTo(size.width * 0.6, size.height * 0.2);
    path.lineTo(size.width, size.height * 0.2);

    final fillPaint = Paint()
      ..color = const Color(0xFF2B3A55).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class CreditScoreGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2B3A55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.lineTo(size.width * 0.2, size.height * 0.5);
    path.lineTo(size.width * 0.4, size.height * 0.4);
    path.lineTo(size.width * 0.6, size.height * 0.3);
    path.lineTo(size.width * 0.8, size.height * 0.2);
    path.lineTo(size.width, size.height * 0.2);

    final fillPaint = Paint()
      ..color = const Color(0xFF2B3A55).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
