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
  int _selectedRating = 0;
  bool _feedbackSent = false;

  // Auto-order agent (LangChain + Gemini) state
  bool _generatingAutoOrder = false;
  bool _applyingAutoOrder = false;
  bool _autoOrderApplied = false;
  List<Map<String, dynamic>>? _autoOrderItems;
  String? _autoOrderSummary;
  Map<int, bool> _autoOrderAccepted = {};
  int _agentRating = 0;
  bool _agentFeedbackSent = false;

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
            _selectedRating = 0;
            _feedbackSent = false;
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

  /// Sends a star rating (1-5) for the current recommendation set as an RL
  /// reward signal — stored in `rl_experiences` and consumed by the nightly
  /// offline trainer (rl_agent.py) to make future recs better.
  Future<void> _submitRecommendationFeedback() async {
    if (_selectedRating == 0 || _feedbackSent) return;

    final reward = (_selectedRating - 3) / 2.0; // 1★→-1.0 … 3★→0.0 … 5★→+1.0
    final now = DateTime.now();
    final state = <double>[
      (_cart.subtotal / 1000).clamp(0.0, 1.0),
      0.5,
      now.weekday / 6.0,
      now.hour / 23.0,
      (_cart.totalItemCount / 20).clamp(0.0, 1.0),
    ];

    try {
      await http.post(
        Uri.parse(AppConfig.rlTelemetryUrl),
        headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, dynamic>{
          'state': state,
          'action': 0, 
          'reward': reward,
          'customer_id': _customerId,
        }),
      ).timeout(const Duration(seconds: 4));

      if (mounted) {
        setState(() => _feedbackSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Gracias! Esto ayuda a mejorar tus próximas recomendaciones'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('RL feedback failed (non-critical): $e');
    }
  }

  /// Asks the LangChain + Gemini agent (POST /api/pedido-automatico) for a
  /// re-order proposal built from purchase history and the live cart. The
  /// backend only ever returns items it knows the SKU/price/picture for —
  /// no hallucinated products — so we can render them with the same tiles
  /// used elsewhere in the app.
  Future<void> _generateAutoOrder() async {
    if (_generatingAutoOrder) return;
    setState(() => _generatingAutoOrder = true);

    try {
      final response = await http.post(
        Uri.parse(AppConfig.autoOrderUrl),
        headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, dynamic>{
          'customer_id': _customerId,
          'current_cart': _cart.items.map((item) => {
                'sku': item.sku,
                'title': item.title,
                'quantity': item.quantity,
                'price': item.price,
              }).toList(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final items = List<Map<String, dynamic>>.from(data['items'] as List);
        if (mounted) {
          setState(() {
            _autoOrderItems = items;
            _autoOrderSummary = data['summary'] as String?;
            _autoOrderAccepted = {
              for (final item in items) (item['sku'] as num).toInt(): true,
            };
            _autoOrderApplied = false;
            _agentRating = 0;
            _agentFeedbackSent = false;
          });
        }
      } else {
        throw Exception('Backend returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Auto-order generation failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo generar la propuesta. Intenta de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingAutoOrder = false);
    }
  }

  /// Applies every suggestion the user left toggled "Aceptar": adds brand-new
  /// items at the suggested quantity, and overwrites the quantity for items
  /// already in the cart whose suggested quantity differs. "same"-type
  /// suggestions are no-ops by definition.
  Future<void> _applyAutoOrder() async {
    if (_autoOrderItems == null || _applyingAutoOrder || _autoOrderApplied) return;
    setState(() => _applyingAutoOrder = true);

    var appliedCount = 0;
    for (final item in _autoOrderItems!) {
      final sku = (item['sku'] as num).toInt();
      if (_autoOrderAccepted[sku] != true) continue;

      final changeType = item['change_type'] as String;
      final suggestedQty = (item['suggested_quantity'] as num).toInt();
      if (changeType == 'new') {
        await _cart.addItem(
          sku: sku,
          title: item['title'] as String,
          picture: item['picture'] as String,
          price: item['price'] as String,
          quantity: suggestedQty,
        );
        appliedCount++;
      } else if (changeType != 'same') {
        await _cart.setQuantity(sku, suggestedQty);
        appliedCount++;
      }
    }

    if (mounted) {
      setState(() {
        _applyingAutoOrder = false;
        _autoOrderApplied = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appliedCount == 0
              ? 'No había cambios aceptados que aplicar'
              : '$appliedCount cambio${appliedCount == 1 ? '' : 's'} aplicado${appliedCount == 1 ? '' : 's'} a tu carrito'),
        ),
      );
    }
  }

  /// "How useful was the agent overall" — separate from the per-recommendation
  /// star rating, this rates the auto-order feature as a whole and is stored
  /// in `agent_feedback` (POST /api/agent-feedback).
  Future<void> _submitAgentFeedback() async {
    if (_agentRating == 0 || _agentFeedbackSent) return;

    try {
      await http.post(
        Uri.parse(AppConfig.agentFeedbackUrl),
        headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, dynamic>{
          'customer_id': _customerId,
          'rating': _agentRating,
        }),
      ).timeout(const Duration(seconds: 4));

      if (mounted) {
        setState(() => _agentFeedbackSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Gracias! Tu opinión nos ayuda a mejorar el agente'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Agent feedback failed (non-critical): $e');
    }
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
            _buildAutoOrderSection(),
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
                      const SizedBox(height: 16),
                      _buildRecommendationFeedback(),
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

  Widget _buildRecommendationFeedback() {
    if (_feedbackSent) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 6),
          Text(
            '¡Gracias por tu valoración!',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Qué tan útiles fueron estas recomendaciones?',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ...List.generate(5, (i) {
              final starValue = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedRating = starValue),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    starValue <= _selectedRating ? Icons.star : Icons.star_border,
                    color: const Color.fromARGB(255, 109, 46, 177),
                    size: 26,
                  ),
                ),
              );
            }),
            const SizedBox(width: 8),
            if (_selectedRating > 0)
              TextButton(
                onPressed: _submitRecommendationFeedback,
                child: const Text(
                  'Enviar',
                  style: TextStyle(color: Color.fromARGB(255, 109, 46, 177), fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAutoOrderSection() {
    const purple = Color.fromARGB(255, 109, 46, 177);
    final items = _autoOrderItems;
    final acceptedCount = _autoOrderAccepted.values.where((v) => v).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: purple, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pedido automático con IA',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Un agente revisa tus pedidos anteriores y arma una propuesta con cantidades sugeridas. Tú decides qué cambios aceptar.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generatingAutoOrder || _cart.items.isEmpty ? null : _generateAutoOrder,
                icon: _generatingAutoOrder
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: purple),
                      )
                    : const Icon(Icons.smart_toy_outlined, size: 18),
                label: Text(_generatingAutoOrder
                    ? 'Generando propuesta...'
                    : (items == null ? 'Generar pedido automático' : 'Generar otra propuesta')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: purple,
                  side: const BorderSide(color: purple),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            if (items != null) ...[
              const SizedBox(height: 16),
              if (_autoOrderSummary != null && _autoOrderSummary!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 18, color: purple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_autoOrderSummary!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ),
                    ],
                  ),
                ),
              if (items.isEmpty)
                Text(
                  'El agente no encontró cambios que sugerir por ahora.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                )
              else ...[
                ...items.map(_buildAutoOrderItemTile),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_applyingAutoOrder || _autoOrderApplied || acceptedCount == 0) ? null : _applyAutoOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _applyingAutoOrder
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _autoOrderApplied
                                ? 'Cambios aplicados ✓'
                                : 'Aplicar $acceptedCount cambio${acceptedCount == 1 ? '' : 's'} al carrito',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildAgentFeedback(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAutoOrderItemTile(Map<String, dynamic> item) {
    final sku = (item['sku'] as num).toInt();
    final changeType = item['change_type'] as String;
    final cartQty = (item['cart_quantity'] as num).toInt();
    final suggestedQty = (item['suggested_quantity'] as num).toInt();
    final accepted = _autoOrderAccepted[sku] ?? true;

    Color badgeColor;
    String badgeLabel;
    switch (changeType) {
      case 'new':
        badgeColor = Colors.green;
        badgeLabel = 'Nuevo · agregar $suggestedQty';
        break;
      case 'increased':
        badgeColor = Colors.orange[800]!;
        badgeLabel = 'Subir cantidad: $cartQty → $suggestedQty';
        break;
      case 'decreased':
        badgeColor = Colors.blueGrey;
        badgeLabel = 'Bajar cantidad: $cartQty → $suggestedQty';
        break;
      default:
        badgeColor = Colors.grey[600]!;
        badgeLabel = 'Sin cambios ($cartQty)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accepted ? Colors.white : Colors.grey[100],
        border: Border.all(color: accepted ? badgeColor.withValues(alpha: 0.4) : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(item['picture'] as String, width: 46, height: 46, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] as String,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['reason'] as String,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: accepted,
                activeColor: const Color.fromARGB(255, 109, 46, 177),
                onChanged: (v) => setState(() => _autoOrderAccepted[sku] = v),
              ),
              Text(
                accepted ? 'Aceptar' : 'Rechazar',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: accepted ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "How useful was the agent" — separate signal from the per-recommendation
  /// rating: this rates the auto-order feature/agent as a whole.
  Widget _buildAgentFeedback() {
    if (_agentFeedbackSent) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 6),
          Text('¡Gracias por calificar al agente!', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Qué tan útil fue el agente de pedido automático?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(5, (i) {
                final starValue = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _agentRating = starValue),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      starValue <= _agentRating ? Icons.star : Icons.star_border,
                      color: const Color.fromARGB(255, 109, 46, 177),
                      size: 26,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              if (_agentRating > 0)
                TextButton(
                  onPressed: _submitAgentFeedback,
                  child: const Text(
                    'Enviar',
                    style: TextStyle(color: Color.fromARGB(255, 109, 46, 177), fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
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
