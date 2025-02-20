## 0.2.4

* Exported `StringExtension`.
* Added an example with changing the language and the theme.

## 0.2.3

* Fixed removing listeners in `_CodeFieldState.dispose()`.

## 0.2.2

* Added `CodeController.lastTextSpan` field (visible for testing) to return the last `TextSpan`
produced by `buildTextSpan()`.

## 0.2.1

* Added the migration guide for 0.2 to README.

## 0.2.0

* **BREAKING:** Removed theme from `CodeController`. Use `CodeTheme` widget instead.
* **BREAKING:** Removed `webSpaceFix`, https://github.com/flutter/flutter/issues/77929
* **BREAKING:** Fixed typo `IntendModifier` → `IndentModifier`.
* **BREAKING:** `CodeFieldState` is now private.

## 0.1.15

* Added a missing code file.

## 0.1.14

* Python fallback parser preserves foldable blocks if `highlight` fails ([Issue 49](https://github.com/akvelon/flutter-code-editor/issues/49)).

## 0.1.13

* Remove an accidentally published temp file.

## 0.1.12

* Reformatted the license, updated README.

## 0.1.11

* Updated README.

## 0.1.10

* Fixed formatting.

## 0.1.9

* Read-only blocks are now pale ([Issue 103](https://github.com/akvelon/flutter-code-editor/issues/103)).

## 0.1.8

* Fixed linter issues.

## 0.1.7

* Fixed README errors.

## 0.1.6

* Improved README.

## 0.1.5

* Updated license formatting to match pub.dev requirements.

## 0.1.4
* Added `CodeController.readOnlySectionNames` getter and setter ([Issue 110](https://github.com/akvelon/flutter-code-editor/issues/110)).
* Added `CodeController.foldCommentAtLineZero`, `foldImports`, `foldOutsideSections` ([Issue 89](https://github.com/akvelon/flutter-code-editor/issues/89)).
* Added `CodeController.visibleSectionNames` ([Issue 27](https://github.com/akvelon/flutter-code-editor/issues/27)).
* Fixed folding Python blocks with multiline `if` conditions ([Issue 108](https://github.com/akvelon/flutter-code-editor/issues/108)).
* Fixed folding duplicate blocks like `[{...}]` etc ([Issue 99](https://github.com/akvelon/flutter-code-editor/issues/99)).
* Fixed `cutLineIndexIfVisible` bug ([Issue 112](https://github.com/akvelon/flutter-code-editor/issues/112)).

## 0.1.3

* Custom undo/redo implementation ([Issue 97](https://github.com/akvelon/flutter-code-editor/issues/97)).
* Remove `FoldableBlock` duplicates ([Issue 99](https://github.com/akvelon/flutter-code-editor/issues/99)).
* Copy folded text ([Issue 24](https://github.com/akvelon/flutter-code-editor/issues/24)).

## 0.1.2

* Preserve selection when folding and unfolding ([Issue 81](https://github.com/akvelon/flutter-code-editor/issues/81)).

## 0.1.1

* Added code folding.
* Fixed editing around hidden text ranges.
* Updated dependencies.

## 0.1.0

* Highlights unterminated blocks for Java and Python.

## 0.0.9

* Forked https://github.com/BertrandBev/code_field
* Re-license under the Apache license, mention the original author as the original license required.
* Added hidden service comment support.
* Added read-only blocks support.
* Added autocomplete for keywords, already-in-the-editor words, and external dictionary.
