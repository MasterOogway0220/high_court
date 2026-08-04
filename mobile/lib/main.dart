import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';
import 'screens/announcements.dart';
import 'screens/dashboard.dart';
import 'screens/directory.dart';
import 'screens/documents.dart';
import 'screens/events.dart';
import 'screens/login.dart';
import 'theme.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // anonKey, not publishableKey: this project still issues the legacy anon JWT,
  // which is what the web app sends. Switch both together, not one of them.
  // ignore: deprecated_member_use
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const GhcbaApp());
}

class GhcbaApp extends StatelessWidget {
  const GhcbaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GHCBA',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const AuthGate(),
  );
}

/// The session decides the screen. Supabase restores a stored session on launch,
/// so this also covers "already signed in" without a flash of the login form.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Session? _session;
  bool _ready = false;
  bool _demoFailed = false;

  @override
  void initState() {
    super.initState();
    _session = sb.auth.currentSession;
    sb.auth.onAuthStateChange.listen((state) {
      if (mounted) setState(() => _session = state.session);
    });
    _start();
  }

  Future<void> _start() async {
    // Supabase.initialize has already restored any stored session, so a null
    // one here means there is genuinely nobody signed in.
    if (_session == null && demoMode) {
      final ok = await Data.demoSignIn();
      // Attempted once, and once only. Retrying is what turns a wrong demo
      // password into an infinite loop instead of a legible failure.
      if (mounted && !ok) setState(() => _demoFailed = true);
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _Splash();
    if (_session != null) return const Shell();

    // Only reached when demo mode is off, or when it failed and the gate is
    // the honest thing to show.
    return LoginScreen(
      notice: _demoFailed
          ? 'Automatic demo sign-in failed. Sign in with your own credentials.'
          : null,
    );
  }
}

/// Shown while the session resolves. Branded rather than a bare spinner,
/// because in demo mode this is the first thing anyone sees.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.canvas,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 76,
              width: 76,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: C.ink),
                  const DotField(
                    gap: 7,
                    radius: 1.1,
                    color: Color(0x26FFFFFF),
                  ),
                  const Center(
                    child: Text(
                      'GH',
                      style: TextStyle(
                        fontFamily: 'Doto',
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: C.onDark,
                        height: 1,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text('GUWAHATI HIGH COURT', style: T.eyebrow),
          const SizedBox(height: 8),
          const Text('Bar Association', style: T.title3),
          const SizedBox(height: 26),
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: C.ink4),
          ),
        ],
      ),
    ),
  );
}

/// The five sections the web app puts in its mobile bar (see MOBILE in nav.tsx).
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => ShellState();

  static ShellState of(BuildContext context) =>
      context.findAncestorStateOfType<ShellState>()!;
}

class ShellState extends State<Shell> {
  int _tab = 0;
  Me? _me;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await Data.me();
      if (!mounted) return;
      // A session without a member row is not a usable state — the account
      // exists in auth but not on the roll. Send them back to the gate.
      if (me == null) {
        await Data.signOut();
        return;
      }
      setState(() => _me = me);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Lets any screen jump to a sibling tab (the dashboard's "View all" links).
  void go(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: C.canvas,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorState(
              'Could not load your membership record.',
              onRetry: () {
                setState(() => _error = null);
                _load();
              },
            ),
          ),
        ),
      );
    }

    final me = _me;
    if (me == null) {
      return const Scaffold(
        backgroundColor: C.canvas,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Scaffold(
      backgroundColor: C.canvas,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            DashboardScreen(me: me, onGo: go),
            AnnouncementsScreen(me: me),
            DirectoryScreen(me: me),
            EventsScreen(me: me),
            DocumentsScreen(me: me),
          ],
        ),
      ),
      bottomNavigationBar: _TabBar(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
    (Icons.campaign_outlined, Icons.campaign_rounded, 'Notices'),
    (Icons.people_outline_rounded, Icons.people_rounded, 'Directory'),
    (Icons.event_outlined, Icons.event_rounded, 'Events'),
    (Icons.folder_outlined, Icons.folder_rounded, 'Files'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: C.surface,
      border: Border(top: BorderSide(color: C.separator, width: 0.5)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        i == index ? _items[i].$2 : _items[i].$1,
                        size: 23,
                        color: i == index ? C.ink : C.ink4,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _items[i].$3,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          height: 1.1,
                          fontWeight: i == index
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: i == index ? C.ink : C.ink4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

