import 'package:flutter/material.dart';
import '../models/progress_model.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ProgressPhase>? _phases;
  String? _email;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final progressData = await ApiService.getProgress();
      final email = await ApiService.getUserEmail();
      setState(() {
        _phases = (progressData['phases'] as List)
            .map((p) => ProgressPhase.fromJson(p as Map<String, dynamic>))
            .toList();
        _email = email;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int get _totalItems =>
      _phases?.fold(0, (s, p) => s! + p.items.length) ?? 0;
  int get _completedItems =>
      _phases?.fold(0, (s, p) => s! + p.completedCount) ?? 0;
  double get _pct => _totalItems > 0 ? _completedItems / _totalItems : 0;

  Future<void> _toggle(int phaseIndex, ProgressItem item) async {
    final newVal = !item.completed;
    setState(() {
      item.completed = newVal;
    });
    try {
      await ApiService.updateProgress(phaseIndex, item.index, newVal);
    } catch (_) {
      setState(() {
        item.completed = !newVal;
      });
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Argo CD + Kargo Tracker'),
        actions: [
          if (_email != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                  child: Text(_email!,
                      style: const TextStyle(fontSize: 13, color: Colors.grey))),
            ),
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOverallProgress(),
        const SizedBox(height: 16),
        for (var i = 0; i < _phases!.length; i++)
          _buildPhaseCard(i, _phases![i]),
      ],
    );
  }

  Widget _buildOverallProgress() {
    final pctLabel = '${(_pct * 100).round()}%';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(pctLabel,
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
                Text('$_completedItems / $_totalItems tasks',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                  value: _pct, minHeight: 12),
            ),
            const SizedBox(height: 8),
            const Text('Intensive beginner path · ~8–10 days',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseCard(int pi, ProgressPhase phase) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: pi < 2,
        title: Text(phase.title,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${phase.days}  ·  ${phase.completedCount}/${phase.items.length} done',
          style: const TextStyle(fontSize: 12),
        ),
        children: phase.items
            .map((item) => CheckboxListTile(
                  value: item.completed,
                  onChanged: (_) => _toggle(pi, item),
                  title: Text(
                    item.text,
                    style: TextStyle(
                      fontSize: 13,
                      decoration: item.completed
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.completed ? Colors.grey : null,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ))
            .toList(),
      ),
    );
  }
}
