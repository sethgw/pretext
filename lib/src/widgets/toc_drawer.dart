import 'package:flutter/material.dart';

import 'package:pretext/src/epub/epub_result.dart';

/// A drawer widget that displays an EPUB table of contents as a
/// navigable tree, with nested entries indented by depth.
class TocDrawer extends StatelessWidget {
  /// The table of contents entries to display.
  final List<TocEntry> entries;

  /// Called when the user taps a TOC entry.
  final void Function(TocEntry entry)? onEntryTapped;

  /// Optional book title displayed at the top of the drawer.
  final String? title;

  const TocDrawer({
    super.key,
    required this.entries,
    this.onEntryTapped,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title!,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(),
            ],
            Expanded(
              child: ListView(
                children: _buildEntries(context, entries, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEntries(
    BuildContext context,
    List<TocEntry> entries,
    int depth,
  ) {
    final widgets = <Widget>[];
    for (final entry in entries) {
      widgets.add(
        ListTile(
          contentPadding:
              EdgeInsets.only(left: 16.0 + depth * 16.0, right: 16),
          title: Text(entry.title),
          dense: depth > 0,
          onTap: () => onEntryTapped?.call(entry),
        ),
      );
      if (entry.children.isNotEmpty) {
        widgets.addAll(_buildEntries(context, entry.children, depth + 1));
      }
    }
    return widgets;
  }
}
