import 'package:flutter/material.dart';

class AppConversationHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const AppConversationHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.onMenu,
  });

  final String title;
  final String? subtitle;

  final VoidCallback? onBack;
  final VoidCallback? onMenu;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 24);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      leading: onBack == null
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: onBack,
            ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actions: [
        if (onMenu != null)
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: onMenu,
          ),
      ],
    );
  }
}
