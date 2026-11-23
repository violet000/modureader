class EmbeddingTokenizer {
  EmbeddingTokenizer.fromFile(String path) {
    throw UnsupportedError('Tokenizer is unavailable on this platform');
  }

  List<int> encode(String text) =>
      throw UnsupportedError('Tokenizer is unavailable on this platform');

  String truncateToTokens(String text, int maxTokens) =>
      throw UnsupportedError('Tokenizer is unavailable on this platform');

  void close() {}
}
