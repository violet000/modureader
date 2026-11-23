import 'dart:ffi';

String currentProcessAbi() => Abi.current().toString();
