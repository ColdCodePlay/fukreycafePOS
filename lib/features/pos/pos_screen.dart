

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/menu_item_model.dart';
import '../../repositories/menu_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/coupon_repository.dart';
import '../../repositories/sales_repository.dart';
import '../../services/printer_service.dart';
import '../../core/navigator_key.dart';
import 'cart_provider.dart';
import 'printer_settings_dialog.dart';
import '../auth/auth_provider.dart';

// Printer service is now a NotifierProvider defined in printer_service.dart

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isValidatingCoupon = false;
  String? _selectedCategoryId;
  String _searchQuery = '';

  @override
  void dispose() {
    _couponController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return userProfileAsync.when(
      data: (profile) {
        if (profile == null) {
          if (context.mounted) context.go('/');
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (profile.role == 'staff' && profile.outletId == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Access Denied')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.warning, size: 64, color: Colors.orange),
                   const SizedBox(height: 16),
                   const Text('No Outlet Assigned!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                   const Padding(
                     padding: EdgeInsets.all(16.0),
                     child: Text('Please ask your Admin to link you to an outlet in the Admin Dashboard.', textAlign: TextAlign.center),
                   ),
                   ElevatedButton(
                     onPressed: () => ref.read(authControllerProvider.notifier).logout(), 
                     child: const Text('Logout')
                   )
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFDEFE6), 
          appBar: AppBar(
            title: const Text('FUKREY CAFE POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: const Color(0xFFE38242),
            foregroundColor: Colors.white,
            elevation: 2,
            actions: [
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: () => showDialog(context: context, builder: (context) => const PrinterSettingsDialog()),
              ),
              IconButton(icon: const Icon(Icons.history), onPressed: () => _showHistoryDialog(context)),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 900;
              
              if (isMobile) {
                return Column(
                  children: [
                    Expanded(child: _buildMenuGrid(menuItemsAsync, categoriesAsync)),
                    const _MobileCartSummary(),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 2, child: _buildMenuGrid(menuItemsAsync, categoriesAsync)),
                  const Expanded(flex: 1, child: _CartSidebar()),
                ],
              );
            },
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildMenuGrid(AsyncValue<List<MenuItem>> itemsAsync, AsyncValue<List<dynamic>> catsAsync) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search, color: Colors.orange, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              ),
              const SizedBox(height: 8),
              catsAsync.when(
                data: (categories) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CategoryChip(
                        label: 'All',
                        isSelected: _selectedCategoryId == null,
                        onSelected: () => setState(() => _selectedCategoryId = null),
                      ),
                      ...categories.map((cat) => _CategoryChip(
                        label: cat['name'],
                        isSelected: _selectedCategoryId == cat['id'],
                        onSelected: () => setState(() => _selectedCategoryId = cat['id']),
                      )),
                    ],
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              final filtered = items.where((i) {
                final matchesCategory = _selectedCategoryId == null || i.categoryId == _selectedCategoryId;
                final matchesSearch = i.name.toLowerCase().contains(_searchQuery);
                return matchesCategory && matchesSearch;
              }).toList();
              
              if (filtered.isEmpty) return const Center(child: Text('No items found.'));

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  childAspectRatio: 0.75, // Increased height for mobile content
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) => _MenuItemCard(
                  item: filtered[index],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Future<void> _showHistoryDialog(BuildContext context) async {
    final recentOrdersAsync = ref.read(recentOrdersProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recent Orders'),
        content: SizedBox(
          width: double.maxFinite,
          child: recentOrdersAsync.when(
            data: (orders) => orders.isEmpty
                ? const Center(child: Text('No orders'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final o = orders[index];
                      return ListTile(
                        title: Text('Order #${o['id'].toString().substring(0, 8)}'),
                        subtitle: Text('₹${o['total_amount']} | ${o['created_at'].toString().substring(11, 16)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.print_outlined),
                          onPressed: () {
                            // Prepare data for PrinterService
                            final orderData = {
                              'id': o['id'],
                              'total': o['total_amount'],
                              'discount_amount': o['discount_amount'] ?? 0,
                              'tax_amount': o['tax_amount'] ?? 0,
                              'items': (o['order_items'] as List? ?? []).map((oi) => {
                                'name': oi['menu_items']?['name'] ?? 'Unknown',
                                'quantity': oi['quantity'],
                                'price': oi['price'],
                              }).toList(),
                            };
                            ref.read(printerServiceProvider.notifier).printBill(orderData);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent to printer')));
                          },
                        ),
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error: $e'),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

class _CartSidebar extends ConsumerWidget {
  const _CartSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey[200]!)),
      ),
      child: const Column(
        children: [
          Expanded(flex: 3, child: _CartItemsList()),
          Divider(height: 1),
          Flexible(flex: 2, child: _CartFooter()),
        ],
      ),
    );
  }
}

class _MobileCartSummary extends ConsumerWidget {
  const _MobileCartSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    if (cartState.items.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${cartState.items.length} Items', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Total: ₹${cartState.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, color: Color(0xFFE38242), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _showMobileCartDetails(context),
            child: const Text('VIEW CART'),
          ),
        ],
      ),
    );
  }
}

void _showMobileCartDetails(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Container(height: 5, width: 40, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(5))),
          const Expanded(child: _CartItemsList()),
          const _CartFooter(),
        ],
      ),
    ),
  );
}


class _CartItemsList extends ConsumerWidget {
  const _CartItemsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    return ListView.builder(
      itemCount: cartState.items.length,
      itemBuilder: (context, index) {
        final item = cartState.items[index];
        return ListTile(
          dense: true,
          title: Text(item.menuItem.name, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('₹${item.menuItem.price} x ${item.quantity}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: () => ref.read(cartProvider.notifier).decrementItem(item.menuItem.id)),
              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.orange), onPressed: () => ref.read(cartProvider.notifier).addItem(item.menuItem)),
            ],
          ),
        );
      },
    );
  }
}

class _CartFooter extends ConsumerStatefulWidget {
  const _CartFooter();

  @override
  ConsumerState<_CartFooter> createState() => _CartFooterState();
}

class _CartFooterState extends ConsumerState<_CartFooter> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  bool _isValidatingCoupon = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.grey[50],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Customer Name (Optional)', prefixIcon: Icon(Icons.person, size: 20), isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Phone Number (Optional)', prefixIcon: Icon(Icons.phone, size: 20), isDense: true),
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _couponController,
              decoration: InputDecoration(
                hintText: cartState.appliedCoupon != null ? 'Promo: ${cartState.appliedCoupon!.code}' : 'Coupon Code',
                suffixIcon: _isValidatingCoupon 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      icon: Icon(cartState.appliedCoupon != null ? Icons.close : Icons.check, size: 18),
                      onPressed: () => _handleCouponAction(cartState),
                    ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Tax (5%)', style: TextStyle(fontSize: 14)),
              value: cartState.taxRate > 0,
              onChanged: (val) {
                ref.read(cartProvider.notifier).setTaxRate(val ? 0.05 : 0.0);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: Colors.orange,
              activeTrackColor: Colors.orange.withValues(alpha: 0.5),
            ),
            const Divider(),
            _TotalRow(label: 'Subtotal', value: '₹${cartState.subtotal.toStringAsFixed(2)}'),
            if (cartState.discountAmount > 0)
              _TotalRow(label: 'Discount', value: '-₹${cartState.discountAmount.toStringAsFixed(2)}', isDiscount: true),
            if (cartState.taxAmount > 0)
              _TotalRow(label: 'Tax (5%)', value: '₹${cartState.taxAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _TotalRow(label: 'Total', value: '₹${cartState.total.toStringAsFixed(2)}', isBold: true),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: cartState.items.isEmpty ? null : () => _showInvoicePreview(context, ref, cartState, _nameController.text, _phoneController.text),
                child: const Text('PROCEED TO CHECKOUT', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _handleCouponAction(CartState cartState) async {
    if (cartState.appliedCoupon != null) {
      ref.read(cartProvider.notifier).removeCoupon();
      _couponController.clear();
      return;
    }
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    
    setState(() => _isValidatingCoupon = true);
    try {
      final coupon = await ref.read(couponRepositoryProvider).getCouponByCode(code);
      if (coupon != null) {
        ref.read(cartProvider.notifier).applyCoupon(coupon);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Coupon'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Coupon Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isValidatingCoupon = false);
    }
  }
}

void _showInvoicePreview(BuildContext context, WidgetRef ref, CartState cart, String custName, String custPhone) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Order Details'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('FUKREY CAFE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (custName.isNotEmpty) Text('Guest: $custName'),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text('${item.menuItem.name} x${item.quantity}')),
                          Text('₹${item.total.toStringAsFixed(2)}'),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              _TotalRow(label: 'Subtotal', value: '₹${cart.subtotal.toStringAsFixed(2)}'),
              if (cart.discountAmount > 0)
                _TotalRow(label: 'Discount', value: '-₹${cart.discountAmount.toStringAsFixed(2)}', isDiscount: true),
              if (cart.taxAmount > 0)
                _TotalRow(label: 'Tax (5%)', value: '₹${cart.taxAmount.toStringAsFixed(2)}'),
              const Divider(),
              _TotalRow(label: 'GRAND TOTAL', value: '₹${cart.total.toStringAsFixed(2)}', isBold: true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('BACK')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          onPressed: () {
            Navigator.pop(dialogContext);
            _handleCheckout(context, ref, cart, custName, custPhone);
          },
          child: const Text('CONFIRM'),
        ),
      ],
    ),
  );
}

Future<void> _handleCheckout(BuildContext context, WidgetRef ref, CartState cartState, String custName, String custPhone) async {
  final profile = ref.read(userProfileProvider).value;
  if (profile == null || profile.outletId == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: No outlet assigned to your profile.')));
    }
    return;
  }

  String? orderId;
  Map<String, dynamic>? finalOrderData;
  bool loaderShown = false;

  try {
    print('DEBUG: [_handleCheckout] Showing loader...');
    // Show loader on the global navigator key context to ensure it's reachable for dismissal
    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) {
        return const Center(child: CircularProgressIndicator());
      },
    );
    loaderShown = true;

    final orderData = {
      'outlet_id': profile.outletId!,
      'items': cartState.items.map((i) => {
        'id': i.menuItem.id,
        'name': i.menuItem.name,
        'quantity': i.quantity,
        'price': i.menuItem.price
      }).toList(),
      'total': cartState.total,
      'discount_amount': cartState.discountAmount,
      'tax_amount': cartState.taxAmount,
      'coupon_code': cartState.appliedCoupon?.code,
      'customer_name': custName.isEmpty ? null : custName,
      'customer_phone': custPhone.isEmpty ? null : custPhone,
    };

    print('DEBUG: [_handleCheckout] Calling createOrder...');
    orderId = await ref.read(orderRepositoryProvider).createOrder(orderData);
    print('DEBUG: [_handleCheckout] orderId returned: $orderId');

    if (orderId != null) {
      finalOrderData = {
        'id': orderId,
        'items': cartState.items.map((i) => {
          'name': i.menuItem.name,
          'quantity': i.quantity,
          'price': i.menuItem.price
        }).toList(),
        'total': cartState.total,
        'discount_amount': cartState.discountAmount,
        'tax_amount': cartState.taxAmount,
      };
      
      // Refresh admin stats & orders
      ref.invalidate(dailySalesProvider);
      ref.invalidate(recentOrdersProvider);
      ref.invalidate(filteredSalesProvider);
      print('DEBUG: [_handleCheckout] Stats invalidated.');
    }
  } catch (e) {
    print('DEBUG: [_handleCheckout] EXCEPTION: $e');
    if (navigatorKey.currentContext != null) { 
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(content: Text('Checkout Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5))
      ); 
    }
  } finally {
    // ALWAYS close loader using the global navigator key
    if (loaderShown && navigatorKey.currentState != null) {
      print('DEBUG: [_handleCheckout] Popping loader...');
      navigatorKey.currentState!.pop();
      loaderShown = false;
    }
  }

  // Show Success/Failure results AFTER the loader is gone
  if (orderId != null && finalOrderData != null) {
    print('DEBUG: [_handleCheckout] Showing Success Dialog...');
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('Order Successful'),
            ],
          ),
          content: Text('Order #$orderId has been created successfully.'),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Print Invoice'),
              onPressed: () {
                print('DEBUG: [SuccessDialog] Print Invoice pressed.');
                ref.read(printerServiceProvider.notifier).printBill(finalOrderData!);
              },
            ),
            ElevatedButton(
              onPressed: () {
                print('DEBUG: [SuccessDialog] New Order pressed.');
                ref.read(cartProvider.notifier).clearCart();
                Navigator.pop(context);
              },
              child: const Text('New Order'),
            ),
          ],
        ),
      );
    }
  } else if (orderId == null) {
    print('DEBUG: [_handleCheckout] orderId is NULL, showing failure.');
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(content: Text('Failed to create order. Please try again.'), backgroundColor: Colors.orange)
      );
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _CategoryChip({required this.label, required this.isSelected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) => onSelected(),
        selectedColor: Colors.orange,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      ),
    );
  }
}

class _MenuItemCard extends ConsumerWidget {
  final MenuItem item;

  const _MenuItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only the quantity for this specific item in the cart
    final quantity = ref.watch(cartProvider.select((state) {
      final cartItem = state.items.cast<CartItem?>().firstWhere(
        (i) => i?.menuItem.id == item.id,
        orElse: () => null,
      );
      return cartItem?.quantity ?? 0;
    }));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: quantity == 0 ? () => ref.read(cartProvider.notifier).addItem(item) : null,
        child: Column(
          children: [
            Expanded(
              flex: 5, // Take most space for icon
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE38242).withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                    child: const Icon(Icons.fastfood, size: 30, color: Color(0xFFE38242)),
                  ),
                  if (quantity > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE38242),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Only take needed space at bottom
                children: [
                  Text(
                    item.name, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), 
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (quantity == 0)
                    Text(
                      '₹${item.price.toStringAsFixed(0)}', 
                      style: const TextStyle(color: Color(0xFFE38242), fontWeight: FontWeight.bold, fontSize: 14),
                    )
                  else
                    FittedBox( // Prevent horizontal overflow of the quantity row
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(width: 8),
                          Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE38242),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                                    onTap: () => ref.read(cartProvider.notifier).decrementItem(item.id),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Icon(Icons.remove, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Text(
                                  '$quantity',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                                    onTap: () => ref.read(cartProvider.notifier).addItem(item),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Icon(Icons.add, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isDiscount;

  const _TotalRow({required this.label, required this.value, this.isBold = false, this.isDiscount = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis)),
          Text(value, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isDiscount ? Colors.red : Colors.black,
            fontSize: isBold ? 18 : 14,
          )),
        ],
      ),
    );
  }
}

