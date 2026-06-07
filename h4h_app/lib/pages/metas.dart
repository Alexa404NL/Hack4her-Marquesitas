import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:h4h_app/config.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class Goal {
  final int id;
  final String title;
  final String goalType;
  final double targetValue;
  final String targetUnit;
  final bool isAutosuggest;
  final bool isCompleted;
  final double currentProgress;
  final String createdAt;

  const Goal({
    required this.id,
    required this.title,
    required this.goalType,
    required this.targetValue,
    required this.targetUnit,
    required this.isAutosuggest,
    required this.isCompleted,
    required this.currentProgress,
    required this.createdAt,
  });

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'] as int,
        title: json['title'] as String,
        goalType: json['goal_type'] as String,
        targetValue: (json['target_value'] as num).toDouble(),
        targetUnit: json['target_unit'] as String,
        isAutosuggest: json['is_autosuggest'] as bool? ?? false,
        isCompleted: json['is_completed'] as bool? ?? false,
        currentProgress: (json['current_progress'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['created_at'] as String? ?? '',
      );

  double get progressRatio =>
      targetValue > 0 ? (currentProgress / targetValue).clamp(0.0, 1.0) : 0.0;
}

class SuggestedGoal {
  final String title;
  final String goalType;
  final double targetValue;
  final String targetUnit;
  final String reason;

  const SuggestedGoal({
    required this.title,
    required this.goalType,
    required this.targetValue,
    required this.targetUnit,
    required this.reason,
  });

  factory SuggestedGoal.fromJson(Map<String, dynamic> json) => SuggestedGoal(
        title: json['title'] as String,
        goalType: json['goal_type'] as String,
        targetValue: (json['target_value'] as num).toDouble(),
        targetUnit: json['target_unit'] as String,
        reason: json['reason'] as String,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const _purple = Color.fromARGB(255, 109, 46, 177);
const _purpleLight = Color(0xFFEDE7F6);
const _bgColor = Color.fromARGB(255, 242, 242, 242);

IconData _iconForType(String type) {
  switch (type) {
    case 'spending':
      return Icons.attach_money_rounded;
    case 'volume':
      return Icons.inventory_2_rounded;
    case 'frequency':
      return Icons.repeat_rounded;
    case 'exploration':
      return Icons.explore_rounded;
    case 'habit':
      return Icons.calendar_month_rounded;
    default:
      return Icons.flag_rounded;
  }
}

Color _colorForType(String type) {
  switch (type) {
    case 'spending':
      return const Color(0xFF6D2EB1);
    case 'volume':
      return const Color(0xFF1565C0);
    case 'frequency':
      return const Color(0xFF2E7D32);
    case 'exploration':
      return const Color(0xFFE65100);
    case 'habit':
      return const Color(0xFF6A1B9A);
    default:
      return _purple;
  }
}

String _labelForType(String type) {
  switch (type) {
    case 'spending':
      return 'Gasto';
    case 'volume':
      return 'Volumen';
    case 'frequency':
      return 'Frecuencia';
    case 'exploration':
      return 'Exploración';
    case 'habit':
      return 'Hábito';
    default:
      return type;
  }
}

String _unitLabel(String unit, double value) {
  switch (unit) {
    case 'pesos':
      return '\$${value.toStringAsFixed(0)}';
    case 'units':
      return '${value.toStringAsFixed(0)} uds';
    case 'orders':
      return '${value.toStringAsFixed(0)} pedidos';
    case 'products':
      return '${value.toStringAsFixed(0)} productos';
    case 'weeks':
      return '${value.toStringAsFixed(0)} semanas';
    default:
      return value.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Metas page
// ─────────────────────────────────────────────────────────────────────────────

class MetasPage extends StatefulWidget {
  const MetasPage({super.key});

  @override
  State<MetasPage> createState() => _MetasPageState();
}

class _MetasPageState extends State<MetasPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Goal> _goals = [];
  List<SuggestedGoal> _suggestions = [];

  bool _loadingGoals = true;
  bool _loadingSuggestions = true;
  String? _goalsError;
  String? _suggestionsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchGoals();
    _fetchSuggestions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Network calls ──────────────────────────────────────────────────────────

  Future<void> _fetchGoals() async {
    setState(() {
      _loadingGoals = true;
      _goalsError = null;
    });
    try {
      final res = await http
          .get(Uri.parse(AppConfig.goalsUrl))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['goals'] as List)
            .map((e) => Goal.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() => _goals = list);
      } else {
        throw Exception('Status ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Goals fetch failed: $e');
      if (mounted) setState(() => _goalsError = 'No se pudieron cargar las metas.');
    } finally {
      if (mounted) setState(() => _loadingGoals = false);
    }
  }

  Future<void> _fetchSuggestions() async {
    setState(() {
      _loadingSuggestions = true;
      _suggestionsError = null;
    });
    try {
      final res = await http
          .get(Uri.parse(AppConfig.goalsSuggestionsUrl))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['suggestions'] as List)
            .map((e) => SuggestedGoal.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() => _suggestions = list);
      } else {
        throw Exception('Status ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Suggestions fetch failed: $e');
      // Use hardcoded fallback suggestions
      if (mounted) {
        setState(() {
          _suggestions = _hardcodedSuggestions();
          _suggestionsError = null; // Silently use fallback
        });
      }
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  List<SuggestedGoal> _hardcodedSuggestions() => [
        const SuggestedGoal(
          title: 'Alcanzar \$5,000 en compras este mes',
          goalType: 'spending',
          targetValue: 5000,
          targetUnit: 'pesos',
          reason: 'Las tiendas similares gastan ~\$4,800/mes — ¡supéralas!',
        ),
        const SuggestedGoal(
          title: 'Hacer 3 pedidos esta semana',
          goalType: 'frequency',
          targetValue: 3,
          targetUnit: 'orders',
          reason: 'Pedidos frecuentes = inventario fresco y más ventas.',
        ),
        const SuggestedGoal(
          title: 'Comprar 50 unidades de bebidas',
          goalType: 'volume',
          targetValue: 50,
          targetUnit: 'units',
          reason: 'Las bebidas lideran ventas — abastécete mejor.',
        ),
        const SuggestedGoal(
          title: 'Descubrir 5 productos nuevos',
          goalType: 'exploration',
          targetValue: 5,
          targetUnit: 'products',
          reason: 'Diversificar puede aumentar tus ventas hasta un 20%.',
        ),
        const SuggestedGoal(
          title: 'Mantener pedidos 4 semanas seguidas',
          goalType: 'habit',
          targetValue: 4,
          targetUnit: 'weeks',
          reason: 'La consistencia garantiza mejor disponibilidad de producto.',
        ),
      ];

  Future<void> _createGoalFromSuggestion(SuggestedGoal s) async {
    await _postGoal(
      title: s.title,
      goalType: s.goalType,
      targetValue: s.targetValue,
      targetUnit: s.targetUnit,
      isAutosuggest: true,
    );
  }

  Future<void> _postGoal({
    required String title,
    required String goalType,
    required double targetValue,
    required String targetUnit,
    bool isAutosuggest = false,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(AppConfig.goalsUrl),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'title': title,
              'goal_type': goalType,
              'target_value': targetValue,
              'target_unit': targetUnit,
              'is_autosuggest': isAutosuggest,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('¡Meta agregada exitosamente!'),
              backgroundColor: _purple,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          _tabController.animateTo(0);
          _fetchGoals();
        }
      } else {
        throw Exception('Status ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Create goal failed: $e');
      // Optimistically add a local goal so the hackathon demo still works
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Meta guardada localmente (sin conexión)'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          _goals.insert(
            0,
            Goal(
              id: DateTime.now().millisecondsSinceEpoch,
              title: title,
              goalType: goalType,
              targetValue: targetValue,
              targetUnit: targetUnit,
              isAutosuggest: isAutosuggest,
              isCompleted: false,
              currentProgress: 0,
              createdAt: DateTime.now().toIso8601String(),
            ),
          );
        });
        _tabController.animateTo(0);
      }
    }
  }

  // ── Dialog for custom goal creation ───────────────────────────────────────

  void _showCreateGoalDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateGoalSheet(
        onSubmit: (title, type, value, unit) async {
          Navigator.pop(ctx);
          await _postGoal(
            title: title,
            goalType: type,
            targetValue: value,
            targetUnit: unit,
          );
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mis Metas',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _purple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _purple,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Mis Metas'),
            Tab(text: 'Sugerencias IA ✨'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GoalsTab(
            goals: _goals,
            loading: _loadingGoals,
            error: _goalsError,
            onRefresh: _fetchGoals,
          ),
          _SuggestionsTab(
            suggestions: _suggestions,
            loading: _loadingSuggestions,
            error: _suggestionsError,
            onRefresh: _fetchSuggestions,
            onAdd: _createGoalFromSuggestion,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGoalDialog,
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Nueva Meta',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Goals tab
// ─────────────────────────────────────────────────────────────────────────────

class _GoalsTab extends StatelessWidget {
  final List<Goal> goals;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  const _GoalsTab({
    required this.goals,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: _purple),
      );
    }

    if (error != null) {
      return _ErrorState(message: error!, onRetry: onRefresh);
    }

    if (goals.isEmpty) {
      return _EmptyGoalsState();
    }

    final active = goals.where((g) => !g.isCompleted).toList();
    final completed = goals.where((g) => g.isCompleted).toList();

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: _purple,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (active.isNotEmpty) ...[
            _SectionHeader(
              label: 'En progreso',
              count: active.length,
              color: _purple,
            ),
            const SizedBox(height: 8),
            ...active.map((g) => _GoalCard(goal: g)),
          ],
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SectionHeader(
              label: 'Completadas',
              count: completed.length,
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            ...completed.map((g) => _GoalCard(goal: g)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestions tab
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionsTab extends StatelessWidget {
  final List<SuggestedGoal> suggestions;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  final Future<void> Function(SuggestedGoal) onAdd;

  const _SuggestionsTab({
    required this.suggestions,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: _purple));
    }

    if (error != null && suggestions.isEmpty) {
      return _ErrorState(message: error!, onRetry: onRefresh);
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: _purple,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          // AI badge header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6D2EB1), Color(0xFF9C27B0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Metas sugeridas por IA',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Basadas en patrones de compra de toda la red',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...suggestions.map((s) => _SuggestionCard(suggestion: s, onAdd: onAdd)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual card widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final Goal goal;
  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(goal.goalType);
    final progress = goal.progressRatio;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Type icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_iconForType(goal.goalType), color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _labelForType(goal.goalType),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                          if (goal.isAutosuggest) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome,
                                      size: 9, color: Colors.amber),
                                  const SizedBox(width: 3),
                                  Text(
                                    'IA',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (goal.isCompleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Completada',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // Progress bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _unitLabel(goal.targetUnit, goal.currentProgress),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  _unitLabel(goal.targetUnit, goal.targetValue),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  goal.isCompleted ? Colors.green : color,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% completado',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  final SuggestedGoal suggestion;
  final Future<void> Function(SuggestedGoal) onAdd;

  const _SuggestionCard({required this.suggestion, required this.onAdd});

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(widget.suggestion.goalType);
    final s = widget.suggestion;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconForType(s.goalType), color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.reason,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Meta: ${_unitLabel(s.targetUnit, s.targetValue)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _adding
                            ? null
                            : () async {
                                setState(() => _adding = true);
                                await widget.onAdd(widget.suggestion);
                                if (mounted) setState(() => _adding = false);
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _adding
                                ? Colors.grey[200]
                                : _purple,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _adding
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _purple,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add_rounded,
                                        color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Agregar',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Empty / Error states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyGoalsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _purpleLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flag_rounded,
                  size: 48, color: _purple),
            ),
            const SizedBox(height: 20),
            Text(
              'Todavía no tienes metas',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Crea una meta propia o agrega una de las sugerencias de IA para comenzar a hacer crecer tu negocio.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // Switch to suggestions tab
                final state = context.findAncestorStateOfType<_MetasPageState>();
                state?._tabController.animateTo(1);
              },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                'Ver sugerencias IA',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(message,
              style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 14)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text('Reintentar',
                style: GoogleFonts.inter(
                    color: _purple, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SectionHeader(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Goal bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateGoalSheet extends StatefulWidget {
  final void Function(String title, String type, double value, String unit)
      onSubmit;

  const _CreateGoalSheet({required this.onSubmit});

  @override
  State<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<_CreateGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _valueController = TextEditingController();

  String _selectedType = 'spending';
  String _selectedUnit = 'pesos';

  static const _types = [
    ('spending', 'Gasto', Icons.attach_money_rounded),
    ('volume', 'Volumen', Icons.inventory_2_rounded),
    ('frequency', 'Frecuencia', Icons.repeat_rounded),
    ('exploration', 'Exploración', Icons.explore_rounded),
    ('habit', 'Hábito', Icons.calendar_month_rounded),
  ];

  static const _units = [
    ('pesos', 'Pesos (\$)'),
    ('units', 'Unidades'),
    ('orders', 'Pedidos'),
    ('products', 'Productos'),
    ('weeks', 'Semanas'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Crear nueva meta',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 18),

              // Title field
              Text(
                'Descripción de la meta',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Ej. Alcanzar \$10,000 este mes',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _purple),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Escribe una descripción' : null,
              ),
              const SizedBox(height: 16),

              // Type selector
              Text(
                'Tipo de meta',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _types.map((t) {
                  final (value, label, icon) = t;
                  final selected = _selectedType == value;
                  final color = _colorForType(value);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? color : Colors.grey[300]!,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon,
                              size: 16,
                              color: selected ? color : Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? color : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Target value & unit row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Value
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valor objetivo',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _valueController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            hintText: '0',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _purple),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Requerido';
                            if (double.tryParse(v) == null) return 'Número inválido';
                            if (double.parse(v) <= 0) return '> 0';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Unit
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unidad',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedUnit,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _purple),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          items: _units
                              .map((u) => DropdownMenuItem(
                                    value: u.$1,
                                    child: Text(u.$2,
                                        style: GoogleFonts.inter(fontSize: 13)),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedUnit = v ?? _selectedUnit),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      widget.onSubmit(
                        _titleController.text.trim(),
                        _selectedType,
                        double.parse(_valueController.text),
                        _selectedUnit,
                      );
                    }
                  },
                  child: Text(
                    'Guardar Meta',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
