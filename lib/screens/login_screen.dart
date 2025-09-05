lib/screens/login_screen.dart          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 1.6),
        ),
      );

  Future<void> _guarded(Future<void> Function() run) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await run();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Firestore user doc
  Future<void> _createOrUpdateUserDoc(User u, {String? name}) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();

    await ref.set({
      'name': name ?? u.displayName ?? 'Invité',
      'email': u.email ?? '',
      'photoURL': u.photoURL ?? '',
    }, SetOptions(merge: true));

    if (!snap.exists) {
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'totalScore': 0,
        'chapters': {},
        'unlockedLevels': {},
        'unlockedModules': {},
        'lastChapterId': '',
        'scrollPositions': {},
      }, SetOptions(merge: true));
    }
  }

  // --- Email / Invité
  Future<void> _signInEmail() => _guarded(() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      await _createOrUpdateUserDoc(FirebaseAuth.instance.currentUser!);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur de connexion');
    }
  });

  Future<void> _signUpEmail() => _guarded(() async {
    if ([_name, _email, _pass].any((c) => c.text.isEmpty)) {
      _snack('Complète nom, email et mot de passe.');
      return;
    }
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      await _createOrUpdateUserDoc(cred.user!, name: _name.text.trim());
      _snack('Inscription réussie, connecte-toi 👍');
      setState(() {
        _loginMode = true;
        _pass.clear();
      });
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur inscription');
    }
  });

  Future<void> _guest() => _guarded(() async {
    try {
      final res = await FirebaseAuth.instance.signInAnonymously();
      await _createOrUpdateUserDoc(res.user!, name: 'Invité');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      _snack('Invité : ${e.message}');
    }
  });

  // --- Widgets utilitaires
  Widget _animatedGradientText(String text) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_bgCtrl.value);
        final g = LinearGradient(
          begin: Alignment(-1 + 2 * t, -1),
          end: Alignment(1 - 2 * t, 1),
          colors: const [
            Color(0xFF7C4DFF),
            Color(0xFF00BFA6),
            Color(0xFF7C4DFF),
          ],
        );
        return ShaderMask(
          shaderCallback: (r) => g.createShader(r),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
        );
      },
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onTap,
  }) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        final c1 = Color.lerp(const Color(0xFF7C4DFF), const Color(0xFF00BFA6), t)!;
        final c2 = Color.lerp(const Color(0xFF00BFA6), const Color(0xFF7C4DFF), t)!;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            scale: onTap == null ? 1.0 : 0.999 + 0.001 * sin(t * pi * 2),
            duration: const Duration(milliseconds: 150),
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c1, c2]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: c1.withOpacity(.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _ghostButton({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(.18)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(.92),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // --- Logo bounce
  Future<void> _bounceLogo() async {
    setState(() => _logoScale = 0.92);
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() => _logoScale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isWide = mq.size.width >= 800;
    final maxBodyWidth = min(520.0, mq.size.width - 32);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0F13),
      body: Stack(
        children: [
          // --- Fond dégradé animé
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (context, _) {
              final t = _bgCtrl.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.7 + 1.4 * t, -1),
                    end: Alignment(1, 0.8 - 1.2 * t),
                    colors: const [
                      Color(0xFF141726),
                      Color(0xFF0E0F13),
                      Color(0xFF141726),
                    ],
                  ),
                ),
              );
            },
          ),

          // --- Grain de verre / carte centrale
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBodyWidth),
                child: SingleChildScrollView(
                  padding:
                      EdgeInsets.symmetric(horizontal: isWide ? 24 : 18, vertical: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.04),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withOpacity(.06),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Logo + bounce
                            GestureDetector(
                              onTap: _bounceLogo,
                              child: AnimatedScale(
                                scale: _logoScale,
                                duration: const Duration(milliseconds: 160),
                                curve: Curves.easeOutCubic,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: min(120.0, mq.size.width * .28),
                                  height: min(120.0, mq.size.width * .28),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            _animatedGradientText(
                              _loginMode ? 'Connexion' : 'Créer un compte',
                            ),
                            const SizedBox(height: 20),

                            if (!_loginMode) ...[
                              TextField(
                                controller: _name,
                                textCapitalization: TextCapitalization.words,
                                style: const TextStyle(color: Colors.white),
                                decoration: _dec('Nom complet', icon: Icons.person),
                              ),
                              const SizedBox(height: 12),
                            ],

                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration:
                                  _dec('Email', icon: Icons.alternate_email_rounded),
                            ),
                            const SizedBox(height: 12),

                            TextField(
                              controller: _pass,
                              obscureText: _obscure,
                              style: const TextStyle(color: Colors.white),
                              decoration: _dec(
                                'Mot de passe',
                                icon: Icons.lock_outline,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            _primaryButton(
                              label: _loginMode ? 'Se connecter' : 'S’inscrire',
                              onTap: _loading
                                  ? null
                                  : (_loginMode ? _signInEmail : _signUpEmail),
                            ),
                            const SizedBox(height: 12),

                            _ghostButton(
                              label: _loginMode
                                  ? 'Créer un compte'
                                  : 'Déjà un compte ? Se connecter',
                              onTap: () => setState(() => _loginMode = !_loginMode),
                            ),

                            const SizedBox(height: 20),
                            Divider(color: Colors.white.withOpacity(.08)),
                            const SizedBox(height: 12),

                            _primaryButton(
                              label: 'Continuer en invité',
                              onTap: _loading ? null : _guest,
                            ),

                            const SizedBox(height: 16),
                            Text(
                              '© AI NEGO • RGPD',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(.60),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
