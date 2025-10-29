import 'package:flutter/material.dart';

class FAQScreen extends StatefulWidget {
  final String? category;
  final String? searchQuery;

  const FAQScreen({Key? key, this.category, this.searchQuery}) : super(key: key);

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final Map<String, List<Map<String, String>>> _faqData = {
    'orders': [
      {
        'question': 'How do I track my order?',
        'answer': 'You can track your order by going to "My Orders" in the Account tab. Click on the order you want to track, and you\'ll see the current status and estimated delivery time.'
      },
      {
        'question': 'What should I do if my order is delayed?',
        'answer': 'If your order is delayed beyond the estimated delivery time, please contact our support team through Live Chat or submit a ticket. We\'ll investigate and provide you with an update.'
      },
      {
        'question': 'Can I cancel my order?',
        'answer': 'You can cancel your order before the seller confirms it. Go to "My Orders", select the order, and click "Cancel Order". If the order has been confirmed, please contact the seller or our support team.'
      },
      {
        'question': 'How do I return or exchange a product?',
        'answer': 'To return or exchange a product, go to "My Orders", select the order, and click "Request Return/Exchange". Fill in the reason and our team will process your request within 24 hours.'
      },
    ],
    'payment': [
      {
        'question': 'What payment methods do you accept?',
        'answer': 'We currently accept GCash for all transactions. More payment methods will be added soon.'
      },
      {
        'question': 'When will I receive my refund?',
        'answer': 'Refunds are processed within 3-5 business days after approval. The amount will be credited back to your original payment method (GCash account).'
      },
      {
        'question': 'Is my payment information secure?',
        'answer': 'Yes, all payment transactions are encrypted and processed securely through GCash\'s official payment gateway. We never store your complete payment information.'
      },
      {
        'question': 'Why was my payment declined?',
        'answer': 'Payment can be declined due to insufficient funds, incorrect payment details, or network issues. Please check your GCash account and try again. If the problem persists, contact GCash support.'
      },
    ],
    'seller': [
      {
        'question': 'How do I become a seller?',
        'answer': 'Go to the Account tab and click "Become a Seller". Fill in the registration form with your personal information, address, and upload a valid government-issued ID. Our admin team will review your application within 1-3 business days.'
      },
      {
        'question': 'What documents do I need to register as a seller?',
        'answer': 'You need a valid government-issued ID (National ID, Driver\'s License, Passport, or Voter\'s ID), complete address information, contact number, and an active GCash account for receiving payments.'
      },
      {
        'question': 'How long does seller approval take?',
        'answer': 'Seller approval typically takes 1-3 business days. You\'ll receive a notification once your application is approved or if additional information is needed.'
      },
      {
        'question': 'How do I add products to sell?',
        'answer': 'Once approved as a seller, go to the Seller Dashboard and click "Add Product". Fill in the product details including name, description, price, category, and upload clear photos of your product.'
      },
      {
        'question': 'How do I receive payments?',
        'answer': 'Payments are automatically transferred to your registered GCash account after the buyer confirms delivery. For cooperative delivery, payment is released after the cooperative confirms pickup.'
      },
      {
        'question': 'Can I edit my product listings?',
        'answer': 'Yes, you can edit your products anytime from the Seller Dashboard. Go to "My Products", select the product you want to edit, and update the information.'
      },
    ],
    'account': [
      {
        'question': 'How do I reset my password?',
        'answer': 'On the login screen, click "Forgot Password". Enter your registered email address, and we\'ll send you a password reset link. Follow the instructions in the email to create a new password.'
      },
      {
        'question': 'Can I change my email address?',
        'answer': 'Currently, email addresses cannot be changed for security reasons. If you need to update your email, please contact our support team with your account details.'
      },
      {
        'question': 'How do I update my profile information?',
        'answer': 'Go to Account tab, click "Profile Settings", and update your name or other information. Note that email addresses cannot be changed directly.'
      },
      {
        'question': 'Is my personal information safe?',
        'answer': 'Yes, we take data security seriously. All personal information is encrypted and stored securely. We never share your information with third parties without your consent.'
      },
      {
        'question': 'How do I delete my account?',
        'answer': 'To delete your account, please contact our support team through Live Chat or submit a ticket. Note that this action is permanent and cannot be undone.'
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _selectedCategory = widget.category!;
    }
    if (widget.searchQuery != null) {
      _searchQuery = widget.searchQuery!;
      _searchController.text = widget.searchQuery!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _getFilteredFAQs() {
    List<Map<String, String>> allFaqs = [];
    
    if (_selectedCategory == 'all') {
      _faqData.values.forEach((faqs) => allFaqs.addAll(faqs));
    } else {
      allFaqs = _faqData[_selectedCategory] ?? [];
    }

    if (_searchQuery.isNotEmpty) {
      allFaqs = allFaqs.where((faq) {
        return faq['question']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               faq['answer']!.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return allFaqs;
  }

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _getFilteredFAQs();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Frequently Asked Questions'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search FAQs...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Category tabs
          Container(
            height: 50,
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip('All', 'all'),
                _buildCategoryChip('Orders', 'orders'),
                _buildCategoryChip('Payment', 'payment'),
                _buildCategoryChip('Seller', 'seller'),
                _buildCategoryChip('Account', 'account'),
              ],
            ),
          ),

          const Divider(height: 1),

          // FAQ list
          Expanded(
            child: filteredFaqs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No FAQs found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or category',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredFaqs.length,
                    itemBuilder: (context, index) {
                      return _buildFAQItem(
                        filteredFaqs[index]['question']!,
                        filteredFaqs[index]['answer']!,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
          });
        },
        selectedColor: Colors.green,
        backgroundColor: Colors.grey.shade200,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
