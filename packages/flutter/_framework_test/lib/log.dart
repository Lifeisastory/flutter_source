import 'package:logger/logger.dart';

/// Wraps [PrettyPrinter] and dims stack trace lines to gray.
class _StackGrayPrinter extends LogPrinter {
  static final _stackLine = RegExp(r'(?:\x1B\[[0-9;]+m)*\s*(?:│\s*)?#\d+\s+');
  static final _ansi = RegExp(r'\x1B\[[0-9;]*m');

  final PrettyPrinter _pretty = PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
  );

  @override
  List<String> log(LogEvent event) {
    return _pretty.log(event).map((line) {
      if (_stackLine.hasMatch(line)) {
        return '\x1B[90m${line.replaceAll(_ansi, '')}\x1B[0m';
      }
      return line;
    }).toList();
  }
}

class ModuleLogger {
  final String moduleName;
  final Logger _logger;

  ModuleLogger(this.moduleName)
    : _logger = Logger(printer: _StackGrayPrinter());

  String _prefix([String? tag]) =>
      tag != null ? '[$moduleName:$tag]' : '[$moduleName]';

  void i(String message, {String? tag}) =>
      _logger.i('${_prefix(tag)} $message');

  void d(String message, {String? tag}) =>
      _logger.d('${_prefix(tag)} $message');

  void w(String message, {String? tag}) =>
      _logger.w('${_prefix(tag)} $message');

  void e(String message, {String? tag}) =>
      _logger.e('${_prefix(tag)} $message');
}
