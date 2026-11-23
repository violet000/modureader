import 'package:hf_tokenizers/hf_tokenizers.dart' as hf;

class EmbeddingTokenizer {
  EmbeddingTokenizer._(this._inner);

  final hf.Tokenizer _inner;

  factory EmbeddingTokenizer.fromFile(String path) =>
      EmbeddingTokenizer._(hf.Tokenizer.fromFile(path));

  List<int> encode(String text) => _inner.encode(text);

  String truncateToTokens(String text, int maxTokens) =>
      _inner.truncateToTokens(text, maxTokens);

  void close() => _inner.close();
}
