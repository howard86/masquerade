import 'package:flutter/cupertino.dart';

class ToolsHubPage extends StatelessWidget {
  const ToolsHubPage({super.key, required this.onToolSelected});

  /// Called with the tab index to switch to when a tool card is tapped.
  final void Function(int tabIndex) onToolSelected;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'Tools',
                style: CupertinoTheme.of(context)
                    .textTheme
                    .navLargeTitleTextStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _ToolCard(
                icon: CupertinoIcons.arrow_2_squarepath,
                name: 'Unit Converter',
                description: 'Convert units, timestamps & encodings',
                onTap: () => onToolSelected(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.name,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String name;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CupertinoColors.systemGrey4, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: CupertinoColors.systemBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(
                          color: CupertinoColors.secondaryLabel,
                          fontSize: 14,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
