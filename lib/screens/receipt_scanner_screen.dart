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

  late AnimationController _scanAnimationController;
  late AnimationController _successAnimationController;
  late Animation<double> _scanAnimation;
  late Animation<double> _successAnimation;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  // Note: The camera will not work on an iOS simulator.
  // Use a real device or the gallery option for testing.
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
    // Simulate AI OCR and processing delay
    await Future.delayed(const Duration(seconds: 3));

    // Mock extracted data - in real app, this would use OCR and AI
    final extractedData = _mockExtractReceiptData();

    setState(() {
      _isProcessing = false;
      _isSuccess = true;
      _extractedData = extractedData;
    });

    _successAnimationController.forward();

    // Auto-save option after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _showSaveDialog();
      }
    });
  }

  ReceiptData _mockExtractReceiptData() {
    // Enhanced mock data with real merchant patterns
    final merchants = [
      {'name': 'Whole Foods Market', 'category': 'Groceries', 'logo': 'wholefoodsmarket.com'},
      {'name': 'Starbucks', 'category': 'Dining Out', 'logo': 'starbucks.com'},
      {'name': 'Target', 'category': 'Shopping', 'logo': 'target.com'},
      {'name': 'CVS Pharmacy', 'category': 'Healthcare', 'logo': 'cvs.com'},
      {'name': 'Shell', 'category': 'Transportation', 'logo': 'shell.com'},
      {'name': 'Amazon Go', 'category': 'Groceries', 'logo': 'amazon.com'},
      {'name': 'Safeway', 'category': 'Groceries', 'logo': 'safeway.com'},
      {'name': 'Best Buy', 'category': 'Shopping', 'logo': 'bestbuy.com'},
      {'name': 'McDonald\'s', 'category': 'Dining Out', 'logo': 'mcdonalds.com'},
      {'name': 'Costco Wholesale', 'category': 'Groceries', 'logo': 'costco.com'},
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
      taxAmount: amount * (0.06 + random.nextDouble() * 0.04), // 6-10% tax
      confidence: 0.82 + random.nextDouble() * 0.17, // 82-99% confidence
      merchantWebsite: merchant['logo']!,
      location: _generateMockLocation(random),
      paymentMethod: _generatePaymentMethod(random),
    );
  }

  List<ReceiptItem> _generateMockItems(math.Random random, String category) {
    final itemsByCategory = {
      'Groceries': [
        'Organic Bananas', 'Almond Milk', 'Whole Wheat Bread', 'Greek Yogurt',
        'Free Range Eggs', 'Avocados', 'Spinach', 'Chicken Breast', 'Olive Oil'
      ],
      'Dining Out': [
        'Grande Latte', 'Blueberry Muffin', 'Avocado Toast', 'Fresh Orange Juice',
        'Cappuccino', 'Breakfast Sandwich', 'Croissant', 'Iced Coffee'
      ],
      'Shopping': [
        'Cotton T-Shirt', 'Phone Case', 'Wireless Earbuds', 'Notebook',
        'Pen Set', 'Desk Lamp', 'USB Cable', 'Water Bottle'
      ],
      'Healthcare': [
        'Vitamin D3', 'Ibuprofen', 'Hand Sanitizer', 'Face Masks',
        'Thermometer', 'First Aid Kit', 'Allergy Medicine'
      ],
      'Transportation': [
        'Regular Gasoline', 'Car Wash', 'Air Freshener', 'Windshield Fluid'
      ],
    };

    final items = itemsByCategory[category] ?? itemsByCategory['Shopping']!;
    final itemCount = 1 + random.nextInt(5); // 1-5 items

    return List.generate(itemCount, (index) {
      final itemName = items[random.nextInt(items.length)];
      final basePrice = category == 'Groceries' ? 3.99 :
                       category == 'Dining Out' ? 4.50 :
                       category == 'Transportation' ? 35.00 : 12.99;

      return ReceiptItem(
        name: itemName,
        price: basePrice + random.nextDouble() * (basePrice * 0.8),
        quantity: 1 + random.nextInt(3),
      );
    });
  }

  String _generateMockLocation(math.Random random) {
    final locations = [
      'Seattle, WA', 'Portland, OR', 'San Francisco, CA', 'Los Angeles, CA',
      'Denver, CO', 'Austin, TX', 'Chicago, IL', 'New York, NY', 'Boston, MA'
    ];
    return locations[random.nextInt(locations.length)];
  }

  String _generatePaymentMethod(math.Random random) {
    final methods = ['Credit Card', 'Debit Card', 'Cash', 'Mobile Payment'];
    return methods[random.nextInt(methods.length)];
  }

  void _showSaveDialog() {
    if (_extractedData == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.save_alt, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('Save Scanned Receipt?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Merchant: ${_extractedData!.merchantName}'),
            Text('Amount: \$${_extractedData!.totalAmount.toStringAsFixed(2)}'),
            Text('Category: ${_extractedData!.category}'),
            Text('Items: ${_extractedData!.items.length}'),
            Text('Confidence: ${(_extractedData!.confidence * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            Text(
              'This will appear in your transactions and update all spending analytics.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveTransaction();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Save Receipt', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (_extractedData == null) return;

    try {
      // Create enhanced transaction from receipt data
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
        // Add receipt-specific metadata
        merchantMetadata: {
          'receipt_scanned': true,
          'items': _extractedData!.items.map((item) => {
            'name': item.name,
            'price': item.price,
            'quantity': item.quantity,
          }).toList(),
          'tax_amount': _extractedData!.taxAmount,
          'scan_confidence': _extractedData!.confidence,
        },
      );

      await _dataService.appendTransaction(transaction);

      // Clear cache to refresh data
      DataService.clearCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Receipt saved! Check your transactions tab.'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pop(context); // Close scanner
              },
            ),
          ),
        );

        // Reset for next scan
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
      backgroundColor: const Color(0xFF2B3A55), // Updated background color
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
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
                      color: const Color(0xFFE5BA73).withOpacity(0.2), // Accent color
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFE5BA73), // Accent color
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: Container(
                width: double.infinity,
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

  Widget _buildMainContent() {
    if (_isProcessing) {
      return _buildProcessingView();
    } else if (_isSuccess && _extractedData != null) {
      return _buildSuccessView();
    } else if (_scannedImage != null) {
      return _buildImagePreview();
    } else {
      return _buildScanOptions();
    }
  }

  Widget _buildScanOptions() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // AR Scanner mockup
            Container(
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
                  // AR viewfinder animation
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
                      const SizedBox(height: 8),
                      Text(
                        'AI will automatically detect and extract data',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
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
            ),

            const SizedBox(height: 24),

            // Features list
            _buildFeaturesList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
        _buildFeatureItem(
          icon: Icons.store,
          title: 'Merchant Recognition',
          description: 'Identifies merchants and locations',
        ),
        _buildFeatureItem(
          icon: Icons.receipt,
          title: 'Item-Level Details',
          description: 'Extracts individual items and prices',
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

  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: FileImage(_scannedImage!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Processing receipt...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2B3A55),
            ),
          ),
          const SizedBox(height: 20),
          const CircularProgressIndicator(color: Color(0xFF2B3A55)),
        ],
      ),
    );
  }

  Widget _buildProcessingView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_scannedImage != null) ...[
            Container(
              height: 200,
              width: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: FileImage(_scannedImage!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],

          // Processing animation
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, child) {
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      const Color(0xFFE5BA73).withOpacity(0.2),
                      const Color(0xFFE5BA73),
                      const Color(0xFF2B3A55),
                      const Color(0xFFE5BA73).withOpacity(0.2),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                    transform: GradientRotation(_scanAnimation.value * 2 * math.pi),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF2B3A55),
                    size: 40,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          const Text(
            'AI is analyzing your receipt...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2B3A55),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Extracting merchant, items, and amounts',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),

          const SizedBox(height: 32),

          // Processing steps
          _buildProcessingSteps(),
        ],
      ),
    );
  }

  Widget _buildProcessingSteps() {
    return Column(
      children: [
        _buildProcessingStep('Scanning receipt...', true),
        _buildProcessingStep('Extracting text...', true),
        _buildProcessingStep('Identifying merchant...', false),
        _buildProcessingStep('Categorizing expense...', false),
      ],
    );
  }

  Widget _buildProcessingStep(String step, bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            step,
            style: TextStyle(
              fontSize: 14,
              color: completed ? Colors.green : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Success animation
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
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          const Text(
            'Receipt Processed Successfully!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B3A55),
            ),
          ),

          const SizedBox(height: 32),

          // Extracted data
          Expanded(child: _buildExtractedDataCard()),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await _saveTransaction();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Receipt',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _scannedImage = null;
                      _extractedData = null;
                      _isSuccess = false;
                    });
                    _successAnimationController.reset();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Scan Another',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
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

  Widget _buildExtractedDataCard() {
    if (_extractedData == null) return const SizedBox();

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Extracted Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3A55),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(_extractedData!.confidence * 100).toStringAsFixed(1)}% confidence',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDataRow('Merchant', _extractedData!.merchantName),
            _buildDataRow('Amount', '\$${_extractedData!.totalAmount.toStringAsFixed(2)}'),
            _buildDataRow('Category', _extractedData!.category),
            _buildDataRow('Date', DateFormat('MMM d,specialmeal h:mm a').format(_extractedData!.date)),
            if (_extractedData!.location != null)
              _buildDataRow('Location', _extractedData!.location!),
            if (_extractedData!.paymentMethod != null)
              _buildDataRow('Payment', _extractedData!.paymentMethod!),
            if (_extractedData!.taxAmount > 0)
              _buildDataRow('Tax', '\$${_extractedData!.taxAmount.toStringAsFixed(2)}'),

            if (_extractedData!.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Items:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2B3A55),
                ),
              ),
              const SizedBox(height: 8),
              ..._extractedData!.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.quantity}x ${item.name}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Text(
                      '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B3A55),
              ),
              textAlign: TextAlign.right,
            ),
          ),
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
      height: size.height * 0.8,
    );

    // Draw corner brackets
    const cornerLength = 30.0;

    // Top-left
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(0, cornerLength),
      paint,
    );

    // Top-right
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(-cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(0, cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(0, -cornerLength),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(-cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(0, -cornerLength),
      paint,
    );

    // Scanning line
    final scanY = rect.top + (rect.height * animationValue);
    final scanPaint = Paint()
      ..color = const Color(0xFFE5BA73)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(rect.left, scanY),
      Offset(rect.right, scanY),
      scanPaint,
    );
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

  ReceiptItem({
    required this.name,
    required this.price,
    required this.quantity,
  });
}