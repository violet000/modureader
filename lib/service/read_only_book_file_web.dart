import 'dart:io';

/// Web has no duplicated file descriptors. Callers receive a normal file.
File readOnlyBookFile(String path) => File(path);
