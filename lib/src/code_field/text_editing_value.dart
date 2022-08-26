import 'package:flutter/widgets.dart';

import '../code/reg_exp.dart';
import '../code/text_range.dart';

extension ReplacedSelection on TextEditingValue {
  /// The position where the word at the cursor starts.
  /// `null` for a non-collapsed selection.
  int? get wordAtCursorStart {
    final startEnd = _getWordAtCursorStartEnd();
    if (startEnd == null) {
      return null;
    }

    final start = startEnd[0];
    final end = startEnd[1];

    return end > start ? start : null;
  }

  /// The word at the cursor, including if it is on either side of the cursor.
  /// `null` for a non-collapsed selection.
  String? get wordAtCursor {
    final startEnd = _getWordAtCursorStartEnd();
    if (startEnd == null) {
      return null;
    }

    final start = startEnd[0];
    final end = startEnd[1];

    return end > start ? text.substring(start, end) : null;
  }

  List<int>? _getWordAtCursorStartEnd() {
    if (!selection.isCollapsed) {
      return null;
    }

    final cursorPosition = selection.normalized.start;
    if (cursorPosition < 0) {
      return null;
    }

    final text = this.text;
    final start = cursorPosition > 0
        ? text.lastIndexOf(RegExps.wordSplit, cursorPosition - 1) + 1
        : 0;
    final firstNonWord = text.indexOf(RegExps.wordSplit, cursorPosition);
    final end = firstNonWord == -1 ? text.length : firstNonWord;

    return [start, end];
  }

  /// The part of the word at the cursor from start to the cursor.
  /// `null` for a non-collapsed selection.
  String? get wordToCursor {
    if (!selection.isCollapsed) {
      return null;
    }

    final cursorPosition = selection.normalized.start;
    if (cursorPosition <= 0) {
      return null;
    }

    final text = this.text;
    final splitPosition = text.lastIndexOf(
      RegExps.wordSplit,
      cursorPosition,
    );

    if (splitPosition == cursorPosition) {
      // On a split symbol. Including just after a word.
      return null;
    }

    final result = text.substring(splitPosition + 1, cursorPosition);
    return result.isEmpty ? null : result;
  }

  TextEditingValue replacedSelection(String value) {
    return replaced(selection, value);
  }
}
