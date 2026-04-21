// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

import 'dart:io';

/// 1) Remove listViewPaddingWithBottomInset(context, …) deixando só a expressão interna.
/// 2) Em cada ListView.*(, envolve apenas o primeiro `padding:` de topo (depth 0) ou insere padding.
void main() {
  final lib = Directory('lib');
  for (final f in lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((e) => e.path.endsWith('.dart'))) {
    if (f.path.contains('list_scroll_padding.dart')) continue;
    var s = f.readAsStringSync();
    if (!s.contains('ListView')) continue;
    final before = s;
    s = _stripAllWrappers(s);
    s = _patchAllListViews(s);
    s = _ensureImport(s);
    if (s != before) {
      f.writeAsStringSync(s);
      print('fixed: ${f.path}');
    }
  }
  print('done');
}

String _stripAllWrappers(String s) {
  const pat = 'listViewPaddingWithBottomInset(context, ';
  while (s.contains(pat)) {
    final i = s.indexOf(pat);
    final valueStart = i + pat.length;
    final valueEnd = _endOfDartExpr(s, valueStart);
    if (valueEnd < 0 || valueEnd + 1 >= s.length || s[valueEnd + 1] != ')') {
      print('strip fail at $i');
      break;
    }
    final inner = s.substring(valueStart, valueEnd + 1);
    s = s.replaceRange(i, valueEnd + 2, inner);
  }
  return s;
}

String _ensureImport(String source) {
  const line =
      "import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';";
  if (!source.contains('listViewPaddingWithBottomInset') &&
      !source.contains('listScrollBottomInset')) {
    return source;
  }
  if (source.contains(line)) return source;
  return _insertImport(source, line);
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

String _patchAllListViews(String source) {
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
      if (_isPrecededByIdChar(out, i)) {
        sb.write(out.substring(start, i + prefix.length));
        start = i + prefix.length;
        continue;
      }
      sb.write(out.substring(start, i));
      final openParen = i + prefix.length - 1;
      final closeParen = _endOfBalancedParens(out, openParen);
      if (closeParen < 0) {
        sb.write(out.substring(i));
        break;
      }
      final ctor = out.substring(i, closeParen + 1);
      final fixed = _fixListViewCtor(ctor, prefix);
      sb.write(fixed);
      start = closeParen + 1;
    }
    out = sb.toString();
  }
  return out;
}

bool _isPrecededByIdChar(String s, int i) {
  if (i <= 0) return false;
  final prev = s.codeUnitAt(i - 1);
  return prev == 0x24 || // $
      (prev >= 0x61 && prev <= 0x7a) ||
      (prev >= 0x41 && prev <= 0x5a) ||
      (prev >= 0x30 && prev <= 0x39) ||
      prev == 0x5f;
}

int _endOfBalancedParens(String s, int openParenIndex) {
  if (openParenIndex < 0 || openParenIndex >= s.length) return -1;
  if (s[openParenIndex] != '(') return -1;
  var depth = 0;
  for (var i = openParenIndex; i < s.length; i++) {
    if (s[i] == '(') {
      depth++;
    } else if (s[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

String _fixListViewCtor(String ctor, String prefix) {
  final innerStart = prefix.length;
  final innerEnd = ctor.length - 1;
  final head = ctor.substring(0, innerStart);
  var inner = ctor.substring(innerStart, innerEnd);
  final tail = ctor.substring(innerEnd);

  final firstPad = _firstTopLevelPadding(inner);
  if (firstPad != null) {
    final wrapped = _wrapPaddingValue(firstPad.valueExpr);
    inner =
        '${inner.substring(0, firstPad.valueStart)}$wrapped${inner.substring(firstPad.valueEnd + 1)}';
    return '$head$inner$tail';
  }

  const insert =
      '\n      padding: EdgeInsets.only(bottom: listScrollBottomInset(context)),';
  return '$head$insert$inner$tail';
}

class _PadMatch {
  final int valueStart;
  final int valueEnd;
  final String valueExpr;
  _PadMatch(this.valueStart, this.valueEnd, this.valueExpr);
}

_PadMatch? _firstTopLevelPadding(String inner) {
  var depth = 1;
  var brace = 0;
  var bracket = 0;
  for (var k = 0; k < inner.length; k++) {
    final c = inner[k];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
    } else if (c == '{') {
      brace++;
    } else if (c == '}') {
      brace--;
    } else if (c == '[') {
      bracket++;
    } else if (c == ']') {
      bracket--;
    } else if (depth == 1 &&
        brace == 0 &&
        bracket == 0 &&
        k + 7 <= inner.length &&
        inner.startsWith('padding', k) &&
        _paddingNameHere(inner, k)) {
      var j = k + 7;
      while (j < inner.length && inner[j] == ' ') j++;
      if (j >= inner.length || inner[j] != ':') continue;
      j++;
      while (j < inner.length && ' \t'.contains(inner[j])) j++;
      if (j >= inner.length) return null;
      final end = _endOfDartExpr(inner, j);
      return _PadMatch(j, end, inner.substring(j, end + 1));
    }
  }
  return null;
}

bool _paddingNameHere(String s, int k) {
  if (k > 0) {
    final prev = s.codeUnitAt(k - 1);
    if ((prev >= 0x61 && prev <= 0x7a) ||
        (prev >= 0x41 && prev <= 0x5a) ||
        (prev >= 0x30 && prev <= 0x39) ||
        prev == 0x5f) {
      return false;
    }
  }
  return true;
}

/// Expressão simples até vírgula de topo ou fim; suporta parênteses/chaves balanceados.
int _endOfDartExpr(String s, int start) {
  var p = 0;
  var b = 0;
  var br = 0;
  for (var k = start; k < s.length; k++) {
    final c = s[k];
    if (c == '(') {
      p++;
    } else if (c == ')') {
      p--;
      if (p < 0) return k - 1;
    } else if (c == '{') {
      b++;
    } else if (c == '}') {
      b--;
    } else if (c == '[') {
      br++;
    } else if (c == ']') {
      br--;
    } else if (c == ',' && p == 0 && b == 0 && br == 0) {
      return k - 1;
    }
  }
  return s.length - 1;
}

String _wrapPaddingValue(String expr) {
  final t = expr.trim();
  if (t.contains('listScrollBottomInset') ||
      t.contains('listViewPaddingWithBottomInset')) {
    return expr;
  }
  return 'listViewPaddingWithBottomInset(context, $t)';
}
