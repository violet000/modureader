import 'package:modu_reader/l10n/modu_strings.dart';
import 'package:modu_reader/service/remote_library/library_view_options.dart';
import 'package:flutter/material.dart';

class RemoteLibraryControls extends StatelessWidget {
  const RemoteLibraryControls(
      {super.key, required this.options, required this.onChanged});
  final LibraryViewOptions options;
  final ValueChanged<LibraryViewOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    String sortLabel(LibrarySortField field) => switch (field) {
          LibrarySortField.name =>
            ModuStrings.text(context, '书名 / 文件名', 'Book / file name'),
          LibrarySortField.createdAt =>
            ModuStrings.text(context, '添加时间', 'Date added'),
          LibrarySortField.modifiedAt =>
            ModuStrings.text(context, '修改时间', 'Date modified'),
          LibrarySortField.size =>
            ModuStrings.text(context, '文件大小', 'File size'),
        };
    String filterLabel(LibraryFileFilter filter) => switch (filter) {
          LibraryFileFilter.all =>
            ModuStrings.text(context, '全部文件', 'All files'),
          LibraryFileFilter.books =>
            ModuStrings.text(context, '仅书籍', 'Books only'),
          _ => filter.name.toUpperCase(),
        };
    final scheme = Theme.of(context).colorScheme;
    final pill = BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: scheme.outlineVariant),
    );
    Widget menu<T>(ValueKey<String> key, T value, List<DropdownMenuItem<T>> items,
        ValueChanged<T?> onSelected) {
      return DecoratedBox(
        decoration: pill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              key: key,
              isDense: true,
              isExpanded: true,
              value: value,
              items: items,
              onChanged: onSelected,
            ),
          ),
        ),
      );
    }

    final sortMenu = menu<LibrarySortField>(
      const ValueKey('library-sort-field'),
      options.sort,
      [
        for (final field in LibrarySortField.values)
          DropdownMenuItem(
            value: field,
            child: Text(sortLabel(field), overflow: TextOverflow.ellipsis),
          ),
      ],
      (value) {
        if (value != null) onChanged(options.copyWith(sort: value));
      },
    );
    final filterMenu = menu<LibraryFileFilter>(
      const ValueKey('library-file-filter'),
      options.filter,
      [
        for (final filter in LibraryFileFilter.values)
          DropdownMenuItem(
            value: filter,
            child: Text(filterLabel(filter), overflow: TextOverflow.ellipsis),
          ),
      ],
      (value) {
        if (value != null) onChanged(options.copyWith(filter: value));
      },
    );
    final directionLabel = options.ascending
        ? ModuStrings.text(context, '升序', 'Ascending')
        : ModuStrings.text(context, '降序', 'Descending');
    final direction = Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        key: const ValueKey('library-sort-direction'),
        onTap: () => onChanged(options.copyWith(ascending: !options.ascending)),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(children: [
            Icon(
                options.ascending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 18,
                color: scheme.onSurface),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                directionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurface),
              ),
            ),
          ]),
        ),
      ),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(flex: 5, child: sortMenu),
        const SizedBox(width: 6),
        Expanded(flex: 4, child: direction),
        const SizedBox(width: 6),
        Expanded(flex: 4, child: filterMenu),
      ]),
      if (options.sort == LibrarySortField.createdAt ||
          options.sort == LibrarySortField.modifiedAt)
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              options.sort == LibrarySortField.createdAt
                  ? ModuStrings.text(context, '添加时间使用服务器创建时间；未提供的排在末尾。',
                      'Date added uses server creation time; missing dates sort last.')
                  : ModuStrings.text(context, '使用服务器修改时间；未提供的排在末尾。',
                      'Uses server modification time; missing dates sort last.'),
              style: Theme.of(context).textTheme.bodySmall,
            )),
    ]);
  }
}
