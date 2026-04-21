// ignore_for_file: avoid_print

import 'dart:io';

/// Insere padding inferior nas listas e o import do helper, de forma conservadora.
void main(List<String> args) {
  final dry = args.contains('--dry-run');
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    print('Execute na raiz do projeto (pasta lib não encontrada).');
    exit(1);
  }

  const importLine =
      "import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';";

  var changedFiles = 0;
  for (final f in _dartFiles(lib)) {
    if (f.path.endsWith('list_scroll_padding.dart')) continue;

    var s = f.readAsStringSync();
    if (!s.contains('ListView')) continue;

    final original = s;

    if (!s.contains(importLine)) {
      s = _insertImport(s, importLine);
    }

    s = _patchListViews(s);

    if (s != original) {
      changedFiles++;
      if (!dry) {
        f.writeAsStringSync(s);
      }
      print(dry ? 'would change: ${f.path}' : 'changed: ${f.path}');
    }
  }
  print('Done. $changedFiles file(s).');
}

Iterable<File> _dartFiles(Directory d) sync* {
  for (final e in d.listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) yield e;
  }
}

String _insertImport(String source, String importLine) {
  final lines = source.split('\n');
  var lastImport = -1;
  for (var i = 0; i < lines.length; i++) {
    final t = lines[i].trimLeft();
    if (t.startsWith('import ') || t.startsWith('export ')) {
      lastImport = i;
    }
  }
  if (lastImport < 0) {
    return '$importLine\n\n$source';
  }
  lines.insert(lastImport + 1, importLine);
  return lines.join('\n');
}

String _patchListViews(String source) {
  const prefixes = ['ListView.builder(', 'ListView.separated(', 'ListView('];
  var out = source;
  for (final prefix in prefixes) {
    var start = 0;
    final sb = StringBuffer();
    while (true) {
      final i = out.indexOf(prefix, start);
      if (i < 0) {
        sb.write(out.substring(start));
        break;
      }
      // Evita casar "ListView(" dentro de "LancamentoListView(", etc.
      if (i > 0) {
        final prev = out.codeUnitAt(i - 1);
        if (prev == 0x24 || // $
            (prev >= 0x61 && prev <= 0x7a) ||
            (prev >= 0x41 && prev <= 0x5a) ||
            (prev >= 0x30 && prev <= 0x39) ||
            prev == 0x5f) {
          sb.write(out.substring(start, i + prefix.length));
          start = i + prefix.length;
          continue;
        }
      }
      sb.write(out.substring(start, i));
      final openParen = i + prefix.length - 1;
      final endCtor = _endOfBalancedParens(out, openParen);
      if (endCtor < 0) {
        sb.write(out.substring(i));
        break;
      }
      final ctor = out.substring(i, endCtor + 1);
      final patchedCtor = _patchListViewCtor(ctor, prefix);
      sb.write(patchedCtor);
      start = endCtor + 1;
    }
    out = sb.toString();
  }
  return out;
}

String _patchListViewCtor(String ctor, String prefix) {
  final innerStart = prefix.length; // após '('
  final innerEnd = ctor.length - 1; // antes de ')'
  if (innerEnd <= innerStart) return ctor;

  final head = ctor.substring(0, innerStart);
  final inner = ctor.substring(innerStart, innerEnd);
  final tail = ctor.substring(innerEnd);

  if (_hasPaddingParam(inner)) {
    return _upgradeConstPadding(head, inner, tail);
  }

  final insert =
      '\n      padding: EdgeInsets.only(bottom: listScrollBottomInset(context)),';
  return '$head$insert$inner$tail';
}

bool _hasPaddingParam(String inner) {
  final reg = RegExp(r'^\s*padding\s*:', multiLine: true);
  return reg.hasMatch(inner);
}

String _upgradeConstPadding(String head, String inner, String tail) {
  var s = inner;
  // padding: const EdgeInsets...  -> listViewPaddingWithBottomInset(context, const ...)
  s = s.replaceAllMapped(
    RegExp(
      r'padding\s*:\s*(const\s+EdgeInsets(?:\.[a-zA-Z]+)?(?:\([^)]*\))?)',
    ),
    (m) => 'padding: listViewPaddingWithBottomInset(context, ${m[1]})',
  );
  return '$head$s$tail';
}

/// [openParenIndex] aponta para '(' de ListView.xxx(
int _endOfBalancedParens(String s, int openParenIndex) {
  if (openParenIndex < 0 || openParenIndex >= s.length) return -1;
  if (s[openParenIndex] != '(') return -1;
  var depth = 0;
  for (var i = openParenIndex; i < s.length; i++) {
    final c = s[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}
