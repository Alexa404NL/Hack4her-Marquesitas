import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:h4h_app/config.dart';
import 'package:h4h_app/pages/tu_pedido.dart' show TuPedido, CompactPedidoTile, SuggestionTile;
import 'package:h4h_app/services/cart_store.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';

class TuCarrito extends StatefulWidget {
  const TuCarrito({super.key});

  @override
  State<TuCarrito> createState() => _TuCarritoState();
}

class _TuCarritoState extends State<TuCarrito> {
  static const _customerId = '5.183610e+17'; // Test customer ID with robust history

  final CartStore _cart = CartStore.instance;

  List<Map<String, dynamic>> _recommendations = [];
  List<int> _lastFetchedSkus = [];
  bool _loadingRecommendations = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _cart.load().then((_) {
      if (mounted) setState(() {});
      _maybeRefreshRecommendations();
    });
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (!mounted) return;
    setState(() {});
    _maybeRefreshRecommendations();
  }

  /// Re-fetches recommendations only when the set of SKUs in the cart
  /// actually changed, so quantity tweaks don't spam the backend.
  Future<void> _maybeRefreshRecommendations() async {
    final currentSkus = _cart.skus;
    if (currentSkus.isEmpty) {
      if (_recommendations.isNotEmpty || _lastFetchedSkus.isNotEmpty) {
        setState(() {
          _recommendations = [];
          _lastFetchedSkus = [];
        });
      }
      return;
    }
    if (_setEquals(currentSkus, _lastFetchedSkus) || _loadingRecommendations) return;

    _loadingRecommendations = true;
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/pedido-inteligente'),
        headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, dynamic>{
          'customer_id': _customerId,
          'current_cart_skus': currentSkus,
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _recommendations = List<Map<String, dynamic>>.from(data['sugerencias']);
            _lastFetchedSkus = currentSkus;
          });
        }
      }
    } catch (e) {
      debugPrint('Recommendation fetch failed: $e');
    } finally {
      _loadingRecommendations = false;
    }
  }

  bool _setEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    final sortedA = [...a]..sort();
    final sortedB = [...b]..sort();
    for (var i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
  }

  void _addRecommendationToCart(Map<String, dynamic> item) {
    _cart.addItem(
      sku: (item['sku'] as num).toInt(),
      title: item['title'] as String,
      picture: item['picture'] as String,
      price: item['price'] as String,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item['title']} agregado al carrito'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _saveOrder() async {
    if (_cart.isEmpty || _saving) return;
    setState(() => _saving = true);

    try {
      final response = await http.post(
        Uri.parse(AppConfig.ordersUrl),
        headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, dynamic>{
          'customer_id': _customerId,
          'items': _cart.items.map((item) => {
                'sku': item.sku,
                'title': item.title,
                'quantity': item.quantity,
                'price': item.price,
              }).toList(),
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        await _cart.clear();
        if (mounted) _showOrderConfirmationDialog();
      } else {
        throw Exception('Backend returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Save order failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el pedido. Intenta de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showOrderConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 150, child: Lottie.asset('assets/images/Checkmark.json')),
                const SizedBox(height: 10),
                const Text(
                  '¡Pedido Guardado!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Tu pedido fue registrado y se usará para mejorar tus próximas recomendaciones',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 109, 46, 177),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
                    },
                    child: const Text(
                      'Volver al Inicio',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _cart.items;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 242, 242, 242),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Tu Carrito',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildPedidoInteligenteBanner(context),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildEmptyCartContainer(),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Artículos en tu carrito',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return CompactPedidoTile(
                          title: item.title,
                          picture: item.picture,
                          quantity: item.quantity,
                          price: item.price,
                          onIncrement: () => _cart.updateQuantity(item.sku, true),
                          onDecrement: () => _cart.updateQuantity(item.sku, false),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildOrderSummary(),
              ),
              if (_recommendations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recomendado para ti',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _recommendations.length,
                          itemBuilder: (context, index) {
                            final rec = _recommendations[index];
                            return SuggestionTile(
                              title: rec['title'],
                              picture: rec['picture'],
                              price: rec['price'],
                              onAdd: () => _addRecommendationToCart(rec),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 109, 46, 177),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saving ? null : _saveOrder,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Guardar Pedido',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPedidoInteligenteBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TuPedido()));
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 109, 46, 177),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pedido Inteligente',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Compra rápido con tu orden sugerida',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCartContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Tu carrito está vacío',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Agrega productos desde el inicio para verlos aquí',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final total = _cart.subtotal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(fontSize: 14, color: Colors.grey)),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Envío', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const Text('Gratis', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.green)),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 109, 46, 177),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
