import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import '../../repositories/sales_repository.dart';
import '../../repositories/menu_repository.dart';
import '../../repositories/user_repository.dart';
import '../auth/auth_provider.dart';
import '../../core/file_utils.dart';
import 'dart:io' show File;

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      data: (profile) {
        if (profile == null || profile.role != 'admin') {
          // If not admin, kick back to / (Dispatcher)
          Future.microtask(() => { if (context.mounted) context.go('/') });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Initialize outlet filter if user is an outlet manager
        if (profile.outletId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(outletFilterProvider.notifier).setFilter(profile.outletId);
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('ADMIN CONSOLE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            backgroundColor: const Color(0xFFE38242),
            foregroundColor: Colors.white,
            elevation: 4,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 4,
              labelColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
                Tab(icon: Icon(Icons.store), text: 'Outlets'),
                Tab(icon: Icon(Icons.people), text: 'Users'),
                Tab(icon: Icon(Icons.category), text: 'Categories'),
                Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: const [
              _OverviewTab(),
              _OutletsTab(),
              _UsersTab(),
              _CategoriesTab(),
              _MenuTab(),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}


// -----------------------------------------------------------------------------
// OVERVIEW TAB
// -----------------------------------------------------------------------------

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pre-fetch outlets to avoid loading delay in picker
    ref.watch(outletsRepoProvider);
    
    final statsAsync = ref.watch(filteredSalesProvider);
    final userProfile = ref.watch(userProfileProvider).value;
    final isOutletManager = userProfile?.outletId != null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PerformanceHeader(isOutletManager: isOutletManager),
          const SizedBox(height: 24),
          
          statsAsync.when(
            data: (stats) => _StatGrid(stats: stats),
            loading: () => const _StatGridPlaceholder(),
            error: (e, st) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
              child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
            ),
          ),

          const SizedBox(height: 40),
          const Text('Recent Orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF2D3142))),
          const SizedBox(height: 16),
          const _RecentOrdersList(),
        ],
      ),
    );
  }
}

class _PerformanceHeader extends ConsumerWidget {
  final bool isOutletManager;
  const _PerformanceHeader({required this.isOutletManager});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(dateRangeProvider);
    final outletId = ref.watch(outletFilterProvider);
    final paymentMethod = ref.watch(paymentMethodFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Overview', 
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF2D3142))
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                icon: Icons.calendar_today,
                label: range.start.day == range.end.day ? 'Today' : '${range.start.day}/${range.start.month} - ${range.end.day}/${range.end.month}',
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    initialDateRange: range,
                  );
                  if (picked != null) {
                    ref.read(dateRangeProvider.notifier).setRange(DateTimeRange(
                      start: picked.start,
                      end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
                    ));
                  }
                },
              ),
              const SizedBox(width: 8),
              if (!isOutletManager)
                _FilterChip(
                  icon: Icons.store,
                  label: outletId == null ? 'All Outlets' : 'Specific Outlet',
                  onTap: () => _showOutletPicker(context, ref),
                ),
              const SizedBox(width: 8),
              _FilterChip(
                icon: Icons.payment,
                label: paymentMethod == null ? 'All Payments' : paymentMethod.toUpperCase(),
                onTap: () => _showPaymentPicker(context, ref),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                icon: Icons.download,
                label: 'Export CSV',
                onTap: () => _exportToCSV(context, ref),
              ),
            ],
          ),
        ),
        if (outletId != null || paymentMethod != null || range.start.day != range.end.day) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              if (range.start.day != range.end.day)
                _ActiveFilterHint(
                  label: 'Range: ${range.start.day}/${range.start.month} - ${range.end.day}/${range.end.month}',
                  onClear: () {
                    final now = DateTime.now();
                    ref.read(dateRangeProvider.notifier).setRange(DateTimeRange(
                      start: DateTime(now.year, now.month, now.day),
                      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
                    ));
                  },
                ),
              if (outletId != null)
                Consumer(builder: (context, ref, child) {
                  final outlets = ref.watch(outletsRepoProvider).value ?? [];
                  final outlet = outlets.firstWhere((o) => o['id'] == outletId, orElse: () => {'name': 'Specific'});
                  return _ActiveFilterHint(
                    label: 'Outlet: ${outlet['name']}',
                    onClear: () => ref.read(outletFilterProvider.notifier).setFilter(null),
                  );
                }),
              if (paymentMethod != null)
                _ActiveFilterHint(
                  label: 'Mode: ${paymentMethod.toUpperCase()}',
                  onClear: () => ref.read(paymentMethodFilterProvider.notifier).setFilter(null),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _showOutletPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final outletsAsync = ref.watch(outletsRepoProvider);
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6, minHeight: 200),
            child: outletsAsync.when(
              data: (outlets) => ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                   const ListTile(title: Text('Select Outlet', style: TextStyle(fontWeight: FontWeight.bold))),
                   ListTile(
                     title: const Text('All Outlets'),
                     onTap: () { ref.read(outletFilterProvider.notifier).setFilter(null); Navigator.pop(context); },
                   ),
                   ...outlets.map((o) => ListTile(
                     title: Text(o['name']),
                     onTap: () { ref.read(outletFilterProvider.notifier).setFilter(o['id']); Navigator.pop(context); },
                   )),
                ],
              ),
              loading: () => const SizedBox(
                height: 200, 
                child: Center(child: CircularProgressIndicator(color: Colors.orange))
              ),
              error: (e, st) => Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Error: $e'))),
            ),
          );
        },
      ),
    );
  }

  void _showPaymentPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          const ListTile(title: Text('Select Payment Mode', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            title: const Text('All Payments'),
            onTap: () { ref.read(paymentMethodFilterProvider.notifier).setFilter(null); Navigator.pop(context); },
          ),
          ...['Cash', 'Card', 'UPI'].map((m) => ListTile(
            title: Text(m),
            onTap: () { ref.read(paymentMethodFilterProvider.notifier).setFilter(m); Navigator.pop(context); },
          )),
        ],
      ),
    );
  }

  Future<void> _exportToCSV(BuildContext context, WidgetRef ref) async {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating CSV...')));
      }
      
      final orders = await ref.read(allFilteredOrdersProvider.future);
      if (orders.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No orders to export')));
        }
        return;
      }

      final List<List<dynamic>> rows = [];
      // Header
      rows.add([
        'Order ID',
        'Date',
        'Time',
        'Customer',
        'Payment Mode',
        'Items',
        'Total Amount',
        'Status'
      ]);

      for (var order in orders) {
        final time = DateTime.parse(order['created_at']).toLocal();
        final itemsList = order['order_items'] as List? ?? [];
        final itemsString = itemsList.map((i) => "${i['menu_items']?['name'] ?? 'Item'} (x${i['quantity']})").join(", ");
        
        rows.add([
          order['id'].toString().substring(0, 8),
          DateFormat('dd/MM/yyyy').format(time),
          DateFormat('HH:mm').format(time),
          order['customer_name'] ?? 'Guest',
          order['payment_method']?.toString().toUpperCase() ?? 'CASH',
          itemsString,
          order['total_amount'],
          order['status']
        ]);
      }

      final csvData = const ListToCsvConverter().convert(rows);
      final fileName = "orders_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv";

      await saveAndShareFile(csvData, fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported: $fileName')));
      }
    } catch (e) {
      debugPrint("Export error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}

class _ActiveFilterHint extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _ActiveFilterHint({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onClear,
      backgroundColor: Colors.grey[200],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FilterChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: Colors.orange),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onPressed: onTap,
      backgroundColor: Colors.orange.withValues(alpha: 0.05),
      side: const BorderSide(color: Colors.orange, width: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final SalesStats stats;
  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          return Column(
            children: [
              _StatCard(title: 'Revenue', value: '₹${stats.totalRevenue.toInt()}', icon: Icons.currency_rupee, color: Colors.green),
              const SizedBox(height: 12),
              Row(
                children: [
                   Expanded(child: _StatCard(title: 'Orders', value: stats.totalOrders.toString(), icon: Icons.receipt_long, color: Colors.blue)),
                   const SizedBox(width: 12),
                   Expanded(child: _StatCard(title: 'Avg. Order', value: '₹${stats.averageOrderValue.toInt()}', icon: Icons.analytics, color: Colors.orange)),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _StatCard(title: 'Total Revenue', value: '₹${stats.totalRevenue.toStringAsFixed(2)}', icon: Icons.currency_rupee, color: Colors.green)),
            const SizedBox(width: 16),
            Expanded(child: _StatCard(title: 'Total Orders', value: stats.totalOrders.toString(), icon: Icons.receipt_long, color: Colors.blue)),
            const SizedBox(width: 16),
            Expanded(child: _StatCard(title: 'Avg. Order', value: '₹${stats.averageOrderValue.toStringAsFixed(2)}', icon: Icons.analytics, color: Colors.orange)),
          ],
        );
      },
    );
  }
}

class _StatGridPlaceholder extends StatelessWidget {
  const _StatGridPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 100, 
      child: Center(child: LinearProgressIndicator(color: Colors.orange))
    );
  }
}

class _RecentOrdersList extends ConsumerWidget {
  const _RecentOrdersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(filteredOrdersProvider);

    return ordersAsync.when(
      data: (orders) => Column(
        children: [
          orders.isEmpty 
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No orders found matching filters')))
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _OrderCard(order: orders[index]),
              ),
          if (orders.isNotEmpty && ref.read(filteredOrdersProvider.notifier).hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: TextButton.icon(
                onPressed: () => ref.read(filteredOrdersProvider.notifier).loadMore(),
                icon: const Icon(Icons.refresh),
                label: const Text('Load More Orders'),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
              ),
            ),
        ],
      ),
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Colors.orange))),
      error: (e, st) => Text('Error: $e'),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final total = order['total_amount'] ?? 0;
    final time = DateTime.parse(order['created_at']).toLocal();
    final items = order['order_items'] as List? ?? [];
    final customerName = order['customer_name'] ?? 'Guest';
    final customerPhone = order['customer_phone'] ?? '';
    final paymentMethod = order['payment_method']?.toString().toUpperCase() ?? 'CASH';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${order['id'].toString().substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF2D3142))),
                    Text('${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} ${time.hour}:${time.minute.toString().padLeft(2, '0')} | $customerName', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    if (customerPhone.isNotEmpty) Text('📞 $customerPhone', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹$total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFE38242))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                      child: Text(paymentMethod, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            ...items.map((item) {
              final menuName = item['menu_items']?['name'] ?? 'Unknown Item';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item['quantity']}x $menuName', style: const TextStyle(fontSize: 15, color: Color(0xFF4F5D75))),
                    Text('₹${(item['price'] * item['quantity']).toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title, 
                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueGrey[900], letterSpacing: -0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// OUTLETS TAB
// -----------------------------------------------------------------------------
class _OutletsTab extends StatefulWidget {
  const _OutletsTab();

  @override
  State<_OutletsTab> createState() => _OutletsTabState();
}

class _OutletsTabState extends State<_OutletsTab> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOutletDialog(context),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: _supabase.from('outlets').select(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final outlets = snapshot.data as List<dynamic>? ?? [];
          if (outlets.isEmpty) {
            return const Center(child: Text('No outlets found. Add one!'));
          }

          return ListView.builder(
            itemCount: outlets.length,
            itemBuilder: (context, index) {
              final outlet = outlets[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.store)),
                title: Text(outlet['name']),
                subtitle: Text(outlet['address'] ?? 'No address'),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddOutletDialog(BuildContext context) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Outlet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Outlet Name')),
            TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabase.from('outlets').insert({
                  'name': nameController.text,
                  'address': addressController.text,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {}); // Refresh list
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MENU TAB
// -----------------------------------------------------------------------------
class _MenuTab extends ConsumerStatefulWidget {
  const _MenuTab();

  @override
  ConsumerState<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends ConsumerState<_MenuTab> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenuDialog(context),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: _supabase.from('menu_items').select(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final items = snapshot.data as List<dynamic>? ?? [];
          if (items.isEmpty) {
             return const Center(child: Text('No menu items. Add one!'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isAvailable = item['is_available'] ?? true;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isAvailable ? Colors.orange : Colors.grey,
                  child: const Icon(Icons.fastfood, color: Colors.white),
                ),
                title: Text(item['name']),
                subtitle: Text('₹${item['price']} | ${isAvailable ? "Available" : "Hidden"}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: isAvailable,
                      onChanged: (val) => _toggleAvailability(item['id'], val),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAddMenuDialog(context, item: item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDeleteItem(item['id']),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddMenuDialog(BuildContext context, {Map<String, dynamic>? item}) {
    final nameController = TextEditingController(text: item?['name'] ?? '');
    final priceController = TextEditingController(text: item?['price']?.toString() ?? '');
    String? selectedCategoryId = item?['category_id'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Add Menu Item' : 'Edit Menu Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Item Name')),
                TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
                const SizedBox(height: 16),
                
                // Category Dropdown
                FutureBuilder(
                  future: _supabase.from('categories').select(),
                  builder: (context, snapshot) {
                    final categories = snapshot.data as List<dynamic>? ?? [];
                    return DropdownButtonFormField<String>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories.map((c) => DropdownMenuItem<String>(
                        value: c['id'],
                        child: Text(c['name']),
                      )).toList(),
                      onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final data = {
                    'name': nameController.text,
                    'price': double.tryParse(priceController.text) ?? 0.0,
                    'category_id': selectedCategoryId,
                  };
                  
                  if (item == null) {
                    await _supabase.from('menu_items').insert(data);
                  } else {
                    await _supabase.from('menu_items').update(data).eq('id', item['id']);
                  }
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() {}); // Refresh list
                    // Invalidate menu items provider to refresh POS
                    ref.invalidate(menuItemsProvider);
                  }
                } catch (e) {
                  if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAvailability(String id, bool available) async {
    try {
      await _supabase.from('menu_items').update({'is_available': available}).eq('id', id);
      setState(() {});
      ref.invalidate(menuItemsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _confirmDeleteItem(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: const Text('Are you sure you want to delete this menu item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('menu_items').delete().eq('id', id);
        setState(() {});
        ref.invalidate(menuItemsProvider);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// -----------------------------------------------------------------------------
// CATEGORIES TAB
// -----------------------------------------------------------------------------
class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder(
        stream: _supabase.from('categories').stream(primaryKey: ['id']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = snapshot.data ?? [];
          if (categories.isEmpty) {
            return const Center(child: Text('No categories found.'));
          }

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return ListTile(
                leading: const Icon(Icons.label),
                title: Text(cat['name']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showCategoryDialog(context, category: cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(cat['id']),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, {Map<String, dynamic>? category}) {
    final nameController = TextEditingController(text: category?['name'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              try {
                if (category == null) {
                  await _supabase.from('categories').insert({'name': nameController.text});
                } else {
                  await _supabase.from('categories').update({'name': nameController.text}).eq('id', category['id']);
                }
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: const Text('Are you sure? Items in this category might be affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('categories').delete().eq('id', id);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// -----------------------------------------------------------------------------
// USERS TAB
// -----------------------------------------------------------------------------
class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final outletsAsync = ref.watch(outletsRepoProvider);

    return Scaffold(
      body: usersAsync.when(
        data: (users) => ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: user.role == 'admin' ? Colors.red : Colors.orange,
                child: Icon(
                  user.role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                  color: Colors.white,
                ),
              ),
              title: Text(user.email),
              subtitle: Text('Role: ${user.role.toUpperCase()}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditUserDialog(context, ref, user, outletsAsync),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showEditUserDialog(
    BuildContext context, 
    WidgetRef ref, 
    UserModel user, 
    AsyncValue<List<Map<String, dynamic>>> outletsAsync
  ) {
    String selectedRole = user.role;
    String? selectedOutletId = user.outletId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit User: ${user.email}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                ],
                onChanged: (val) => setDialogState(() => selectedRole = val!),
              ),
              const SizedBox(height: 16),
              outletsAsync.when(
                data: (outlets) => DropdownButtonFormField<String>(
                  value: selectedOutletId,
                  decoration: const InputDecoration(labelText: 'Assign Outlet'),
                  hint: const Text('None'),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('No Outlet')),
                    ...outlets.map((o) => DropdownMenuItem<String>(
                      value: o['id'],
                      child: Text(o['name']),
                    )),
                  ],
                  onChanged: (val) => setDialogState(() => selectedOutletId = val),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => Text('Error loading outlets: $e'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(userRepositoryProvider).updateUser(
                    user.id,
                    role: selectedRole,
                    outletId: selectedOutletId,
                  );
                  ref.invalidate(allUsersProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
