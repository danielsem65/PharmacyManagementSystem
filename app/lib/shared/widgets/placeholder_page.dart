import 'package:flutter/material.dart';

/// Temporary screen used until each module is implemented phase-by-phase.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    required this.phase,
  });

  final String title;
  final IconData icon;
  final String phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Module is being built in $phase',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}