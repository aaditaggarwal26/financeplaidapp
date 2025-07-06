import 'package:finsight/models/transaction.dart';
import 'package:finsight/services/data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;
  final Function()? onDelete;

  const TransactionDetailScreen({
    Key? key,
    required this.transaction,
    this.onDelete,
  }) : super(key: key);

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getCategoryColor() {
    final Map<String, Color> categoryColors = {
      'Groceries': const Color(0xFFE5BA73),
      'Utilities': const Color(0xFF4A90E2),
      'Rent': const Color(0xFF2B3A55),
      'Transportation': const Color(0xFF50C878),
      'Entertainment': const Color(0xFFE67E22),
      'Dining Out': const Color(0xFFE74C3C),
      'Shopping': const Color(0xFF9B59B6),
      'Healthcare': const Color(0xFF1ABC9C),
      'Insurance': const Color(0xFF34495E),
      'Subscriptions': const Color(0xFFFF6B6B),
      'Banking': const Color(0xFF3498DB),
      'Travel': const Color(0xFFE91E63),
      'Education': const Color(0xFF9C27B0),
      'Miscellaneous': const Color(0xFF95A5A6),
    };
    return categoryColors[widget.transaction.category] ?? const Color(0xFF95A5A6);
  }

  IconData _getCategoryIcon() {
    switch (widget.transaction.category) {
      case 'Groceries':
        return Icons.shopping_basket;
      case 'Utilities':
        return Icons.power;
      case 'Rent':
        return Icons.home;
      case 'Transportation':
        return Icons.directions_car;
      case 'Entertainment':
        return Icons.movie;
      case 'Dining Out':
        return Icons.restaurant;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Healthcare':
        return Icons.medical_services;
      case 'Insurance':
        return Icons.security;
      case 'Subscriptions':
        return Icons.subscriptions;
      case 'Banking':
        return Icons.account_balance;
      case 'Travel':
        return Icons.flight;
      case 'Education':
        return Icons.school;
      default:
        return Icons.attach_money;
    }
  }

  Future<void> _launchWebsite() async {
    if (widget.transaction.merchantWebsite != null) {
      final url = 'https://${widget.transaction.merchantWebsite}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        backgroundColor: _getCategoryColor(),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteTransaction() async {
    if (!widget.transaction.isPersonal || widget.transaction.id == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dataService = DataService();
      await dataService.deleteTransaction(widget.transaction.id!);

      if (widget.onDelete != null) {
        widget.onDelete!();
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting transaction: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTransaction();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Enhanced Header Section
                  Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 20,
                      bottom: 40,
                      left: 20,
                      right: 20,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          categoryColor,
                          categoryColor.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: categoryColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Top Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('EEE, MMM d, yyyy').format(widget.transaction.date),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              children: [
                                if (widget.transaction.isPersonal && widget.transaction.id != null)
                                  IconButton(
                                    icon: _isLoading 
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.delete_outline, color: Colors.white),
                                    onPressed: _isLoading ? null : _showDeleteConfirmation,
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Merchant Logo and Info
                        Row(
                          children: [
                            // Merchant Logo
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: widget.transaction.hasLogo
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Image.network(
                                        widget.transaction.merchantLogoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            _getCategoryIcon(),
                                            color: Colors.white,
                                            size: 28,
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      _getCategoryIcon(),
                                      color: Colors.white,
                                      size: 28,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Merchant Name and Category
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.transaction.displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          widget.transaction.category,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (widget.transaction.isRecurring) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'RECURRING',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Transaction Amount
                        Text(
                          widget.transaction.formattedAmount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Transaction Details
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Quick Actions
                        if (widget.transaction.merchantWebsite != null) ...[
                          _buildActionCard(
                            icon: Icons.language,
                            title: 'Visit Website',
                            subtitle: widget.transaction.merchantWebsite!,
                            onTap: _launchWebsite,
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Transaction Details Card
                        _buildDetailCard(
                          title: 'Transaction Details',
                          children: [
                            _buildDetailItem(
                              'Description',
                              widget.transaction.description,
                              copyable: true,
                            ),
                            _buildDetailItem('Account', widget.transaction.account),
                            _buildDetailItem('Transaction Type', widget.transaction.transactionType),
                            _buildDetailItem(
                              'Time',
                              DateFormat('h:mm a').format(widget.transaction.date),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Merchant Information Card
                        if (widget.transaction.merchantName != null ||
                            widget.transaction.originalDescription != null) ...[
                          _buildDetailCard(
                            title: 'Merchant Information',
                            children: [
                              if (widget.transaction.merchantName != null)
                                _buildDetailItem(
                                  'Merchant Name',
                                  widget.transaction.merchantName!,
                                  copyable: true,
                                ),
                              if (widget.transaction.originalDescription != null &&
                                  widget.transaction.originalDescription != widget.transaction.description)
                                _buildDetailItem(
                                  'Original Description',
                                  widget.transaction.originalDescription!,
                                  copyable: true,
                                ),
                              if (widget.transaction.location != null)
                                _buildDetailItem('Location', widget.transaction.location!),
                              if (widget.transaction.paymentMethod != null)
                                _buildDetailItem('Payment Method', widget.transaction.paymentMethod!),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Additional Information Card
                        _buildDetailCard(
                          title: 'Additional Information',
                          children: [
                            if (widget.transaction.cardId != null)
                              _buildDetailItem(
                                'Card Used',
                                widget.transaction.cardId!.length >= 4
                                    ? '****${widget.transaction.cardId!.substring(widget.transaction.cardId!.length - 4)}'
                                    : widget.transaction.cardId!,
                              ),
                            _buildDetailItem(
                              'Entry Type',
                              widget.transaction.isPersonal ? 'Manual Entry' : 'Bank Import',
                            ),
                            if (widget.transaction.plaidCategory != null)
                              _buildDetailItem(
                                'Plaid Category',
                                widget.transaction.plaidCategory!,
                              ),
                            if (widget.transaction.confidence != null)
                              _buildDetailItem(
                                'Categorization Confidence',
                                '${(widget.transaction.confidence! * 100).toStringAsFixed(0)}%',
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 100), // Extra space for scrolling
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getCategoryColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: _getCategoryColor(),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B3A55),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _copyToClipboard(value),
                    child: Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}