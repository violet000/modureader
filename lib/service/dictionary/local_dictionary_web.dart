import 'dart:typed_data';

import 'local_dictionary_shared.dart';

/// Web builds have no native SQLite. The reader can open; local dictionaries
/// stay unavailable instead of pulling `dart:ffi` into the browser compile.
class LocalDictionaryStore {
  LocalDictionaryStore(this.root);
  final String root;

  Future<List<LocalDictionary>> list() async => const [];

  Future<void> importFiles(List<String> paths, String name,
      {void Function(int count)? onProgress}) async {
    throw const DictionaryFailure('io');
  }

  Future<void> rename(String id, String name) async {
    throw const DictionaryFailure('io');
  }

  Future<void> enable(String id, bool enabled) async {
    throw const DictionaryFailure('io');
  }

  Future<void> delete(String id) async {
    throw const DictionaryFailure('io');
  }

  Future<List<DictionaryEntry>> lookup(String word,
          {Set<String>? dictionaryIds}) async =>
      const [];

  Future<Uint8List?> resource(String id, String name) async => null;
}
