import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../services/admin_service.dart';
import '../services/debug_admin_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final Future<bool> _access;

  @override
  void initState() {
    super.initState();
    _access = AdminService.instance.isAdmin(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _access,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Accès refusé')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ce compte ne possède pas le rôle Super Admin.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return DefaultTabController(
          length: 6,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Super Admin'),
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(icon: Icon(Icons.insights_rounded), text: 'Vue générale'),
                  Tab(icon: Icon(Icons.payments_rounded), text: 'Abonnements'),
                  Tab(icon: Icon(Icons.emoji_events_rounded), text: 'Défis'),
                  Tab(icon: Icon(Icons.people_alt_rounded), text: 'Utilisateurs'),
                  Tab(icon: Icon(Icons.campaign_rounded), text: 'Communication'),
                  Tab(icon: Icon(Icons.science_rounded), text: 'Tests'),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                _OverviewTab(),
                _SubscriptionsTab(),
                _GamificationTab(),
                _UsersTab(),
                _CommunicationTab(),
                _TestsTab(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _future = AdminService.instance.dashboardStats();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorRetry(error: snapshot.error, onRetry: () => setState(_refresh));
        }

        final s = snapshot.data ?? const <String, dynamic>{};
        final total = (s['totalUsers'] as num?)?.toInt() ?? 0;
        final premium = (s['premiumUsers'] as num?)?.toInt() ?? 0;
        final monthly = (s['monthlyUsers'] as num?)?.toInt() ?? 0;
        final yearly = (s['yearlyUsers'] as num?)?.toInt() ?? 0;
        final new7 = (s['newUsers7Days'] as num?)?.toInt() ?? 0;
        final new30 = (s['newUsers30Days'] as num?)?.toInt() ?? 0;
        final aiToday = (s['aiCallsToday'] as num?)?.toInt() ?? 0;
        final aiMonth = (s['aiCallsMonth'] as num?)?.toInt() ?? 0;
        final guidedToday =
            (s['guidedSessionsToday'] as num?)?.toInt() ?? 0;
        final guidedMonth =
            (s['guidedSessionsMonth'] as num?)?.toInt() ?? 0;
        final examsMonth = (s['examSessionsMonth'] as num?)?.toInt() ?? 0;
        final passesMonth =
            (s['intensivePassesSoldMonth'] as num?)?.toInt() ?? 0;
        final passRevenue =
            (s['intensivePassRevenueMonth'] as num?)?.toDouble() ?? 0;
        final activePaid =
            (s['activePaidSubscribers'] as num?)?.toInt() ?? 0;
        final cancelling =
            (s['cancellingSubscribers'] as num?)?.toInt() ?? 0;
        final paymentIssues =
            (s['paymentIssueSubscribers'] as num?)?.toInt() ?? 0;
        final aiHealth = s['aiHealth'] is Map
            ? Map<String, dynamic>.from(s['aiHealth'] as Map)
            : <String, dynamic>{};
        final aiOk = aiHealth['ok'] == true;
        final contentMigration = s['contentMigration'] is Map
            ? Map<String, dynamic>.from(s['contentMigration'] as Map)
            : <String, dynamic>{};
        final contentV2Applied = contentMigration['applied'] == true;
        final recurring = (s['estimatedMonthlyRevenue'] as num?)?.toDouble() ?? 0;

        return RefreshIndicator(
          onRefresh: () async {
            setState(_refresh);
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: _MetricCard('Inscrits', '$total', Icons.people_alt_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _MetricCard('Premium', '$premium', Icons.workspace_premium_rounded)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _MetricCard('Mensuels', '$monthly', Icons.calendar_view_month_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _MetricCard('Annuels', '$yearly', Icons.event_available_rounded)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _MetricCard('Nouveaux 7 j', '$new7', Icons.person_add_alt_1_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _MetricCard('Nouveaux 30 j', '$new30', Icons.trending_up_rounded)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _MetricCard('IA aujourd’hui', '$aiToday', Icons.auto_awesome_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _MetricCard('IA ce mois', '$aiMonth', Icons.data_usage_rounded)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _MetricCard('Séances aujourd’hui', '$guidedToday', Icons.mic_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _MetricCard('Examens ce mois', '$examsMonth', Icons.school_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _MetricCard('Payants actifs', '$activePaid', Icons.verified_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _MetricCard('À surveiller', '${cancelling + paymentIssues}', Icons.warning_amber_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              _AdminCard(
                title: 'État du service IA',
                icon: aiOk ? Icons.check_circle_rounded : Icons.error_rounded,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      aiOk ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: aiOk ? Colors.green : Colors.red,
                      size: 34,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            aiOk ? 'IA opérationnelle' : 'IA à vérifier',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${aiHealth['message'] ?? 'Aucun contrôle disponible pour le moment.'}',
                            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                          ),
                          if (aiHealth['reason'] == 'insufficient_quota') ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Ajoute du crédit dans OpenAI Billing puis relance une simulation.',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _AdminCard(
                title: 'Leçons, quiz et simulations V2',
                icon: contentV2Applied
                    ? Icons.library_add_check_rounded
                    : Icons.pending_actions_rounded,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      contentV2Applied
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: contentV2Applied ? Colors.green : Colors.deepOrange,
                      size: 34,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        contentV2Applied
                            ? 'Migration pédagogique V2 appliquée dans Firestore.'
                            : 'Migration pédagogique non détectée. Les améliorations préparées ne sont pas encore dans les collections en ligne. Exécute npm run migrate:v2:apply une seule fois.',
                        style: TextStyle(
                          height: 1.4,
                          fontWeight: FontWeight.w800,
                          color: contentV2Applied
                              ? Colors.green.shade800
                              : Colors.deepOrange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _AdminCard(
                title: 'Entraînement IA maîtrisé',
                icon: Icons.shield_rounded,
                child: Column(
                  children: [
                    _InfoRow('Séances guidées ce mois', '$guidedMonth'),
                    _InfoRow('Examens blancs ce mois', '$examsMonth'),
                    _InfoRow('Pass intensifs vendus', '$passesMonth'),
                    _InfoRow(
                      'Recette brute des pass',
                      '${passRevenue.toStringAsFixed(2).replaceAll('.', ',')} €',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _AdminCard(
                title: 'Revenu récurrent estimé',
                icon: Icons.euro_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${recurring.toStringAsFixed(2).replaceAll('.', ',')} € / mois',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Estimation : abonnements mensuels à 7,99 € + annuels à 29,99 € répartis sur 12 mois. Les remboursements et commissions Google ne sont pas déduits.',
                      style: TextStyle(fontSize: 12, height: 1.35, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SubscriptionsTab extends StatefulWidget {
  const _SubscriptionsTab();

  @override
  State<_SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends State<_SubscriptionsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _future = AdminService.instance.listSubscriptions();
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('$value')?.toLocal();
    if (parsed == null) return '—';
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _statusLabel(String value, bool active, bool autoRenewing) {
    if (value == 'LEGACY_ACTIVE') return 'Actif • ancien achat à resynchroniser';
    if (value == 'LEGACY_RECEIPT') return 'Ancien reçu • statut à actualiser';
    if (value == 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD') {
      return 'Paiement à régulariser';
    }
    if (value == 'SUBSCRIPTION_STATE_ON_HOLD') return 'Paiement suspendu';
    if (value == 'SUBSCRIPTION_STATE_CANCELED' && active) {
      return 'Résilié, encore actif';
    }
    if (!active) return 'Expiré / inactif';
    return autoRenewing ? 'Actif • renouvellement auto' : 'Actif';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorRetry(
            error: snapshot.error,
            onRetry: () => setState(_refresh),
          );
        }
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return RefreshIndicator(
          onRefresh: () async {
            setState(_refresh);
            await _future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            children: [
              _AdminCard(
                title: 'Abonnements Google Play vérifiés',
                icon: Icons.verified_user_rounded,
                child: Text(
                  '${rows.where((row) => row['active'] == true).length} actif(s) sur ${rows.length} compte(s) synchronisé(s). '
                  'Les anciens abonnés apparaîtront après ouverture de la nouvelle version ou restauration de leurs achats.',
                  style: const TextStyle(height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const _AdminCard(
                  title: 'Aucun abonnement synchronisé',
                  icon: Icons.hourglass_empty_rounded,
                  child: Text(
                    'Google Play peut afficher du revenu avant que le compte utilisateur soit relié à Firestore. La restauration des achats réalisera ce rapprochement.',
                  ),
                )
              else
                ...rows.map((row) {
                  final active = row['active'] == true;
                  final autoRenewing = row['autoRenewing'] == true;
                  final status = _statusLabel(
                    '${row['status'] ?? ''}',
                    active,
                    autoRenewing,
                  );
                  final source = '${row['source'] ?? 'google_play'}';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: active
                                    ? Colors.green.withOpacity(.12)
                                    : Colors.grey.withOpacity(.15),
                                child: Icon(
                                  active
                                      ? Icons.workspace_premium_rounded
                                      : Icons.person_off_rounded,
                                  color: active ? Colors.green : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${row['name'] ?? 'Utilisateur'}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900),
                                    ),
                                    Text(
                                      '${row['email'] ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              _SmallChip(
                                '${row['plan'] ?? 'PREMIUM'}'
                                    .replaceAll('PREMIUM_', ''),
                                active,
                              ),
                            ],
                          ),
                          const Divider(height: 22),
                          _InfoRow('Statut', status),
                          _InfoRow('Début', _date(row['startedAt'])),
                          _InfoRow('Fin de période', _date(row['expiresAt'])),
                          _InfoRow('Dernière vérification', _date(row['verifiedAt'])),
                          _InfoRow(
                            'Source',
                            source == 'google_play'
                                ? 'Google Play vérifié'
                                : source == 'historical_receipt'
                                    ? 'Ancien reçu sécurisé'
                                    : 'Ancien droit Premium',
                          ),
                          if (row['needsRefresh'] == true)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Les dates exactes apparaîtront après ouverture de la V2.2 par cet abonné ou restauration de son achat.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.35,
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _GamificationTab extends StatefulWidget {
  const _GamificationTab();

  @override
  State<_GamificationTab> createState() => _GamificationTabState();
}

class _GamificationTabState extends State<_GamificationTab> {
  final _dailyGoal = TextEditingController(text: '3');
  final _dailyBonus = TextEditingController(text: '25');
  final _title = TextEditingController(text: 'Défi de la semaine');
  final _description = TextEditingController(
    text: 'Progresse régulièrement et décroche le badge spécial.',
  );
  final _target = TextEditingController(text: '5');
  final _bonus = TextEditingController(text: '150');
  bool _enabled = true;
  bool _challengeEnabled = true;
  bool _loading = true;
  bool _busy = false;
  String _metric = 'quiz';
  int _durationDays = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await AdminService.instance.loadGamificationConfig();
      final rawChallenge = config['challenge'];
      final challenge = rawChallenge is Map
          ? Map<String, dynamic>.from(rawChallenge)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _enabled = config['enabled'] != false;
        _dailyGoal.text = '${config['dailyGoal'] ?? 3}';
        _dailyBonus.text = '${config['dailyBonusXp'] ?? 25}';
        _challengeEnabled = challenge['enabled'] == true;
        _title.text = '${challenge['title'] ?? 'Défi de la semaine'}';
        _description.text = '${challenge['description'] ?? ''}';
        _target.text = '${challenge['target'] ?? 5}';
        _bonus.text = '${challenge['bonusXp'] ?? 150}';
        final loadedMetric = '${challenge['metric'] ?? 'quiz'}';
        _metric = const {'quiz', 'simulation', 'lesson', 'assistant', 'xp'}
                .contains(loadedMetric)
            ? loadedMetric
            : 'quiz';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _dailyGoal,
      _dailyBonus,
      _title,
      _description,
      _target,
      _bonus,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _publish() async {
    if (_challengeEnabled && _title.text.trim().isEmpty) {
      _snack('Ajoute un titre au défi.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AdminService.instance.publishGamification({
        'enabled': _enabled,
        'dailyGoal': int.tryParse(_dailyGoal.text) ?? 3,
        'dailyBonusXp': int.tryParse(_dailyBonus.text) ?? 25,
        'challenge': {
          'enabled': _challengeEnabled,
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'metric': _metric,
          'target': int.tryParse(_target.text) ?? 5,
          'bonusXp': int.tryParse(_bonus.text) ?? 150,
          'durationDays': _durationDays,
        },
      });
      _snack('Nouveau défi publié dans l’application.');
    } catch (e) {
      _snack('Publication impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 64),
        children: [
          _AdminCard(
          title: 'Mission quotidienne',
          icon: Icons.today_rounded,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
                title: const Text('Activer les missions et récompenses'),
              ),
              TextField(
                controller: _dailyGoal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nombre d’activités par jour',
                  helperText:
                      'Une activité = leçon, quiz, simulation ou coach pédagogique.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _dailyBonus,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Bonus XP quotidien'),
              ),
            ],
          ),
        ),
          const SizedBox(height: 12),
          _AdminCard(
          title: 'Défi événementiel',
          icon: Icons.emoji_events_rounded,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _challengeEnabled,
                onChanged: (value) =>
                    setState(() => _challengeEnabled = value),
                title: const Text('Publier un défi spécial'),
              ),
              TextField(
                controller: _title,
                enabled: _challengeEnabled,
                decoration: const InputDecoration(labelText: 'Titre du défi'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                enabled: _challengeEnabled,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _metric,
                decoration: const InputDecoration(labelText: 'Objectif mesuré'),
                items: const [
                  DropdownMenuItem(value: 'quiz', child: Text('Quiz validés')),
                  DropdownMenuItem(
                    value: 'simulation',
                    child: Text('Simulations terminées', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'lesson',
                    child: Text('Leçons terminées', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'assistant',
                    child: Text('Recherches dans le coach', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(value: 'xp', child: Text('XP gagnés')),
                ],
                onChanged: _challengeEnabled
                    ? (value) => setState(() => _metric = value ?? _metric)
                    : null,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _target,
                enabled: _challengeEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Objectif à atteindre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bonus,
                enabled: _challengeEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Récompense XP'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: _durationDays,
                decoration: const InputDecoration(labelText: 'Durée'),
                items: const [
                  DropdownMenuItem(value: 3, child: Text('3 jours')),
                  DropdownMenuItem(value: 7, child: Text('7 jours')),
                  DropdownMenuItem(value: 14, child: Text('14 jours')),
                  DropdownMenuItem(value: 30, child: Text('30 jours')),
                ],
                onChanged: _challengeEnabled
                    ? (value) =>
                        setState(() => _durationDays = value ?? _durationDays)
                    : null,
              ),
            ],
          ),
        ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _publish,
            icon: const Icon(Icons.rocket_launch_rounded),
            label: const Text('Publier dans l’application'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _users = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await AdminService.instance.listUsers(query: _search.text);
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editTestAccess(Map<String, dynamic> user) async {
    var enabled = user['testPremium'] == true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Accès Premium de test'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${user['name'] ?? 'Utilisateur'}\n${user['email'] ?? ''}'),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: enabled,
                onChanged: (value) => setDialogState(() => enabled = value),
                title: const Text('Premium de test'),
                subtitle: const Text('N’altère pas un abonnement Google Play.'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                await AdminService.instance.setUserTestPremium(
                  uid: '${user['uid']}',
                  enabled: enabled,
                );
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Nom, email ou UID',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward_rounded)),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorRetry(error: _error, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final u = _users[index];
                          final premium = u['premium'] == true;
                          final admin = u['admin'] == true;
                          final displayName = '${u['name'] ?? 'Utilisateur'}';
                          final email = '${u['email'] ?? ''}';
                          final plan = '${u['plan'] ?? 'PREMIUM'}';
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(displayName.isEmpty
                                    ? '?'
                                    : displayName[0].toUpperCase()),
                              ),
                              title: Text(displayName,
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(email),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _SmallChip(premium ? plan : 'FREE', premium),
                                      if (u['testPremium'] == true) const _SmallChip('TEST', true),
                                      if (admin) const _SmallChip('ADMIN', true),
                                      if (((u['intensiveExamPasses'] as num?)?.toInt() ?? 0) > 0)
                                        _SmallChip(
                                          '${(u['intensiveExamPasses'] as num).toInt()} PASS',
                                          true,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                tooltip: 'Gérer accès test',
                                icon: const Icon(Icons.manage_accounts_rounded),
                                onPressed: () => _editTestAccess(u),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _CommunicationTab extends StatefulWidget {
  const _CommunicationTab();

  @override
  State<_CommunicationTab> createState() => _CommunicationTabState();
}

class _CommunicationTabState extends State<_CommunicationTab> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _image = TextEditingController();
  final _actionLabel = TextEditingController(text: 'En savoir plus');
  final _actionUrl = TextEditingController(
    text: 'https://play.google.com/store/apps/details?id=com.emploiboost.emploiboost',
  );
  final _minimumBuild = TextEditingController(text: '62');
  final _latestBuild = TextEditingController(text: '64');

  String _kind = 'announcement';
  String _displayMode = 'modal';
  String _audience = 'all';
  int _durationDays = 7;
  bool _dismissible = true;
  bool _forceUpdate = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await AdminService.instance.loadAppConfig();
      final raw = config['communication'];
      if (raw is! Map || !mounted) return;
      final c = Map<String, dynamic>.from(raw);
      setState(() {
        _title.text = '${c['title'] ?? ''}';
        _message.text = '${c['message'] ?? ''}';
        _image.text = '${c['imageUrl'] ?? ''}';
        _actionLabel.text = '${c['actionLabel'] ?? 'En savoir plus'}';
        _actionUrl.text = '${c['actionUrl'] ?? ''}';
        _minimumBuild.text = '${c['minimumBuild'] ?? 62}';
        _latestBuild.text = '${c['latestBuild'] ?? 62}';
        final loadedKind = '${c['kind'] ?? 'announcement'}';
        final loadedMode = '${c['displayMode'] ?? 'modal'}';
        final loadedAudience = '${c['audience'] ?? 'all'}';
        _kind = const {'announcement', 'update', 'maintenance'}
                .contains(loadedKind)
            ? loadedKind
            : 'announcement';
        _displayMode = const {'banner', 'modal', 'fullscreen'}
                .contains(loadedMode)
            ? loadedMode
            : 'modal';
        _audience = const {'all', 'free', 'premium'}
                .contains(loadedAudience)
            ? loadedAudience
            : 'all';
        _dismissible = c['dismissible'] != false;
        _forceUpdate = c['forceUpdate'] == true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _message,
      _image,
      _actionLabel,
      _actionUrl,
      _minimumBuild,
      _latestBuild,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      _snack('Ajoute un titre et un message.');
      return;
    }
    if (_forceUpdate && int.tryParse(_minimumBuild.text) == null) {
      _snack('Indique un numéro de build minimum valide.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AdminService.instance.publishCommunication({
        'enabled': true,
        'kind': _kind,
        'displayMode': _displayMode,
        'audience': _audience,
        'title': _title.text.trim(),
        'message': _message.text.trim(),
        'imageUrl': _image.text.trim(),
        'actionLabel': _actionLabel.text.trim(),
        'actionUrl': _actionUrl.text.trim(),
        'dismissible': _dismissible,
        'forceUpdate': _forceUpdate,
        'minimumBuild': int.tryParse(_minimumBuild.text) ?? 0,
        'latestBuild': int.tryParse(_latestBuild.text) ?? 0,
        'expiresInDays': _durationDays,
      });
      _snack('Communication publiée dans l’application.');
    } catch (e) {
      _snack('Publication impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    setState(() => _busy = true);
    try {
      await AdminService.instance.disableCommunication();
      _snack('Communication désactivée.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AdminCard(
          title: 'Créer une communication',
          icon: Icons.edit_notifications_rounded,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _kind,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'announcement', child: Text('Annonce / nouveauté')),
                  DropdownMenuItem(value: 'update', child: Text('Mise à jour de l’application')),
                  DropdownMenuItem(value: 'maintenance', child: Text('Maintenance / incident')),
                ],
                onChanged: (v) => setState(() {
                  _kind = v ?? _kind;
                  if (_kind == 'update') {
                    _actionLabel.text = 'Mettre à jour';
                    if (_actionUrl.text.trim().isEmpty) {
                      _actionUrl.text =
                          'https://play.google.com/store/apps/details?id=com.emploiboost.emploiboost';
                    }
                  }
                }),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _displayMode,
                decoration: const InputDecoration(labelText: 'Affichage'),
                items: const [
                  DropdownMenuItem(value: 'banner', child: Text('Bannière discrète')),
                  DropdownMenuItem(value: 'modal', child: Text('Fenêtre au centre')),
                  DropdownMenuItem(value: 'fullscreen', child: Text('Plein écran / flash')),
                ],
                onChanged: (v) => setState(() => _displayMode = v ?? _displayMode),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _audience,
                decoration: const InputDecoration(labelText: 'Public ciblé'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tous les utilisateurs')),
                  DropdownMenuItem(value: 'free', child: Text('Utilisateurs gratuits')),
                  DropdownMenuItem(value: 'premium', child: Text('Abonnés Premium')),
                ],
                onChanged: (v) => setState(() => _audience = v ?? _audience),
              ),
              const SizedBox(height: 10),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Titre')),
              const SizedBox(height: 10),
              TextField(
                controller: _message,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _image,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Lien de l’image (facultatif)'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _actionLabel, decoration: const InputDecoration(labelText: 'Texte du bouton')),
              const SizedBox(height: 10),
              TextField(
                controller: _actionUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Lien du bouton'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: _durationDays,
                decoration: const InputDecoration(labelText: 'Durée d’affichage'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 jour')),
                  DropdownMenuItem(value: 3, child: Text('3 jours')),
                  DropdownMenuItem(value: 7, child: Text('7 jours')),
                  DropdownMenuItem(value: 30, child: Text('30 jours')),
                  DropdownMenuItem(value: 0, child: Text('Sans date de fin')),
                ],
                onChanged: (v) => setState(() => _durationDays = v ?? 7),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _dismissible,
                onChanged: (v) => setState(() => _dismissible = v),
                title: const Text('L’utilisateur peut fermer le message'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _AdminCard(
          title: 'Réglages de mise à jour',
          icon: Icons.system_update_alt_rounded,
          child: Column(
            children: [
              TextField(
                controller: _latestBuild,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dernier build disponible',
                  helperText: 'La V2.2.1 correspond au build 64.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _minimumBuild,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Build minimum accepté'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _forceUpdate,
                onChanged: _kind == 'update'
                    ? (v) => setState(() {
                          _forceUpdate = v;
                          if (v) {
                            _displayMode = 'fullscreen';
                            _dismissible = false;
                          }
                        })
                    : null,
                title: const Text('Mise à jour obligatoire'),
                subtitle: const Text('Bloque uniquement les builds inférieurs au minimum.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _publish,
          icon: const Icon(Icons.publish_rounded),
          label: const Text('Publier maintenant'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _disable,
          icon: const Icon(Icons.visibility_off_rounded),
          label: const Text('Retirer le message actuel'),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _TestsTab extends StatefulWidget {
  const _TestsTab();

  @override
  State<_TestsTab> createState() => _TestsTabState();
}

class _TestsTabState extends State<_TestsTab> {
  late Future<DebugReport> _report;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => _report = DebugAdminService.getDebugReport();

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      setState(_refresh);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DebugReport>(
      future: _report,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final r = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AdminCard(
              title: 'Ton compte administrateur',
              icon: Icons.admin_panel_settings_rounded,
              child: Column(
                children: [
                  _InfoRow('Email', r.email ?? '—'),
                  _InfoRow('Premium effectif', r.isPremium ? 'OUI' : 'NON'),
                  _InfoRow('Plan', r.activePlan),
                  _InfoRow('Crédits simulation', '${r.simCredits}'),
                  _InfoRow('Quota texte', '${r.textCredits}'),
                  _InfoRow('Audio', '${r.audioSeconds} sec'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AdminCard(
              title: 'Tester les parcours',
              icon: Icons.science_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Ton rôle Admin donne automatiquement accès à toutes les fonctions Premium, sans achat et sans modifier les abonnements Google Play existants.',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.workspace_premium_rounded),
                        label: Text('Premium'),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.lock_outline_rounded),
                        label: Text('Gratuit'),
                      ),
                    ],
                    selected: {r.isPremium},
                    onSelectionChanged: _busy
                        ? null
                        : (selection) => _run(
                              () => DebugAdminService.setDevPremium(selection.first),
                              selection.first
                                  ? 'Aperçu Premium activé'
                                  : 'Aperçu utilisateur gratuit activé',
                            ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() => DebugAdminService.resetSimCredits(1), '1 crédit de test ajouté'),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Redonner 1 crédit simulation'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(DebugAdminService.resetDailyQuota, 'Quotas locaux réinitialisés'),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Réinitialiser les quotas'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(DebugAdminService.resetLocalPaywallStats, 'Statistiques locales réinitialisées'),
                    icon: const Icon(Icons.cleaning_services_rounded),
                    label: const Text('Réinitialiser le paywall local'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _AdminCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.black54))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String text;
  final bool active;
  const _SmallChip(this.text, this.active);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: active ? Colors.green.withOpacity(.12) : Colors.grey.withOpacity(.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: active ? Colors.green.shade800 : Colors.black54)),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.error, required this.onRetry});

  String _friendlyMessage() {
    final value = error;
    if (value is FirebaseFunctionsException) {
      switch (value.code) {
        case 'not-found':
          return 'Les nouvelles fonctions Admin ne sont pas encore déployées. '
              'Exécute : firebase deploy --only functions --project emploiboost';
        case 'permission-denied':
          return 'Ton compte est connecté, mais le rôle Admin n’est pas reconnu. '
              'Vérifie dans users/{ton UID} que admin est bien un booléen true, '
              'puis déconnecte-toi et reconnecte-toi.';
        case 'unauthenticated':
          return 'La session Firebase a expiré. Déconnecte-toi puis reconnecte-toi.';
        case 'unavailable':
        case 'internal':
          return 'Le service Firebase est momentanément indisponible. Vérifie ta '
              'connexion Internet puis appuie sur Réessayer.';
        default:
          return value.message ?? 'Le service Admin n’a pas pu être chargé.';
      }
    }
    return 'Le tableau Admin n’a pas pu être chargé. Vérifie la connexion et le '
        'déploiement des Functions, puis appuie sur Réessayer.';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const Icon(Icons.error_outline_rounded, size: 42),
        const SizedBox(height: 10),
        const Text(
          'Chargement impossible',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          _friendlyMessage(),
          textAlign: TextAlign.center,
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(height: 1.4),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      ],
    );
  }
}
