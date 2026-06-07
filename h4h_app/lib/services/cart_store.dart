import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One line item in the cart. Items are grouped by [sku] — adding the same
/// product twice increments [quantity] instead of creating a duplicate row.
class CartItem {
  final int sku;
  final String title;
  final String picture;
  final String price;
  int quantity;

  CartItem({
    required this.sku,
    required this.title,
    required this.picture,
    required this.price,
    this.quantity = 1,
  });

  double get unitPrice =>
      double.tryParse(price.replaceAll('\$', '').replaceAll(',', '')) ?? 0.0;

  Map<String, dynamic> toJson() => {
        'sku': sku,
        'title': title,
        'picture': picture,
        'price': price,
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        sku: (json['sku'] as num).toInt(),
        title: json['title'] as String,
        picture: json['picture'] as String,
        price: json['price'] as String,
        quantity: (json['quantity'] as num).toInt(),
      );
}

/// App-wide cart, persisted locally so it survives navigation and restarts.
/// Grouping by SKU happens here so every entry point (dashboard, suggestions,
/// chat, etc.) shares one consistent cart.
class CartStore extends ChangeNotifier {
  CartStore._internal();
  static final CartStore instance = CartStore._internal();

  static const _prefsKey = 'cart_items_v1';

  final List<CartItem> _items = [];
  bool _loaded = false;

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  int get totalItemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.unitPrice * item.quantity);

  List<int> get skus => _items.map((item) => item.sku).toList();

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _items
        ..clear()
        ..addAll(decoded.map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map))));
      notifyListeners();
    } catch (e) {
      debugPrint('CartStore: failed to load persisted cart: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> addItem({
    required int sku,
    required String title,
    required String picture,
    required String price,
    int quantity = 1,
  }) async {
    final existingIndex = _items.indexWhere((item) => item.sku == sku);
    if (existingIndex != -1) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItem(
        sku: sku,
        title: title,
        picture: picture,
        price: price,
        quantity: quantity,
      ));
    }
    notifyListeners();
    await _persist();
  }

  /// Sets [sku]'s quantity to an absolute value — unlike [addItem] (which adds
  /// on top of what's already there), this is what applying an agent's
  /// "change quantity to N" suggestion needs.
  Future<void> setQuantity(int sku, int quantity) async {
    if (quantity <= 0) {
      await removeItem(sku);
      return;
    }
    final index = _items.indexWhere((item) => item.sku == sku);
    if (index == -1) return;
    _items[index].quantity = quantity;
    notifyListeners();
    await _persist();
  }

  Future<void> updateQuantity(int sku, bool increment) async {
    final index = _items.indexWhere((item) => item.sku == sku);
    if (index == -1) return;

    if (increment) {
      _items[index].quantity++;
    } else if (_items[index].quantity > 1) {
      _items[index].quantity--;
    } else {
      _items.removeAt(index);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> removeItem(int sku) async {
    _items.removeWhere((item) => item.sku == sku);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    await _persist();
  }
}
