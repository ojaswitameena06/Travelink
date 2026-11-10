import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_service.dart';
import 'add_buddy_plan_page.dart';
import 'chat_detail_page.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]}';

class BuddyPlan {
  final String id;
  final String userId;
  final String displayName;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final num budget;
  final List<String> categories;
  final int buddiesWanted;
  final String note;

  BuddyPlan({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.categories,
    required this.buddiesWanted,
    required this.note,
  });

  factory BuddyPlan.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BuddyPlan(
      id: doc.id,
      userId: (d['userId'] ?? '').toString(),
      displayName: (d['displayName'] ?? 'Traveler').toString(),
      destination: (d['destination'] ?? '').toString(),
      startDate: (d['startDate'] as Timestamp).toDate(),
      endDate: (d['endDate'] as Timestamp).toDate(),
      budget: (d['budget'] as num?) ?? 0,
      categories: List<String>.from(d['categories'] ?? []),
      buddiesWanted: (d['buddiesWanted'] as num?)?.toInt() ?? 1,
      note: (d['note'] ?? '').toString(),
    );
  }
}

class _Match {
  final BuddyPlan plan;
  final int score;
  final bool sameDestination;
  final int overlapDays;
  final List<String> sharedCategories;

  _Match({
    required this.plan,
    required this.score,
    required this.sameDestination,
    required this.overlapDays,
    required this.sharedCategories,
  });
}

class BuddyFinderPage extends StatefulWidget {
  const BuddyFinderPage({super.key});

  @override
  State<BuddyFinderPage> createState() => _BuddyFinderPageState();
}

class _BuddyFinderPageState extends State<BuddyFinderPage> {
  bool _loading = true;
  String? _error;
  List<BuddyPlan> _myPlans = [];
  List<BuddyPlan> _others = [];
  BuddyPlan? _selectedPlan;
  List<_Match> _matches = [];
  Map<String, Map<String, String>> _insights = {};
  bool _loadingInsights = false;
  bool _insightsFailed = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  // ── Matching logic (plain scoring, max 100) ──
  _Match _scorePlan(BuddyPlan mine, BuddyPlan other) {
    int score = 0;

    // Destination (40)
    final a = mine.destination.trim().toLowerCase();
    final b = other.destination.trim().toLowerCase();
    bool sameDestination = false;
    if (a.isNotEmpty && b.isNotEmpty) {
      if (a == b) {
        score += 40;
        sameDestination = true;
      } else if (a.contains(b) || b.contains(a)) {
        score += 30;
        sameDestination = true;
      }
    }

    // Date overlap (25)
    final overlapStart = mine.startDate.isAfter(other.startDate) ? mine.startDate : other.startDate;
    final overlapEnd = mine.endDate.isBefore(other.endDate) ? mine.endDate : other.endDate;
    int overlapDays = overlapEnd.difference(overlapStart).inDays + 1;
    if (overlapDays < 0) overlapDays = 0;

    final myLength = mine.endDate.difference(mine.startDate).inDays + 1;
    final otherLength = other.endDate.difference(other.startDate).inDays + 1;
    final shorter = myLength < otherLength ? myLength : otherLength;
    if (overlapDays > 0 && shorter > 0) {
      score += ((overlapDays / shorter) * 25).round();
    }

    // Shared interests (25)
    final shared = mine.categories.where((c) => other.categories.contains(c)).toList();
    final union = {...mine.categories, ...other.categories}.length;
    if (union > 0) {
      score += ((shared.length / union) * 25).round();
    }

    // Budget closeness (10)
    if (mine.budget > 0 && other.budget > 0) {
      final ratio = (mine.budget - other.budget).abs() / mine.budget;
      if (ratio <= 0.3) {
        score += 10;
      } else if (ratio <= 0.6) {
        score += 5;
      }
    }

    return _Match(
      plan: other,
      score: score,
      sameDestination: sameDestination,
      overlapDays: overlapDays,
      sharedCategories: shared,
    );
  }

  void _rankMatches() {
    final mine = _selectedPlan;
    if (mine == null) {
      _matches = [];
      return;
    }
    _matches = _others.map((o) => _scorePlan(mine, o)).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  Future<void> _loadPlans() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Please log in to find travel buddies.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await FirebaseFirestore.instance.collection('buddy_plans').get();
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final upcoming = <BuddyPlan>[];
      for (final doc in snap.docs) {
        try {
          final plan = BuddyPlan.fromDoc(doc);
          if (!plan.endDate.isBefore(startOfToday)) upcoming.add(plan);
        } catch (_) {
          // skip malformed documents
        }
      }

      final mine = upcoming.where((p) => p.userId == user.uid).toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
      final others = upcoming.where((p) => p.userId != user.uid).toList();

      BuddyPlan? selected;
      if (mine.isNotEmpty) {
        final previousId = _selectedPlan?.id;
        selected = mine.firstWhere((p) => p.id == previousId, orElse: () => mine.first);
      }

      if (!mounted) return;
      setState(() {
        _myPlans = mine;
        _others = others;
        _selectedPlan = selected;
        _insights = {};
        _rankMatches();
        _loading = false;
      });
      _loadInsights();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load travel plans. $e';
      });
    }
  }

  Map<String, dynamic> _planToMap(BuddyPlan p) => {
        'id': p.id,
        'destination': p.destination,
        'startDate': p.startDate.toIso8601String().substring(0, 10),
        'endDate': p.endDate.toIso8601String().substring(0, 10),
        'budget': p.budget,
        'categories': p.categories,
        'buddiesWanted': p.buddiesWanted,
        'note': p.note,
      };

  Future<void> _loadInsights() async {
    final mine = _selectedPlan;
    if (mine == null || _matches.isEmpty) return;

    final top = _matches.take(5).toList();
    setState(() {
      _loadingInsights = true;
      _insightsFailed = false;
    });

    try {
      final result = await AIService.getBuddyInsights(
        _planToMap(mine),
        top.map((m) => _planToMap(m.plan)).toList(),
      );
      if (!mounted) return;
      setState(() {
        _insights = result;
        _loadingInsights = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _insightsFailed = true;
        _loadingInsights = false;
      });
    }
  }

  Future<void> _openAddPlan() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddBuddyPlanPage()),
    );
    if (added == true) _loadPlans();
  }

  Future<void> _confirmDelete(BuddyPlan p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this plan?'),
        content: Text('Your plan to ${p.destination} will no longer be shown to other travelers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('buddy_plans').doc(p.id).delete();
      _loadPlans();
    }
  }

  void _messageBuddy(BuddyPlan p) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final ids = [me.uid, p.userId]..sort();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          chatId: ids.join('_'),
          recipientUid: p.userId,
          recipientName: p.displayName,
          destination: p.destination,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Travel Buddy 🧳'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadPlans,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPlan,
        icon: const Icon(Icons.add),
        label: const Text('Post my plan'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_selectedPlan == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_emptyState()],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        _myPlanCard(),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('Your best matches',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (_loadingInsights)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (_insightsFailed)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'AI insights are unavailable right now - showing match scores only.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        if (_matches.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No other travelers have posted plans yet. Check back soon!'),
            ),
          ),
        ..._matches.map(_matchCard),
      ],
    );
  }

  Widget _emptyState() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.group_add_outlined, size: 56, color: Colors.blueAccent),
            const SizedBox(height: 12),
            const Text(
              'Post your trip plan to find travel buddies',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _others.isEmpty
                  ? 'Be the first to post an upcoming plan!'
                  : '${_others.length} upcoming plan${_others.length == 1 ? '' : 's'} from other travelers are waiting to be matched with yours.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openAddPlan,
              icon: const Icon(Icons.add),
              label: const Text('Post my plan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _myPlanCard() {
    final p = _selectedPlan!;
    return Card(
      color: Colors.blueAccent.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Matching against your plan',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete this plan',
                  onPressed: () => _confirmDelete(p),
                ),
              ],
            ),
            if (_myPlans.length > 1)
              DropdownButton<String>(
                isExpanded: true,
                value: p.id,
                items: _myPlans
                    .map((plan) => DropdownMenuItem<String>(
                          value: plan.id,
                          child: Text(
                              '${plan.destination} · ${_fmt(plan.startDate)} – ${_fmt(plan.endDate)}'),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  setState(() {
                    _selectedPlan = _myPlans.firstWhere((x) => x.id == id);
                    _insights = {};
                    _rankMatches();
                  });
                  _loadInsights();
                },
              )
            else
              Text(
                '${p.destination} · ${_fmt(p.startDate)} – ${_fmt(p.endDate)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: p.categories
                  .map((c) => Chip(
                        label: Text(c, style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _matchCard(_Match m) {
    final p = m.plan;
    final insight = _insights[p.id];
    final Color scoreColor =
        m.score >= 70 ? Colors.green : (m.score >= 40 ? Colors.orange : Colors.grey);
    final budgetText = p.budget > 0 ? '₹${p.budget} per person' : 'Budget not set';
    final buddyText = '${p.buddiesWanted} ${p.buddiesWanted == 1 ? 'buddy' : 'buddies'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                  child: Text(p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : '?'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.displayName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '${p.destination} · ${_fmt(p.startDate)} – ${_fmt(p.endDate)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${m.score}% match',
                    style: TextStyle(
                        color: scoreColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (m.sameDestination) _tag('Same destination', Colors.green),
                if (m.overlapDays > 0) _tag('${m.overlapDays} overlapping days', Colors.blue),
                ...m.sharedCategories.map((c) => _tag(c, Colors.purple)),
              ],
            ),
            const SizedBox(height: 8),
            Text('$budgetText · wants $buddyText', style: const TextStyle(fontSize: 13)),
            if (p.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('"${p.note}"',
                    style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
              ),
            if (insight != null && (insight['reason'] ?? '').isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: Colors.orange),
                        SizedBox(width: 4),
                        Text('Why you might click',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(insight['reason'] ?? ''),
                    if ((insight['icebreaker'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Icebreaker: "${insight['icebreaker']}"',
                        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy icebreaker'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: insight['icebreaker'] ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied - paste it in the chat')),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Message'),
                onPressed: () => _messageBuddy(p),
              ),
            ),
          ],
        ),
      ),
    );
  }
}