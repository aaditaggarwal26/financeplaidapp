import 'package:flutter/material.dart';

class HelpQAScreen extends StatefulWidget {
  const HelpQAScreen({Key? key}) : super(key: key);

  @override
  State<HelpQAScreen> createState() => _HelpQAScreenState();
}

class _HelpQAScreenState extends State<HelpQAScreen> with SingleTickerProviderStateMixin {
  static const Color primaryColor = Color(0xFF2B3A55);
  static const Color accentColor = Color(0xFFE5BA73);
  static const Color backgroundColor = Color(0xFFF8F9FA);

  // Initialize the controller in the declaration to avoid late initialization errors
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = "";

  final List<Map<String, String>> _questionsAndAnswers = [
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

  final List<Map<String, String>> _contactInfo = [
    {
      'title': 'Email Support',
      'content': 'contactfinsight@gmail.com',
      'icon': 'email'
    },
    {
      'title': 'Phone Support',
      'content': '+1 (555) 123-4567',
      'icon': 'phone'
    },
    {
      'title': 'Live Chat',
      'content': 'Available 24/7',
      'icon': 'chat'
    },
  ];

  final Map<String, bool> _expandedQuestions = {};

  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: 2, vsync: this);
    
    for (var qna in _questionsAndAnswers) {
      _expandedQuestions[qna['question']!] = false;
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filteredQuestions {
    if (_searchQuery.isEmpty) {
      return _questionsAndAnswers;
    }
    
    return _questionsAndAnswers.where((qna) {
      return qna['question']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          qna['answer']!.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // Method to toggle search mode
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = "";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ensure the TabController is initialized before using it
    if (_tabController == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Search for help...",
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  autofocus: true,
                )
              : const Text(
                  'Help & Q&A',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
          centerTitle: true,
          backgroundColor: primaryColor,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: Colors.white,
              ),
              onPressed: _toggleSearch,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: accentColor,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            tabs: const [
              Tab(
                icon: Icon(Icons.question_answer),
                text: "FAQs",
              ),
              Tab(
                icon: Icon(Icons.support_agent),
                text: "Contact",
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              // FAQs Tab
              _buildFAQsTab(),
              
              // Contact Tab
              _buildContactTab(),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: accentColor,
          onPressed: () {
            // Show a snackbar when FAB is pressed
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Starting live chat...'),
                backgroundColor: primaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                action: SnackBarAction(
                  label: 'CANCEL',
                  textColor: accentColor,
                  onPressed: () {},
                ),
              ),
            );
          },
          child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        ),
      ),
    );
  }

  // FAQs Tab Content
  Widget _buildFAQsTab() {
    return Column(
      children: [
        // Header with illustration
        if (_searchQuery.isEmpty) _buildHeader(),
        
        // FAQ list
        Expanded(
          child: _filteredQuestions.isEmpty
              ? _buildNoResultsFound()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredQuestions.length,
                  itemBuilder: (context, index) {
                    final qna = _filteredQuestions[index];
                    final isExpanded = _expandedQuestions[qna['question']] ?? false;
                    
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Material(
                          color: Colors.transparent,
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              key: Key(qna['question'] ?? ''), // Add key for proper state management
                              initiallyExpanded: false,
                              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              expandedCrossAxisAlignment: CrossAxisAlignment.start,
                              title: Text(
                                qna['question'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: isExpanded ? accentColor : primaryColor,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isExpanded 
                                    ? accentColor.withOpacity(0.1)
                                    : primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: isExpanded ? accentColor : primaryColor,
                                ),
                              ),
                              onExpansionChanged: (expanded) {
                                setState(() {
                                  _expandedQuestions[qna['question']!] = expanded;
                                });
                              },
                              children: [
                                Divider(
                                  color: accentColor.withOpacity(0.3),
                                  thickness: 1,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 20,
                                    right: 20,
                                    top: 8,
                                    bottom: 20,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        qna['answer'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          _buildReactionButton(Icons.thumb_up_outlined, "Helpful"),
                                          const SizedBox(width: 8),
                                          _buildReactionButton(Icons.thumb_down_outlined, "Not helpful"),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Contact Tab Content
  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Contact Info Cards
          ...List.generate(_contactInfo.length, (index) {
            final info = _contactInfo[index];
            IconData icon;
            
            switch (info['icon']) {
              case 'email':
                icon = Icons.email_outlined;
                break;
              case 'phone':
                icon = Icons.phone_outlined;
                break;
              default:
                icon = Icons.chat_outlined;
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                title: Text(
                  info['title'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    info['content'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: primaryColor.withOpacity(0.5),
                  size: 16,
                ),
                onTap: () {
                  // Show contact action feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Contacting via ${info['title']}...Please wait until a representative is available'),
                      backgroundColor: primaryColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
          
          const SizedBox(height: 24),
          
          // Section header
          Row(
            children: [
              Icon(
                Icons.rate_review_outlined,
                color: accentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Leave Feedback',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Feedback Form with error handling
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Added animation effect
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.8, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        filled: true,
                        fillColor: Color(0xFFF2F3F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Your email',
                      filled: true,
                      fillColor: Color(0xFFF2F3F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Your message',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: Color(0xFFF2F3F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.all(16),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your message';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Animated button
                  SizedBox(
                    width: double.infinity,
                    child: TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.9, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          // Form validation and submission
                          final form = Form.of(context);
                          if (form != null && form.validate()) {
                            // Show submit feedback confirmation
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Thank you for your feedback!'),
                                backgroundColor: primaryColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                action: SnackBarAction(
                                  label: 'DISMISS',
                                  textColor: Colors.white,
                                  onPressed: () {},
                                ),
                              ),
                            );
                          }
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'SUBMIT',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // FAQ quick links
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Help',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickHelpChip('Password Reset'),
                    _buildQuickHelpChip('Payment Issues'),
                    _buildQuickHelpChip('Account Settings'),
                    _buildQuickHelpChip('App Tutorial'),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find Answers',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Browse through our frequently asked questions',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.question_answer_rounded,
              size: 40,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionButton(IconData icon, String label) {
    return OutlinedButton.icon(
      icon: Icon(
        icon,
        size: 16,
        color: primaryColor,
      ),
      label: Text(
        label,
        style: const TextStyle(
          color: primaryColor,
          fontSize: 12,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: primaryColor.withOpacity(0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () {
        // Show reaction feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You marked this as $label'),
            duration: const Duration(seconds: 1),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildQuickHelpChip(String label) {
    return InkWell(
      onTap: () {
        // Switch to FAQs tab and set search query
        _tabController?.animateTo(0);
        setState(() {
          _isSearching = true;
          _searchQuery = label.toLowerCase();
          _searchController.text = label;
        });
      },
      child: Chip(
        backgroundColor: Colors.white,
        side: BorderSide(color: accentColor.withOpacity(0.3)),
        label: Text(label),
        avatar: Icon(
          Icons.help_outline,
          size: 18,
          color: accentColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}