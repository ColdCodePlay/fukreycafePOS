import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/menu_item_model.dart';
import '../../models/coupon_model.dart';

class CartItem {
  final MenuItem menuItem;
  final int quantity;

  CartItem({required this.menuItem, this.quantity = 1});
  
  double get total => menuItem.price * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      menuItem: menuItem,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartState {
  final List<CartItem> items;
  final CouponModel? appliedCoupon;
  final double taxRate; // 0.05 for 5%
  final String paymentMethod; // 'cash', 'card', 'upi'

  CartState({
    this.items = const [],
    this.appliedCoupon,
    this.taxRate = 0.0,
    this.paymentMethod = 'cash',
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get discountAmount => appliedCoupon?.calculateDiscount(subtotal) ?? 0.0;
  double get taxAmount => (subtotal - discountAmount) * taxRate;
  double get total => (subtotal - discountAmount) + taxAmount;

  CartState copyWith({
    List<CartItem>? items,
    CouponModel? appliedCoupon,
    bool clearCoupon = false,
    double? taxRate,
    String? paymentMethod,
  }) {
    return CartState(
      items: items ?? this.items,
      appliedCoupon: clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
      taxRate: taxRate ?? this.taxRate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    return CartState();
  }

  void addItem(MenuItem item) {
    final existingIndex = state.items.indexWhere((i) => i.menuItem.id == item.id);
    if (existingIndex >= 0) {
      final newItems = state.items.map((i) {
        if (i.menuItem.id == item.id) {
          return i.copyWith(quantity: i.quantity + 1);
        }
        return i;
      }).toList();
      state = state.copyWith(items: newItems);
    } else {
      state = state.copyWith(items: [...state.items, CartItem(menuItem: item)]);
    }
  }

  void decrementItem(String itemId) {
    final existingIndex = state.items.indexWhere((i) => i.menuItem.id == itemId);
    if (existingIndex >= 0) {
      final item = state.items[existingIndex];
      if (item.quantity > 1) {
        final newItems = state.items.map((i) {
          if (i.menuItem.id == itemId) {
            return i.copyWith(quantity: i.quantity - 1);
          }
          return i;
        }).toList();
        state = state.copyWith(items: newItems);
      } else {
        removeItem(itemId);
      }
    }
  }

  void removeItem(String itemId) {
    state = state.copyWith(
      items: state.items.where((i) => i.menuItem.id != itemId).toList(),
    );
  }

  void clearCart() {
    state = CartState();
  }

  void applyCoupon(CouponModel coupon) {
    state = state.copyWith(appliedCoupon: coupon);
  }

  void removeCoupon() {
    state = state.copyWith(clearCoupon: true);
  }

  void setTaxRate(double rate) {
    state = state.copyWith(taxRate: rate);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
