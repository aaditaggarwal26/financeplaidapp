import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:finsight/models/transaction.dart';
import 'package:finsight/services/data_service.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({Key? key}) : super(key: key);

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final DataService _dataService = DataService();

  File? _scannedImage;
  bool _isProcessing = false;
  bool _isSuccess = false;
  ReceiptData? _extractedData;
  bool _showScannedReceipts = true;

  late AnimationController _scanAnimationController;
  late AnimationController _successAnimationController;
  late Animation<double> _scanAnimation;
  late Animation<double> _successAnimation;

  @override
  void initState() {
    super.initState();
    _loadToggleState();

    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _scanAnimationController, curve: Curves.easeInOut));

    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _successAnimationController, curve: Curves.elasticOut));
  }
  
  Future<void> _loadToggleState() async {
    final show = await _dataService.getShowScannedReceipts();
    if (mounted) {
      setState(() {
        _showScannedReceipts = show;
      });
    }
  }

  Future<void> _toggleScannedReceipts(bool value) async {
    setState(() {
      _showScannedReceipts = value;
    });
    await _dataService.setShowScannedReceipts(value);
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  Future<void> _scanFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _scannedImage = File(image.path);
          _isProcessing = true;
          _isSuccess = false;
        });

        await _processReceipt();
      }
    } catch (e) {
      _showErrorDialog('Failed to capture image: $e');
    }
  }

  Future<void> _scanFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _scannedImage = File(image.path);
          _isProcessing = true;
          _isSuccess = false;
        });

        await _processReceipt();
      }
    } catch (e) {
      _showErrorDialog('Failed to select image: $e');
    }
  }

  Future<void> _processReceipt() async {
    await Future.delayed(const Duration(seconds: 3));
    final extractedData = _mockExtractReceiptData();
    setState(() {
      _isProcessing = false;
      _isSuccess = true;
      _extractedData = extractedData;
    });
    _successAnimationController.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _showSaveDialog();
      }
    });
  }

  ReceiptData _mockExtractReceiptData() {
    final merchants = [
      {'name': 'Whole Foods Market', 'category': 'Groceries', 'logo': 'wholefoodsmarket.com'},
      {'name': 'Starbucks', 'category': 'Dining Out', 'logo': 'starbucks.com'},
      {'name': 'Target', 'category': 'Shopping', 'logo': 'target.com'},
    ];
    final random = math.Random();
    final merchant = merchants[random.nextInt(merchants.length)];
    final amount = 8.99 + random.nextDouble() * 150;
    final date = DateTime.now().subtract(Duration(minutes: random.nextInt(60)));
    return ReceiptData(
      merchantName: merchant['name']!,
      totalAmount: amount,
      date: date,
      category: merchant['category']!,
      items: _generateMockItems(random, merchant['category']!),
      taxAmount: amount * (0.06 + random.nextDouble() * 0.04),
      confidence: 0.82 + random.nextDouble() * 0.17,
      merchantWebsite: merchant['logo']!,
      location: _generateMockLocation(random),
      paymentMethod: _generatePaymentMethod(random),
    );
  }

  List<ReceiptItem> _generateMockItems(math.Random random, String category) {
    final itemsByCategory = {
      'Groceries': ['Organic Bananas', 'Almond Milk', 'Avocados'],
      'Dining Out': ['Grande Latte', 'Blueberry Muffin', 'Avocado Toast'],
      'Shopping': ['Cotton T-Shirt', 'Phone Case', 'Wireless Earbuds'],
    };
    final items = itemsByCategory[category] ?? itemsByCategory['Shopping']!;
    final itemCount = 1 + random.nextInt(3);
    return List.generate(itemCount, (index) {
      final itemName = items[random.nextInt(items.length)];
      final basePrice = category == 'Groceries' ? 3.99 : 12.99;
      return ReceiptItem(
        name: itemName,
        price: basePrice + random.nextDouble() * (basePrice * 0.8),
        quantity: 1,
      );
    });
  }

  String _generateMockLocation(math.Random random) {
    final locations = ['Seattle, WA', 'New York, NY', 'San Francisco, CA'];
    return locations[random.nextInt(locations.length)];
  }

  String _generatePaymentMethod(math.Random random) {
    final methods = ['Credit Card', 'Debit Card', 'Cash'];
    return methods[random.nextInt(methods.length)];
  }

  void _showSaveDialog() {
    if (_extractedData == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Save Scanned Receipt?'),
        content: Text(
            'Save this transaction of \$${_extractedData!.totalAmount.toStringAsFixed(2)} from ${_extractedData!.merchantName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF2B3A55))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B3A55),
              foregroundColor: Colors.white
            ),
            onPressed: () async {
              await _saveTransaction();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (_extractedData == null) return;
    try {
      final transaction = Transaction(
        id: 'receipt_${DateTime.now().millisecondsSinceEpoch}',
        date: _extractedData!.date,
        description: _extractedData!.merchantName,
        category: _extractedData!.category,
        amount: _extractedData!.totalAmount,
        account: 'Receipt Scan',
        transactionType: 'Debit',
        isPersonal: true,
        merchantName: _extractedData!.merchantName,
        merchantWebsite: _extractedData!.merchantWebsite,
        confidence: _extractedData!.confidence,
        location: _extractedData!.location,
        paymentMethod: _extractedData!.paymentMethod,
        merchantMetadata: {
          'receipt_scanned': true,
          'items': _extractedData!.items
              .map((item) => {
                    'name': item.name,
                    'price': item.price,
                    'quantity': item.quantity
                  })
              .toList(),
          'tax_amount': _extractedData!.taxAmount,
          'scan_confidence': _extractedData!.confidence,
        },
      );
      await _dataService.appendTransaction(transaction);
      DataService.clearCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Receipt saved!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        setState(() {
          _scannedImage = null;
          _extractedData = null;
          _isSuccess = false;
        });
        _successAnimationController.reset();
      }
    } catch (e) {
      _showErrorDialog('Failed to save transaction: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B3A55),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeaderContent(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: _buildMainContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Receipt Scanner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'AI-powered receipt recognition',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE5BA73).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFFE5BA73),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isProcessing) return _buildProcessingView();
    if (_isSuccess && _extractedData != null) return _buildSuccessView();
    return _buildScanOptions();
  }

  Widget _buildScanOptions() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildReceiptToggleCard(),
            const SizedBox(height: 24),
            _buildARScannerMockup(),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 24),
            _buildFeaturesList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReceiptToggleCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: Color(0xFF2B3A55)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Show Scanned Receipts in App',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B3A55),
              ),
            ),
          ),
          Switch(
            value: _showScannedReceipts,
            onChanged: _toggleScannedReceipts,
            activeColor: const Color(0xFFE5BA73),
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildARScannerMockup() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2B3A55).withOpacity(0.05),
            const Color(0xFFE5BA73).withOpacity(0.05),
          ],
        ),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(200, 200),
                painter: ARScannerPainter(_scanAnimation.value),
              );
            },
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long,
                size: 60,
                color: const Color(0xFF2B3A55).withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              const Text(
                'Position receipt in viewfinder',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2B3A55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.camera_alt,
            label: 'Take Photo',
            color: const Color(0xFF2B3A55),
            onTap: _scanFromCamera,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            icon: Icons.photo_library,
            label: 'From Gallery',
            color: const Color(0xFFE5BA73),
            onTap: _scanFromGallery,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Smart Features',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B3A55),
          ),
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          icon: Icons.auto_awesome,
          title: 'AI-Powered OCR',
          description: 'Automatically extracts text from receipts',
        ),
        _buildFeatureItem(
          icon: Icons.category,
          title: 'Smart Categorization',
          description: 'Intelligently categorizes expenses',
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2B3A55).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF2B3A55), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2B3A55),
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingView() {
    return const Center(child: CircularProgressIndicator(color: Color(0xFF2B3A55)));
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _successAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _successAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 40),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Receipt Processed!',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B3A55)),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildExtractedDataCard()),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B3A55),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: _saveTransaction,
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2B3A55),
                    side: const BorderSide(color: Color(0xFF2B3A55)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: () {
                    setState(() {
                      _scannedImage = null;
                      _isSuccess = false;
                    });
                  },
                  child: const Text('Scan Another'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedDataCard() {
    if (_extractedData == null) return const SizedBox();
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            _buildDataRow('Merchant', _extractedData!.merchantName),
            _buildDataRow('Amount', '\$${_extractedData!.totalAmount.toStringAsFixed(2)}'),
            _buildDataRow('Category', _extractedData!.category),
            _buildDataRow('Date', DateFormat('MMM d,specialmeal').format(_extractedData!.date)),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class ARScannerPainter extends CustomPainter {
  final double animationValue;
  ARScannerPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2B3A55).withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.8,
        height: size.height * 0.8);

    const cornerLength = 30.0;
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cornerLength, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cornerLength), paint);
    canvas.drawLine(rect.topRight, rect.topRight - const Offset(cornerLength, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cornerLength), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cornerLength, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft - const Offset(0, cornerLength), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight - const Offset(cornerLength, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight - const Offset(0, cornerLength), paint);

    final scanY = rect.top + (rect.height * animationValue);
    final scanPaint = Paint()
      ..color = const Color(0xFFE5BA73)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(rect.left, scanY), Offset(rect.right, scanY), scanPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ReceiptData {
  final String merchantName;
  final double totalAmount;
  final DateTime date;
  final String category;
  final List<ReceiptItem> items;
  final double taxAmount;
  final double confidence;
  final String? merchantWebsite;
  final String? location;
  final String? paymentMethod;

  ReceiptData({
    required this.merchantName,
    required this.totalAmount,
    required this.date,
    required this.category,
    required this.items,
    required this.taxAmount,
    required this.confidence,
    this.merchantWebsite,
    this.location,
    this.paymentMethod,
  });
}

class ReceiptItem {
  final String name;
  final double price;
  final int quantity;
  ReceiptItem({required this.name, required this.price, required this.quantity});
}