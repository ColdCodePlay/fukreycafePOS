
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../repositories/sales_repository.dart';
import '../../repositories/menu_repository.dart';
import '../../repositories/user_repository.dart';
import '../auth/auth_provider.dart';

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
    final range = ref.watch(dateRangeProvider);
    final statsAsync = ref.watch(filteredSalesProvider);
    final recentOrdersAsync = ref.watch(recentOrdersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Performance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(range.start.day == range.end.day ? 'Today' : 'Date Range'),
                        onPressed: () async {
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
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  statsAsync.when(
                    data: (stats) => isMobile 
                      ? Column(
                          children: [
                            _StatCard(title: 'Revenue', value: '₹${stats.totalRevenue.toInt()}', icon: Icons.currency_rupee, color: Colors.green),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _StatCard(title: 'Orders', value: stats.totalOrders.toString(), icon: Icons.receipt_long, color: Colors.blue),
                                const SizedBox(width: 12),
                                _StatCard(title: 'Avg.', value: '₹${stats.averageOrderValue.toInt()}', icon: Icons.analytics, color: Colors.orange),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            _StatCard(title: 'Total Revenue', value: '₹${stats.totalRevenue.toStringAsFixed(2)}', icon: Icons.currency_rupee, color: Colors.green),
                            const SizedBox(width: 16),
                            _StatCard(title: 'Total Orders', value: stats.totalOrders.toString(), icon: Icons.receipt_long, color: Colors.blue),
                            const SizedBox(width: 16),
                            _StatCard(title: 'Avg. Order', value: '₹${stats.averageOrderValue.toStringAsFixed(2)}', icon: Icons.analytics, color: Colors.orange),
                          ],
                        ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => Text('Error: $e'),
                  ),
                ],
              );
            }
          ),

          const SizedBox(height: 32),
          const Text('Recent Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          recentOrdersAsync.when(
            data: (orders) => orders.isEmpty 
              ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No orders found')))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final total = order['total_amount'] ?? 0;
                    final time = DateTime.parse(order['created_at']).toLocal();
                    final items = order['order_items'] as List? ?? [];
                    final customerName = order['customer_name'] ?? 'Guest';
                    final customerPhone = order['customer_phone'] ?? 'No Phone';

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Order #${order['id'].toString().substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('${time.hour}:${time.minute.toString().padLeft(2, '0')} | $customerName', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                  ],
                                ),
                                Text('₹$total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFE38242))),
                              ],
                            ),
                            if (customerPhone != 'No Phone') Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text('📞 $customerPhone', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ),
                            const Divider(height: 24),
                            ...items.map((item) {
                              final menuName = item['menu_items']?['name'] ?? 'Unknown Item';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${item['quantity']}x $menuName', style: const TextStyle(fontSize: 14)),
                                    Text('₹${(item['price'] * item['quantity']).toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error loading orders: $e'),
          ),
        ],
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
    return Expanded(
      child: Container(
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
                  ),
                ),
              ],
            ),
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
