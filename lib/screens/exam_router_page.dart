import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/active_track_service.dart';
import 'exam_mode_page.dart';
import 'ntc_exam_mode_page.dart';

/// Choisit l'examen à partir du parcours demandé, du parcours mémorisé et de
/// la configuration RNCP. Un alias Firestore ne peut donc plus renvoyer par
/// erreur l'utilisateur NTC vers l'ancien examen CIP.
class ExamRouterPage extends StatefulWidget {
  final String? trackId;

  const ExamRouterPage({super.key, this.trackId});

  @override
  State<ExamRouterPage> createState() => _ExamRouterPageState();
}

class _ExamRouterPageState extends State<ExamRouterPage> {
  late Future<bool> _isNtcExam;

  @override
  void initState() {
    super.initState();
    _isNtcExam = _resolveExam();
  }

  Future<bool> _resolveExam() async {
    final trackId = await ActiveTrackService.resolve(
      requestedTrackId: widget.trackId,
      fallback: 'cip',
    );
    if (trackId == 'ntc') return true;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tracks')
          .doc(trackId)
          .get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final exam = data['exam'] is Map
          ? Map<String, dynamic>.from(data['exam'] as Map)
          : <String, dynamic>{};
      final fingerprint = [
        data['title'],
        data['shortTitle'],
        data['rncpReference'],
        exam['kind'],
      ].whereType<Object>().join(' ').toLowerCase();
      return fingerprint.contains('39063') ||
          fingerprint.contains('technico-commercial') ||
          fingerprint.contains('technico commercial') ||
          fingerprint.contains('ntc');
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isNtcExam,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == true
            ? const NtcExamModePage()
            : const ExamModePage();
      },
    );
  }
}
