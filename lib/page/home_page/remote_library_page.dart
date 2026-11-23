import 'package:modu_reader/widgets/settings/setting_help_title.dart';
import 'package:modu_reader/utils/app_motion.dart';
import 'package:modu_reader/l10n/modu_strings.dart';
import 'package:modu_reader/widgets/home_navigation_metrics.dart';
import 'dart:convert';
import 'dart:io';

import 'package:modu_reader/page/settings_page/remote_library.dart';
import 'package:modu_reader/models/book.dart';
import 'package:modu_reader/providers/book_list.dart';
import 'package:modu_reader/service/book.dart';
import 'package:modu_reader/service/book_import_source.dart';
import 'package:modu_reader/widgets/bookshelf/book_import_picker.dart';
import 'package:modu_reader/utils/log/common.dart';
import 'package:modu_reader/utils/toast/common.dart';
import 'package:modu_reader/service/md5_service.dart';
import 'package:modu_reader/service/remote_library/webdav_library.dart';
import 'package:modu_reader/service/remote_library/library_view_options.dart';
import 'package:modu_reader/widgets/common/aurora_chrome.dart';
import 'package:modu_reader/service/remote_library/note_images.dart';
import 'package:modu_reader/widgets/markdown/remote_note_image.dart';
import 'package:modu_reader/widgets/markdown/styled_markdown.dart';
import 'package:modu_reader/widgets/remote_library_controls.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:modu_reader/utils/get_path/get_temp_dir.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RemoteLibraryPage extends ConsumerStatefulWidget {
  const RemoteLibraryPage({super.key, this.clientFactory});
  final WebdavLibrary Function(LibraryConnection)? clientFactory;
  @override
  ConsumerState<RemoteLibraryPage> createState() => _RemoteLibraryPageState();
}

class _RemoteLibraryPageState extends ConsumerState<RemoteLibraryPage> {
  WebdavLibrary? _client;
  Uri? _directory;
  List<LibraryEntry> _entries = [];
  (List<LibraryEntry>, LibraryViewOptions, String)? _visibleKey;
  List<LibraryEntry> _visibleEntries = [];
  CancelToken? _listing, _download;
  String? _error, _activeName;
  String _filter = '';
  LibraryViewOptions _viewOptions = const LibraryViewOptions();
  bool _loading = true, _importing = false;
  int _received = 0, _total = -1;
  final _imported = <String>{};
  bool get zh => Localizations.localeOf(context).languageCode == 'zh';
  String t(String cn, String en) => zh ? cn : en;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final options = await LibraryViewOptionsStore.load();
    if (!mounted) return;
    setState(() => _viewOptions = options);
    await _connect();
  }

  Future<void> _changeViewOptions(LibraryViewOptions options) async {
    setState(() => _viewOptions = options);
    try {
      await LibraryViewOptionsStore.save(options);
    } catch (_) {
      if (!mounted) return;
      _message(ModuStrings.text(context, '排序已生效，但无法保存到本机。',
          'Sorting applied, but preferences could not be saved.'));
    }
  }

  Future<void> _connect() async {
    _listing?.cancel();
    _client?.close();
    _client = null;
    setState(() {
      _loading = true;
      _entries = [];
      _directory = null;
      _error = null;
    });
    try {
      final connection = await LibraryConnectionStore.load();
      if (!mounted) return;
      if (connection != null) {
        _client =
            widget.clientFactory?.call(connection) ?? WebdavLibrary(connection);
      }
      if (_client == null) {
        setState(() => _loading = false);
      } else {
        await _browse(_client!.root);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = libraryError(error, zh, listing: true);
        });
      }
    }
  }

  Future<void> _browse(Uri directory) async {
    _listing?.cancel();
    final token = CancelToken();
    _listing = token;
    setState(() {
      _loading = true;
      _error = null;
      _directory = directory;
      _entries = [];
    });
    try {
      final entries = await _client!.list(directory, cancelToken: token);
      if (!mounted || token.isCancelled) return;
      setState(() {
        _entries = entries;
        _directory = directory;
      });
    } catch (error) {
      AnxLog.warning('Remote library listing failed: ${error.runtimeType}'
          '${error is LibraryListingException ? ' (${error.reason})' : ''}'
          '${error is DioException ? ', HTTP ${error.response?.statusCode}' : ''}');
      if (mounted && !token.isCancelled) {
        setState(() => _error = libraryError(error, zh, listing: true));
      }
    } finally {
      if (mounted && !token.isCancelled) setState(() => _loading = false);
    }
  }

  Future<void> _settings() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                appBar: AppBar(
                    title: Text(ModuStrings.text(
                        context, '远程书库设置', 'Remote library settings'))),
                body: const RemoteLibrarySettings())));
    if (mounted) await _connect();
  }

  void _message(String value) {
    if (mounted) AnxToast.show(value, context: context);
  }

  Future<File> _cachedCopy(LibraryEntry entry) async {
    final root = await getAnxTempDir();
    final safe =
        entry.name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
    var hash = 0x811c9dc5;
    for (final unit in entry.uri.toString().codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return File('${root.path}/modu-webdav-open/${hash.toRadixString(16)}/$safe');
  }

  bool _isTextNote(LibraryEntry entry) {
    final extension = entry.name.split('.').last.toLowerCase();
    return extension == 'txt' || extension == 'md' || extension == 'markdown';
  }

  /// Notes are fetched and shown in place. This path never writes a local
  /// file, so the browser is not blocked by the shelf download limit.
  Future<void> _openText(LibraryEntry entry) async {
    if (_activeName != null) return;
    final token = CancelToken();
    _download = token;
    setState(() {
      _activeName = entry.name;
      _received = 0;
      _total = entry.size ?? -1;
      _importing = false;
    });
    try {
      final bytes = await _client!.readBytes(entry, token);
      if (!mounted || token.isCancelled) return;
      final markdown = !entry.name.toLowerCase().endsWith('.txt');
      final body = markdown
          ? readableRemoteNote(utf8.decode(bytes, allowMalformed: true))
          : utf8.decode(bytes, allowMalformed: true);
      final library = _client;
      if (library == null) return;
      setState(() {
        _activeName = null;
        _download = null;
      });
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _RemoteNotePage(
              title: entry.name,
              body: body,
              markdown: markdown,
              noteUri: entry.uri,
              library: library)));
    } catch (error) {
      if (!mounted) return;
      _message(token.isCancelled
          ? t('已取消。', 'Cancelled.')
          : libraryError(error, zh));
    } finally {
      if (mounted && _download == token) {
        setState(() {
          _activeName = null;
          _importing = false;
          _download = null;
        });
      }
    }
  }

  /// Download into a local cache and open the reader. Nothing is added to the
  /// bookshelf; a copy already on the shelf is opened instead.
  Future<void> _openEntry(LibraryEntry entry) async {
    if (_activeName != null || !entry.isBook) return;
    if (_isTextNote(entry)) {
      await _openText(entry);
      return;
    }
    if (kIsWeb) {
      _message(t('浏览器里可以直接打开 Markdown 和纯文本。epub、pdf 等格式请用桌面版打开。',
          'This browser can open Markdown and plain text directly. Use the desktop app for epub, pdf and similar formats.'));
      return;
    }
    final token = CancelToken();
    _download = token;
    setState(() {
      _activeName = entry.name;
      _received = 0;
      _total = entry.size ?? -1;
      _importing = false;
    });
    try {
      final file = await _cachedCopy(entry);
      final complete = await file.exists() &&
          (entry.size == null || await file.length() == entry.size);
      if (!complete) {
        if (await file.exists()) await file.delete();
        final partial = File('${file.path}.part');
        if (await partial.exists()) await partial.delete();
        await file.parent.create(recursive: true);
        final progressClock = Stopwatch()..start();
        await _client!.download(entry, file, token, (received, total) {
          if (mounted &&
              (progressClock.elapsedMilliseconds >= 100 || received == total)) {
            progressClock.reset();
            setState(() {
              _received = received;
              _total = total;
            });
          }
        });
      }
      if (!mounted || token.isCancelled) return;
      final hash = await MD5Service.calculateFileMd5(file.path);
      final duplicate =
          hash == null ? null : await MD5Service.checkDuplicateByMd5(hash);
      if (!mounted) return;
      final onShelf = duplicate != null &&
          !duplicate.isDeleted &&
          File(duplicate.fileFullPath).existsSync();
      final book = onShelf
          ? duplicate
          : Book(
              id: -1,
              title: entry.name,
              coverPath: '',
              filePath: file.path,
              lastReadPosition: '',
              readingPercentage: 0,
              author: '',
              isDeleted: false,
              rating: 0,
              createTime: DateTime.now(),
              updateTime: DateTime.now(),
            );
      setState(() {
        _activeName = null;
        _download = null;
      });
      await pushToReadingPage(ref, context, book);
    } catch (error) {
      if (!mounted) return;
      _message(token.isCancelled
          ? t('已取消。', 'Cancelled.')
          : libraryError(error, zh));
    } finally {
      if (mounted && _download == token) {
        setState(() {
          _activeName = null;
          _importing = false;
          _download = null;
        });
      }
    }
  }

  Future<bool> _importEntry(
      LibraryEntry entry, WebdavLibrary client, CancelToken token) async {
    final container = ProviderScope.containerOf(context, listen: false);
    Directory? temporary;
    try {
      temporary = await (await getAnxTempDir()).createTemp('modu-webdav-');
      // URI-derived immediate-child names are checked by the service, and the
      // unique staging directory prevents clobbering a user's local book.
      final localName =
          entry.name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
      final file = File('${temporary.path}/$localName');
      final progressClock = Stopwatch()..start();
      await client.download(entry, file, token, (received, total) {
        if (mounted &&
            (progressClock.elapsedMilliseconds >= 100 || received == total)) {
          progressClock.reset();
          setState(() {
            _received = received;
            _total = total;
          });
        }
      });
      if (!mounted || token.isCancelled) throw StateError('Cancelled');
      setState(() => _importing = true);
      final hash = await MD5Service.calculateFileMd5(file.path);
      if (!mounted) throw StateError('Cancelled');
      final duplicate =
          hash == null ? null : await MD5Service.checkDuplicateByMd5(hash);
      if (!mounted) throw StateError('Cancelled');
      final alreadyPresent = duplicate != null &&
          !duplicate.isDeleted &&
          File(duplicate.fileFullPath).existsSync();
      if (!alreadyPresent) {
        await importBook(file, ref,
            onImported: () =>
                container.read(bookListProvider.notifier).refresh());
      }
      if (mounted) setState(() => _imported.add(entry.uri.toString()));
      return !alreadyPresent;
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    }
  }

  Future<void> _getFolder(Uri directory) async {
    if (_activeName != null) return;
    final client = _client!;
    final token = CancelToken();
    _download = token;
    setState(() {
      _activeName = t('扫描文件夹（含子文件夹）', 'Scanning folder (including subfolders)');
      _received = 0;
      _total = -1;
    });
    var added = 0, skipped = 0, failed = 0;
    String? lastFailure;
    try {
      final entries = await client.discoverBooks(directory, cancelToken: token);
      if (!mounted || token.isCancelled) return;
      if (entries.isEmpty) {
        _message(t('没有找到支持的书籍文件', 'No supported books found'));
        return;
      }
      final byId = {for (final e in entries) e.uri.toString(): e};
      final selected = await showDialog<List<BookImportEntry>>(
          context: context,
          animationStyle: AppMotion.style,
          builder: (_) => BookImportSelection(
              entries: entries
                  .map((e) => BookImportEntry(
                      id: e.uri.toString(),
                      name: e.name,
                      label: e.uri.pathSegments
                          .skip(directory.pathSegments.length - 1)
                          .join('/')))
                  .toList()));
      if (selected == null || !mounted || token.isCancelled) return;
      for (var i = 0; i < selected.length; i++) {
        if (!mounted || token.isCancelled) break;
        final entry = byId[selected[i].id]!;
        setState(() {
          _activeName = '${i + 1}/${selected.length} · ${entry.name}';
          _received = 0;
          _total = -1;
          _importing = false;
        });
        try {
          if (await _importEntry(entry, client, token)) {
            added++;
          } else {
            skipped++;
          }
        } catch (error) {
          if (token.isCancelled || !mounted) break;
          failed++;
          lastFailure = _importing
              ? t('书籍解析失败', 'Book import failed')
              : libraryError(error, zh);
        }
      }
      if (mounted) {
        _message(t(
            '${token.isCancelled ? '已取消。' : ''}导入 $added 本，重复跳过 $skipped 本，失败 $failed 本。${lastFailure ?? ''}',
            '${token.isCancelled ? 'Cancelled. ' : ''}Imported $added, skipped $skipped duplicates, failed $failed. ${lastFailure ?? ''}'));
      }
    } catch (error) {
      if (mounted) {
        _message(token.isCancelled
            ? t('已取消文件夹扫描。', 'Folder scan cancelled.')
            : libraryError(error, zh, listing: true));
      }
    } finally {
      if (mounted) {
        setState(() {
          _activeName = null;
          _importing = false;
          _download = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _listing?.cancel();
    _download?.cancel();
    _client?.close();
    super.dispose();
  }

  String _size(int? bytes) => bytes == null
      ? '—'
      : bytes < 1024
          ? '$bytes B'
          : bytes < 1024 * 1024
              ? '${(bytes / 1024).toStringAsFixed(1)} KiB'
              : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';

  String _entrySubtitle(LibraryEntry entry) {
    final info = entry.isDirectory
        ? ModuStrings.text(context, '文件夹', 'Folder')
        : '${_size(entry.size)}${entry.isBook ? '' : ModuStrings.text(context, ' · 不能直接打开', ' · Cannot open directly')}';
    final date = switch (_viewOptions.sort) {
      LibrarySortField.createdAt => entry.createdAt,
      LibrarySortField.modifiedAt => entry.modifiedAt,
      _ => null,
    };
    if (_viewOptions.sort != LibrarySortField.createdAt &&
        _viewOptions.sort != LibrarySortField.modifiedAt) {
      return info;
    }
    final label = _viewOptions.sort == LibrarySortField.createdAt
        ? ModuStrings.text(context, '添加', 'Added')
        : ModuStrings.text(context, '修改', 'Modified');
    return '$info · $label: ${date == null ? ModuStrings.text(context, '未提供', 'Not provided') : DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal())}';
  }

  @override
  Widget build(BuildContext context) {
    final directory = _directory;
    final root = _client?.root;
    final visibleKey = (_entries, _viewOptions, _filter);
    // Download progress must not re-sort a large directory on every repaint.
    if (_visibleKey != visibleKey) {
      _visibleKey = visibleKey;
      _visibleEntries = _viewOptions.apply(_entries, query: _filter);
    }
    final visible = _visibleEntries;
    final scheme = Theme.of(context).colorScheme;
    final title = ModuStrings.text(context, '远程书库', 'Remote library');
    return AuroraCanvas(
        child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Text(title),
            actions: [
              IconButton(
                  tooltip: t('导入当前文件夹', 'Import current folder'),
                  onPressed: _loading ||
                          _error != null ||
                          directory == null ||
                          _activeName != null
                      ? null
                      : () => _getFolder(directory),
                  icon: const Icon(Icons.drive_folder_upload_outlined)),
              IconButton(
                  tooltip: ModuStrings.text(context, '刷新', 'Refresh'),
                  onPressed: _loading
                      ? null
                      : () =>
                          directory == null ? _connect() : _browse(directory),
                  icon: const Icon(Icons.refresh_rounded)),
              IconButton(
                  tooltip: ModuStrings.text(
                      context, '远程书库设置', 'Remote library settings'),
                  onPressed: _activeName == null ? _settings : null,
                  icon: const Icon(Icons.settings_outlined)),
              const SizedBox(width: 8),
            ]),
        body: Column(children: [
          if (root != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                child: Row(children: [
                  IconButton(
                      tooltip: ModuStrings.text(context, '上一级', 'Parent folder'),
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                      onPressed: _loading ||
                              directory == null ||
                              directory == root
                          ? null
                          : () => _browse(directory.resolve('../'))),
                  TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _loading ? null : () => _browse(root),
                      child: Text(ModuStrings.text(context, '根目录', 'Root'))),
                  Expanded(
                      child: SelectableText(
                          directory == null
                              ? '/'
                              : '/${directory.pathSegments.skip(root.pathSegments.where((segment) => segment.isNotEmpty).length).join('/')}',
                          maxLines: 1,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant))),
                ])),
          if (root != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: TextField(
                    onChanged: (value) => setState(() => _filter = value),
                    decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 20, color: scheme.onSurfaceVariant),
                        hintText: ModuStrings.text(context, '筛选当前目录中的文件',
                            'Filter files in this folder'),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: scheme.primary, width: 1))))),
          if (root != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: RemoteLibraryControls(
                  options: _viewOptions, onChanged: _changeViewOptions),
            ),
          if (_activeName != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: GlassPanel(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                            child: Text(_importing
                                ? t('正在导入：$_activeName',
                                    'Importing: $_activeName')
                                : '$_activeName · ${_size(_received)} / ${_size(_total < 0 ? null : _total)}')),
                        TextButton(
                            onPressed:
                                _importing ? null : () => _download?.cancel(),
                            child:
                                Text(ModuStrings.text(context, '取消', 'Cancel')))
                      ]),
                      EinkStaticIndicator(
                          child: LinearProgressIndicator(
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(8),
                              value: _importing || _total <= 0
                                  ? null
                                  : (_received / _total).clamp(0, 1))),
                    ]))),
          Expanded(
              child: _loading
                  ? const Center(
                      child: EinkStaticIndicator(
                          child: CircularProgressIndicator()))
                  : _error != null
                      ? Center(
                          child: GlassPanel(
                              margin: const EdgeInsets.all(24),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.cloud_off_rounded,
                                        size: 42, color: scheme.primary),
                                    const SizedBox(height: 12),
                                    Text(_error!, textAlign: TextAlign.center),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                        onPressed: _activeName == null
                                            ? _settings
                                            : null,
                                        child: Text(ModuStrings.text(
                                            context,
                                            '检查连接设置',
                                            'Check connection settings')))
                                  ])))
                      : root == null
                          ? Center(
                              child: GlassPanel(
                                  margin: const EdgeInsets.all(24),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28, vertical: 32),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const GlowMark(
                                            icon: Icons.cloud_rounded, size: 48),
                                        const SizedBox(height: 16),
                                        Text(
                                            ModuStrings.text(
                                                context,
                                                '连接 WebDAV，浏览远程目录并将书籍下载到本地书架。',
                                                'Connect WebDAV to browse and import books into your local bookshelf.'),
                                            textAlign: TextAlign.center),
                                        const SizedBox(height: 18),
                                        FilledButton(
                                            onPressed: _settings,
                                            child: Text(ModuStrings.text(
                                                context,
                                                '配置书库 WebDAV',
                                                'Configure library WebDAV')))
                                      ])))
                          : visible.isEmpty
                              ? Center(
                                  child: Text(ModuStrings.text(
                                      context,
                                      '当前目录没有匹配的文件。',
                                      'No matching files in this folder.')))
                              : ListView.builder(
                                  padding: EdgeInsets.only(
                                      top: 4,
                                      bottom: 12 +
                                          MediaQuery.paddingOf(context).bottom +
                                          (_activeName == null
                                              ? HomeNavigationClearance.of(
                                                  context)
                                              : 0)),
                                  itemCount: visible.length,
                                  itemBuilder: (context, index) {
                                    final entry = visible[index];
                                    final imported = _imported
                                        .contains(entry.uri.toString());
                                    return _LibraryRow(
                                      key: ValueKey(
                                          'library-entry:${entry.uri}'),
                                      entry: entry,
                                      subtitle: _entrySubtitle(entry),
                                      imported: imported,
                                      busy: _activeName != null,
                                      onOpen: entry.isDirectory
                                          ? () => _browse(entry.uri)
                                          : entry.isBook
                                              ? () => _openEntry(entry)
                                              : null,
                                      onImportFolder: () =>
                                          _getFolder(entry.uri),
                                      onDownload: () => _openEntry(entry),
                                      importFolderTip:
                                          t('导入文件夹', 'Import folder'),
                                      importedTip: ModuStrings.text(context,
                                          '本次已导入', 'Imported this session'),
                                      downloadTip: ModuStrings.text(
                                          context, '打开', 'Open'),
                                    );
                                  })),
          if (_activeName != null)
            Padding(
                padding: EdgeInsets.fromLTRB(
                    8, 8, 8, 8 + HomeNavigationClearance.of(context)),
                child: SettingHelp(
                    title: Text(ModuStrings.text(context, "下载", "Download")),
                    description: Text(
                        ModuStrings.text(context, "下载完成前请保持此页打开。",
                            "Keep this page open until the download finishes."),
                        style: Theme.of(context).textTheme.bodySmall))),
        ])));
  }

}

class _LibraryRow extends StatefulWidget {
  const _LibraryRow({
    super.key,
    required this.entry,
    required this.subtitle,
    required this.imported,
    required this.busy,
    required this.onOpen,
    required this.onImportFolder,
    required this.onDownload,
    required this.importFolderTip,
    required this.importedTip,
    required this.downloadTip,
  });

  final LibraryEntry entry;
  final String subtitle;
  final bool imported;
  final bool busy;
  final VoidCallback? onOpen;
  final VoidCallback onImportFolder;
  final VoidCallback onDownload;
  final String importFolderTip;
  final String importedTip;
  final String downloadTip;

  @override
  State<_LibraryRow> createState() => _LibraryRowState();
}

class _LibraryRowState extends State<_LibraryRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = widget.entry;
    final icon = entry.isDirectory
        ? Icons.folder_rounded
        : entry.isBook
            ? Icons.menu_book_rounded
            : Icons.description_outlined;
    final tileColor = entry.isDirectory
        ? const Color(0xFFFFF4E0)
        : entry.isBook
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.onSurface.withValues(alpha: 0.06);
    final tint = entry.isDirectory
        ? const Color(0xFFB7791F)
        : entry.isBook
            ? scheme.primary
            : scheme.onSurfaceVariant;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: ColoredBox(
        color: _hover
            ? scheme.onSurface.withValues(alpha: 0.04)
            : Colors.transparent,
        child: Column(children: [
          ListTile(
            hoverColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tint, size: 20),
            ),
            title: Text(entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(widget.subtitle),
            onTap: widget.onOpen,
            trailing: entry.isDirectory
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        tooltip: widget.importFolderTip,
                        onPressed: widget.busy ? null : widget.onImportFolder,
                        icon: const Icon(Icons.download_rounded)),
                    Icon(Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant),
                  ])
                : !entry.isBook
                    ? null
                    : IconButton(
                        tooltip: widget.downloadTip,
                        onPressed: widget.busy ? null : widget.onDownload,
                        icon: const Icon(Icons.menu_book_outlined)),
          ),
          Divider(
            height: 1,
            indent: 60,
            endIndent: 20,
            color: scheme.outlineVariant,
          ),
        ]),
      ),
    );
  }
}

class _RemoteNotePage extends StatelessWidget {
  const _RemoteNotePage({
    required this.title,
    required this.body,
    required this.markdown,
    required this.noteUri,
    required this.library,
  });

  final String title;
  final String body;
  final bool markdown;
  final Uri noteUri;
  final WebdavLibrary library;

  @override
  Widget build(BuildContext context) {
    final name = title.replaceFirst(RegExp(r'\.(md|markdown|txt)$', caseSensitive: false), '');
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, 8, narrow ? 16 : 28, 32),
        children: [
          if (body.trim().isEmpty)
            Text(ModuStrings.text(context, '这篇笔记没有正文。', 'This note is empty.'))
          else if (markdown)
            StyledMarkdown(
              data: body,
              imageBuilder: (context, url, width, height) => RemoteNoteImage(
                url: url,
                noteUri: noteUri,
                library: library,
              ),
            )
          else
            SelectableText(body),
        ],
      ),
    );
  }
}
