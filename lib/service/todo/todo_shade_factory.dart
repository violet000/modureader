import 'package:modu_reader/service/todo/todo_shade.dart';
import 'package:modu_reader/service/todo/todo_shade_stub.dart'
    if (dart.library.io) 'package:modu_reader/service/todo/todo_shade_io.dart';

TodoShade createPlatformTodoShade() => createTodoShade();
