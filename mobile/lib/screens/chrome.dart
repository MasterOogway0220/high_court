import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import '../ui.dart';
import 'notifications.dart';
import 'settings.dart';

/// The header the web app draws above every page: the mark, notifications with
/// an unread count, and the member's own avatar as the way into Settings.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.me, this.unread = 0});

  final Me me;
  final int unread;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 12),
    child: Row(
      children: [
        Container(
          height: 34,
          width: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.ink,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Text(
            'GH',
            style: TextStyle(
              fontFamily: 'Doto',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: C.onDark,
              height: 1,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text('GHCBA', style: T.eyebrow),
        const Spacer(),
        _CircleAction(
          icon: Icons.notifications_none_rounded,
          badge: unread,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NotificationsScreen(me: me)),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SettingsScreen(me: me)),
          ),
          child: Avatar(name: me.fullName, url: me.photoUrl, size: 34),
        ),
      ],
    ),
  );
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap, this.badge = 0});

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 34,
          width: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.surface,
            shape: BoxShape.circle,
            border: Border.all(color: C.separator, width: 0.5),
          ),
          child: Icon(icon, size: 18, color: C.ink2),
        ),
        if (badge > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: C.accent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.canvas, width: 1.5),
              ),
              child: Text(
                badge > 9 ? '9+' : '$badge',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Doto',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: C.onDark,
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
