import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_navbar.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/loading_screen.dart';

class EditMenuScreen extends StatefulWidget {
  const EditMenuScreen({super.key});

  @override
  State<EditMenuScreen> createState() => _EditMenuScreenState();
}

class _EditMenuScreenState extends State<EditMenuScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _menu = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final List<String> _categories = ['Beverages', 'Desserts', 'Main Course', 'Appetizers', 'Snacks'];
  Map<String, dynamic>? _restaurantData;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchRestaurantData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchRestaurantData() async {
    try {
      setState(() => _isLoading = true);
      final data = await _apiService.getRestaurantByOwnerId();
      
      if (mounted) {
        setState(() {
          _restaurantData = data;
          _menu = List<Map<String, dynamic>>.from(data['menu'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching restaurant data: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load menu data';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveMenu() async {
    try {
      setState(() => _isLoading = true);
      await _apiService.updateMenu(_restaurantData!['_id'], _menu);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving menu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update menu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addMenuItem() {
    setState(() {
      _menu.add({
        'itemName': '',
        'description': '',
        'imageUrl': '',
        'category': _categories[0],
        'sizes': {},
        'isAvailable': true,
      });
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _removeMenuItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: const Text('Are you sure you want to remove this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _menu.removeAt(index));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _addSize(int itemIndex) {
    showDialog(
      context: context,
      builder: (context) {
        String size = '';
        String price = '';
        
        return AlertDialog(
          title: const Text('Add Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Size (e.g., Small)'),
                onChanged: (value) => size = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                onChanged: (value) => price = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (size.isNotEmpty && price.isNotEmpty) {
                  setState(() {
                    final sizes = Map<String, dynamic>.from(_menu[itemIndex]['sizes']);
                    sizes[size] = double.parse(price);
                    _menu[itemIndex]['sizes'] = sizes;
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search menu items...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _menu.length,
              itemBuilder: (context, index) => _buildMenuItem(index),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMenuItem,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMenuItem(int index) {
    final item = _menu[index];
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Item Name'),
              controller: TextEditingController(text: item['itemName']),
              onChanged: (value) => setState(() => item['itemName'] = value),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
              controller: TextEditingController(text: item['description']),
              onChanged: (value) => setState(() => item['description'] = value),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Image URL'),
              controller: TextEditingController(text: item['imageUrl']),
              onChanged: (value) => setState(() => item['imageUrl'] = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: item['category'] ?? _categories[0],
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) => setState(() => item['category'] = value),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sizes and Prices:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Size'),
                  onPressed: () => _addSize(index),
                ),
              ],
            ),
            if (item['sizes'] != null) ...[
              ...Map<String, dynamic>.from(item['sizes']).entries.map((entry) {
                return ListTile(
                  title: Text(entry.key),
                  subtitle: Text('₹${entry.value}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        final sizes = Map<String, dynamic>.from(item['sizes']);
                        sizes.remove(entry.key);
                        item['sizes'] = sizes;
                      });
                    },
                  ),
                );
              }).toList(),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Switch(
                  value: item['isAvailable'] ?? true,
                  onChanged: (value) => setState(() => item['isAvailable'] = value),
                ),
                Text(item['isAvailable'] ?? true ? 'Available' : 'Unavailable'),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeMenuItem(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 