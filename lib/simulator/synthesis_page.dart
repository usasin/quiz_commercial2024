import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/cip_colors.dart';
import '../services/openai_roleplay_service.dart';

class SynthesisPage extends StatefulWidget {
  final String scenarioId;
  final Map<String, dynamic> persona;
  final List<Map<String, String>> transcript;
  final OpenAiRoleplayService service;

  const SynthesisPage({
    super.key,
    required this.scenarioId,
    required this.persona,
    required this.transcript,
    required this.service,
  });

  @override
  State<SynthesisPage> createState() => _SynthesisPageState();
}

class _SynthesisPageState extends State<SynthesisPage> {
  final _synthCtrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _synthCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _synthCtrl.text.trim().length >= 40;

  List<String> _safeList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    return const [];
  }

  int _safeInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _safeStr(dynamic v) => (v ?? '').toString();

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    if (_loading) return;

    final text = _synthCtrl.text.trim();
    if (text.length < 40) {
      _snack("Écris une synthèse plus complète avant de valider.");
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await widget.service.correctSynthesis(
        scenarioId: widget.scenarioId,
        persona: widget.persona,
        transcript: widget.transcript,
        synthesisText: text,
      );
      if (!mounted) return;
      setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      _snack("Erreur: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _shareText() {
    final r = _result ?? const {};
    final note = _safeInt(r['note']);
    final ok = _safeList(r['ok']);
    final bad = _safeList(r['a_corriger']);
    final prop = _safeStr(r['proposition']).trim();

    final b = StringBuffer();
    b.writeln("📌 Synthèse — Feedback écrit");
    b.writeln("Note : $note/100");

    if (ok.isNotEmpty) {
      b.writeln("");
      b.writeln("✅ OK :");
      for (final x in ok.take(8)) b.writeln("• $x");
    }

    if (bad.isNotEmpty) {
      b.writeln("");
      b.writeln("⚠️ À corriger :");
      for (final x in bad.take(8)) b.writeln("• $x");
    }

    if (prop.isNotEmpty) {
      b.writeln("");
      b.writeln("✍️ Proposition :");
      b.writeln(prop);
    }

    b.writeln("");
    b.writeln("— EmploiBoost");
    return b.toString().trim();
  }

  Future<void> _copy() async {
    if (_result == null) return;
    await Clipboard.setData(ClipboardData(text: _shareText()));
    if (!mounted) return;
    _snack("Copié ✅");
  }

  Future<void> _share() async {
    if (_result == null) return;
    await Share.share(_shareText());
  }

  void _reset() => setState(() => _result = null);

  @override
  Widget build(BuildContext context) {
    final r = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Synthèse (écrit)"),
        backgroundColor: cipDark,
        foregroundColor: Colors.white,
        actions: [
          if (r != null) ...[
            IconButton(tooltip: "Copier", onPressed: _copy, icon: const Icon(Icons.copy_rounded)),
            IconButton(tooltip: "Partager", onPressed: _share, icon: const Icon(Icons.ios_share_rounded)),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 6))],
            ),
            child: const Text(
              "Écris ta synthèse d’entretien.\n\n"
                  "⚠️ Le feedback écrit apparaît uniquement après validation.",
              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _synthCtrl,
            enabled: !_loading,
            minLines: 10,
            maxLines: 20,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText:
              "Structure conseillée :\n"
                  "• Contexte / cadre\n"
                  "• Demande\n"
                  "• Infos factuelles\n"
                  "• Freins / atouts\n"
                  "• Urgences\n"
                  "• Suite (RDV / actions / docs)",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          if (r == null) ...[
            ElevatedButton.icon(
              onPressed: _loading ? null : (_canSubmit ? _submit : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: cipGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: const Text("Valider & Corriger"),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _reset,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text("Modifier"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cipBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _share,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text("Partager"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy_rounded),
                label: const Text("Copier"),
              ),
            ),
          ],
          if (r != null) ...[
            const SizedBox(height: 16),
            _resultCard(r),
          ],
        ],
      ),
    );
  }

  Widget _resultCard(Map<String, dynamic> r) {
    final note = _safeInt(r['note']);
    final ok = _safeList(r['ok']);
    final bad = _safeList(r['a_corriger']);
    final prop = _safeStr(r['proposition']).trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text("Feedback écrit", style: TextStyle(fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: cipGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                child: Text("$note/100", style: const TextStyle(fontWeight: FontWeight.w900, color: cipGreen)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text("✅ OK", style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          if (ok.isEmpty) const Text("—", style: TextStyle(color: Color(0xFF6B7280))),
          for (final x in ok.take(8)) Text("• $x"),
          const SizedBox(height: 10),
          const Text("⚠️ À corriger", style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          if (bad.isEmpty) const Text("—", style: TextStyle(color: Color(0xFF6B7280))),
          for (final x in bad.take(8)) Text("• $x"),
          if (prop.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text("✍️ Proposition", style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(prop),
          ],
        ],
      ),
    );
  }
}
