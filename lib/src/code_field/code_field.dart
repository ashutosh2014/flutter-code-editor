import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../code_theme/code_theme.dart';
import '../gutter/gutter.dart';
import '../line_numbers/line_number_style.dart';
import '../sizes.dart';
import '../wip/autocomplete/popup.dart';
import 'actions/comment_uncomment.dart';
import 'actions/indent.dart';
import 'actions/outdent.dart';
import 'code_controller.dart';

final _shortcuts = <ShortcutActivator, Intent>{
  // Copy
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyC,
  ): CopySelectionTextIntent.copy,
  const SingleActivator(
    LogicalKeyboardKey.keyC,
    meta: true,
  ): CopySelectionTextIntent.copy,
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.insert,
  ): CopySelectionTextIntent.copy,

  // Cut
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyX,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  const SingleActivator(
    LogicalKeyboardKey.keyX,
    meta: true,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.delete,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),

  // Undo
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyZ,
  ): const UndoTextIntent(SelectionChangedCause.keyboard),
  const SingleActivator(
    LogicalKeyboardKey.keyZ,
    meta: true,
  ): const UndoTextIntent(SelectionChangedCause.keyboard),

  // Redo
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(SelectionChangedCause.keyboard),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(SelectionChangedCause.keyboard),

  // Indent
  LogicalKeySet(
    LogicalKeyboardKey.tab,
  ): const IndentIntent(),

  // Outdent
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.tab,
  ): const OutdentIntent(),

  // Comment Uncomment
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.slash,
  ): const CommentUncommentIntent(),
  const SingleActivator(
    LogicalKeyboardKey.slash,
    meta: true,
  ): const CommentUncommentIntent(),
};

class CodeField extends StatefulWidget {
  /// {@macro flutter.widgets.textField.minLines}
  final int? minLines;

  /// {@macro flutter.widgets.textField.maxLInes}
  final int? maxLines;

  /// {@macro flutter.widgets.textField.expands}
  final bool expands;

  /// Whether overflowing lines should wrap around or make the field scrollable horizontally
  final bool wrap;

  /// A CodeController instance to apply language highlight, themeing and modifiers
  final CodeController controller;

  /// A LineNumberStyle instance to tweak the line number column styling
  final LineNumberStyle lineNumberStyle;

  /// {@macro flutter.widgets.textField.cursorColor}
  final Color? cursorColor;

  /// {@macro flutter.widgets.textField.textStyle}
  final TextStyle? textStyle;

  /// A way to replace specific line numbers by a custom TextSpan
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;

  /// {@macro flutter.widgets.textField.enabled}
  final bool? enabled;

  /// {@macro flutter.widgets.editableText.onChanged}
  final void Function(String)? onChanged;

  /// {@macro flutter.widgets.editableText.readOnly}
  final bool readOnly;

  final Color? background;
  final EdgeInsets padding;
  final Decoration? decoration;
  final TextSelectionThemeData? textSelectionTheme;
  final FocusNode? focusNode;
  final bool lineNumbers;
  final EdgeInsets? codeFieldPadding;
  final BoxDecoration? numbersTabDecoration;
  final FixedColumnWidth? fixedColumnWidth;

  const CodeField({
    super.key,
    required this.controller,
    this.minLines,
    this.maxLines,
    this.expands = false,
    this.wrap = false,
    this.background,
    this.decoration,
    this.textStyle,
    this.padding = EdgeInsets.zero,
    this.lineNumberStyle = const LineNumberStyle(),
    this.enabled,
    this.readOnly = false,
    this.cursorColor,
    this.textSelectionTheme,
    this.lineNumberBuilder,
    this.focusNode,
    this.onChanged,
    this.lineNumbers = true,
    this.numbersTabDecoration,
    this.codeFieldPadding,
    this.fixedColumnWidth,
  });

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  // Add a controller
  LinkedScrollControllerGroup? _controllers;
  ScrollController? _numberScroll;
  ScrollController? _codeScroll;
  ScrollController? _horizontalCodeScroll;
  final _codeFieldKey = GlobalKey();

  Offset _normalPopupOffset = Offset.zero;
  Offset _flippedPopupOffset = Offset.zero;
  double painterWidth = 0;
  double painterHeight = 0;

  StreamSubscription<bool>? _keyboardVisibilitySubscription;
  FocusNode? _focusNode;
  String? lines;
  String longestLine = '';
  late Size windowSize;
  late TextStyle textStyle;
  bool enterText = false;

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _numberScroll = _controllers?.addAndGet();
    _codeScroll = _controllers?.addAndGet();

    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_updatePopupOffset);
    _horizontalCodeScroll = ScrollController();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode!.attach(context, onKeyEvent: _onKeyEvent);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final double width = _codeFieldKey.currentContext!.size!.width;
      final double height = _codeFieldKey.currentContext!.size!.height;
      windowSize = Size(width, height);
    });
    _onTextChanged();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    return widget.controller.onKey(event);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.controller.removeListener(_updatePopupOffset);
    _numberScroll?.dispose();
    _codeScroll?.dispose();
    _horizontalCodeScroll?.dispose();
    _keyboardVisibilitySubscription?.cancel();
    super.dispose();
  }

  void rebuild() {
    setState(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // For some reason _codeFieldKey.currentContext is null in tests
        // so check first.
        final context = _codeFieldKey.currentContext;
        if (context != null) {
          final double width = context.size!.width;
          final double height = context.size!.height;
          windowSize = Size(width, height);
        }
      });
    });
  }

  void _onTextChanged() {
    // Rebuild line number
    final str = widget.controller.text.split('\n');
    final buf = <String>[];

    for (var k = 0; k < str.length; k++) {
      buf.add((k + 1).toString());
    }

    // Find longest line
    longestLine = '';
    widget.controller.text.split('\n').forEach((line) {
      if (line.length > longestLine.length) longestLine = line;
    });

    rebuild();
  }

  // Wrap the codeField in a horizontal scrollView
  Widget _wrapInScrollView(
      Widget codeField,
      TextStyle textStyle,
      double minWidth,
      ) {
    final intrinsic = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 0,
              minWidth: minWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(longestLine, style: textStyle),
            ), // Add extra padding
          ),
          widget.expands ? Expanded(child: codeField) : codeField,
        ],
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        right: widget.padding.right,
      ),
      scrollDirection: Axis.horizontal,
      controller: _horizontalCodeScroll,
      child: intrinsic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Default color scheme
    const rootKey = 'root';
    final defaultBg = Colors.grey.shade900;
    final defaultText = Colors.grey.shade200;

    final themeData = Theme.of(context);
    final styles = CodeTheme.of(context)?.styles;
    Color? backgroundCol =
        widget.background ?? styles?[rootKey]?.backgroundColor ?? defaultBg;

    if (widget.decoration != null) {
      backgroundCol = null;
    }

    final defaultTextStyle = TextStyle(
      color: styles?[rootKey]?.color ?? defaultText,
      fontSize: themeData.textTheme.subtitle1?.fontSize,
    );

    textStyle = defaultTextStyle.merge(widget.textStyle);

    final lineNumberSize = textStyle.fontSize;
    final lineNumberColor = widget.lineNumberStyle.textStyle?.color ??
        textStyle.color?.withOpacity(.5);

    final lineNumberTextStyle =
    (widget.lineNumberStyle.textStyle ?? textStyle).copyWith(
      color: lineNumberColor,
      fontFamily: textStyle.fontFamily,
      fontSize: lineNumberSize,
    );

    final lineNumberStyle = widget.lineNumberStyle.copyWith(
      textStyle: lineNumberTextStyle,
    );

    Widget? numberCol;

    if (widget.lineNumbers) {
      numberCol = GutterWidget(
        codeController: widget.controller,
        style: lineNumberStyle,
        fixedColumnWidth: widget.fixedColumnWidth,
      );
      if (widget.numbersTabDecoration != null) {
        numberCol = SizedBox(
            height: double.maxFinite,
            child: DecoratedBox(
              decoration: widget.numbersTabDecoration!,
              child: numberCol,
            ));
      }
    }

    final codeField = TextField(
      contextMenuBuilder: (
          BuildContext context,
          EditableTextState editableTextState,
          ) {
        return AdaptiveTextSelectionMainToolbar(
          anchors: editableTextState.contextMenuAnchors,
          children: editableTextState.contextMenuButtonItems
              .map<Widget>((ContextMenuButtonItem buttonItem) {
            // buttonItem.type.
            return SizedBox(
              height: 24,
              width: 100,
              child: TextButton(
                onPressed: buttonItem.onPressed,
                style: ButtonStyle(
                  backgroundColor: const MaterialStatePropertyAll(Colors.transparent),
                  padding: MaterialStatePropertyAll(EdgeInsets.only(
                    right: CupertinoTextSelectionToolbarButton.getButtonLabel(
                        context, buttonItem) ==
                        'Cut'
                        ? 60
                        : CupertinoTextSelectionToolbarButton.getButtonLabel(
                        context, buttonItem) ==
                        'Paste'
                        ? 47
                        : 50,),
                  ),
                  overlayColor: const MaterialStatePropertyAll(Colors.transparent),
                ),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return MouseRegion(
                      onEnter: (_) {
                        setState(() {
                          enterText = true;
                        });
                      },
                      onExit: (_) {
                        setState(() {
                          enterText = false;
                        });
                      },
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        CupertinoTextSelectionToolbarButton.getButtonLabel(
                            context, buttonItem),
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: enterText ? Colors.white70 : Colors.white),
                      ),
                    );
                  },
                  // ),
                ),
              ),
            );
          }).toList(),
        );
      },
      focusNode: _focusNode,
      scrollPadding: widget.padding,
      style: textStyle,
      controller: widget.controller,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      expands: widget.expands,
      scrollController: _codeScroll,
      decoration: InputDecoration(
        isCollapsed: true,
        contentPadding:
        widget.codeFieldPadding ?? const EdgeInsets.symmetric(vertical: 16),
        disabledBorder: InputBorder.none,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      cursorColor: widget.cursorColor ?? defaultTextStyle.color,
      autocorrect: false,
      enableSuggestions: false,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      readOnly: widget.readOnly,
      cursorHeight: 19,
    );

    final editingField = Theme(
      data: Theme.of(context).copyWith(
          textSelectionTheme: widget.textSelectionTheme,
          canvasColor: Colors.green),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Control horizontal scrolling
          return _wrapInScrollView(codeField, textStyle, constraints.maxWidth);
        },
      ),
    );

    return FocusableActionDetector(
      actions: widget.controller.actions,
      shortcuts: _shortcuts,
      child: Container(
        decoration: widget.decoration,
        color: backgroundCol,
        key: _codeFieldKey,
        padding: !widget.lineNumbers ? const EdgeInsets.only(left: 8) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.lineNumbers && numberCol != null) numberCol,
            Expanded(
              child: Stack(
                children: [
                  editingField,
                  // if (widget.controller.popupController.isPopupShown)
                  //   Popup(
                  //     normalOffset: _normalPopupOffset,
                  //     flippedOffset: _flippedPopupOffset,
                  //     controller: widget.controller.popupController,
                  //     editingWindowSize: windowSize,
                  //     style: textStyle,
                  //     backgroundColor: backgroundCol,
                  //     parentFocusNode: _focusNode!,
                  //   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updatePopupOffset() {
    final TextPainter textPainter = _getTextPainter(widget.controller.text);
    final caretHeight = _getCaretHeight(textPainter);

    final double leftOffset = _getPopupLeftOffset(textPainter);
    final double normalTopOffset = _getPopupTopOffset(textPainter, caretHeight);
    final double flippedTopOffset = normalTopOffset -
        (Sizes.autocompletePopupMaxHeight + caretHeight + Sizes.caretPadding);

    setState(() {
      _normalPopupOffset = Offset(leftOffset, normalTopOffset);
      _flippedPopupOffset = Offset(leftOffset, flippedTopOffset);
    });
  }

  TextPainter _getTextPainter(String text) {
    return TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: text, style: textStyle),
    )..layout();
  }

  Offset _getCaretOffset(TextPainter textPainter) {
    return textPainter.getOffsetForCaret(
      widget.controller.selection.base,
      Rect.zero,
    );
  }

  double _getCaretHeight(TextPainter textPainter) {
    final double? caretFullHeight = textPainter.getFullHeightForCaret(
      widget.controller.selection.base,
      Rect.zero,
    );
    return (widget.controller.selection.base.offset > 0) ? caretFullHeight! : 0;
  }

  double _getPopupLeftOffset(TextPainter textPainter) {
    return max(
      _getCaretOffset(textPainter).dx +
          widget.padding.left -
          _horizontalCodeScroll!.offset,
      0,
    );
  }

  double _getPopupTopOffset(TextPainter textPainter, double caretHeight) {
    return max(
      _getCaretOffset(textPainter).dy +
          caretHeight +
          16 +
          widget.padding.top -
          _codeScroll!.offset,
      0,
    );
  }
}

class AdaptiveTextSelectionMainToolbar extends StatelessWidget {
  const AdaptiveTextSelectionMainToolbar({
    super.key,
    required this.children,
    required this.anchors,
  }) : buttonItems = null;

  /// {@template flutter.material.AdaptiveTextSelectionToolbar.buttonItems}
  /// The [ContextMenuButtonItem]s that will be turned into the correct button
  /// widgets for the current platform.
  /// {@endtemplate}
  final List<ContextMenuButtonItem>? buttonItems;

  /// The children of the toolbar, typically buttons.
  final List<Widget>? children;

  /// {@template flutter.material.AdaptiveTextSelectionToolbar.anchors}
  /// The location on which to anchor the menu.
  /// {@endtemplate}
  final TextSelectionToolbarAnchors anchors;

  /// Returns the default button label String for the button of the given
  /// [ContextMenuButtonType] on any platform.
  static String getButtonLabel(
      BuildContext context, ContextMenuButtonItem buttonItem) {
    if (buttonItem.label != null) {
      return buttonItem.label!;
    }

    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return CupertinoTextSelectionToolbarButton.getButtonLabel(
          context,
          buttonItem,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        assert(debugCheckHasMaterialLocalizations(context));
        final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);
        switch (buttonItem.type) {
          case ContextMenuButtonType.cut:
            return localizations.cutButtonLabel;
          case ContextMenuButtonType.copy:
            return localizations.copyButtonLabel;
          case ContextMenuButtonType.paste:
            return localizations.pasteButtonLabel;
          case ContextMenuButtonType.selectAll:
            return localizations.selectAllButtonLabel;
          case ContextMenuButtonType.delete:
            return localizations.deleteButtonTooltip.toUpperCase();
          case ContextMenuButtonType.custom:
            return '';
        }
    }
    return '';
  }

  static Iterable<Widget> getAdaptiveButtons(
      BuildContext context, List<ContextMenuButtonItem> buttonItems) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
        return buttonItems.map((ContextMenuButtonItem buttonItem) {
          return CupertinoTextSelectionToolbarButton.text(
            onPressed: buttonItem.onPressed,
            text: getButtonLabel(context, buttonItem),
          );
        });
      case TargetPlatform.fuchsia:
      case TargetPlatform.android:
        final List<Widget> buttons = <Widget>[];
        for (int i = 0; i < buttonItems.length; i++) {
          final ContextMenuButtonItem buttonItem = buttonItems[i];
          buttons.add(TextSelectionToolbarTextButton(
            padding: TextSelectionToolbarTextButton.getPadding(
                i, buttonItems.length),
            onPressed: buttonItem.onPressed,
            child: Text(getButtonLabel(context, buttonItem)),
          ));
        }
        return buttons;
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return buttonItems.map((ContextMenuButtonItem buttonItem) {
          return DesktopTextSelectionToolbarButton.text(
            context: context,
            onPressed: buttonItem.onPressed,
            text: getButtonLabel(context, buttonItem),
          );
        });
      case TargetPlatform.macOS:
        return buttonItems.map((ContextMenuButtonItem buttonItem) {
          return CupertinoDesktopTextSelectionToolbarButton.text(
            // context: context,
            onPressed: buttonItem.onPressed,
            text: getButtonLabel(context, buttonItem),
          );
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If there aren't any buttons to build, build an empty toolbar.
    if ((children != null && children!.isEmpty) ||
        (buttonItems != null && buttonItems!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final List<Widget> resultChildren = children != null
        ? children!
        : getAdaptiveButtons(context, buttonItems!).toList();

    return CupertinoDesktopMainTextSelectionToolbar(
      anchor: anchors.primaryAnchor,
      children: resultChildren,
    );
  }
}

const double _kToolbarScreenPadding = 8.0;

const double _kToolbarWidth = 100.0;
const Radius _kToolbarBorderRadius = Radius.circular(8.0);
const EdgeInsets _kToolbarPadding = EdgeInsets.symmetric(
  vertical: 3.0,
);

const CupertinoDynamicColor _kToolbarBorderColor =
CupertinoDynamicColor.withBrightness(
  color: Colors.transparent,
  darkColor: Colors.transparent,
);
const CupertinoDynamicColor _kToolbarBackgroundColor =
CupertinoDynamicColor.withBrightness(
  color: Color(0xFF1A1B23),
  darkColor: Colors.transparent,
);

class CupertinoDesktopMainTextSelectionToolbar extends StatelessWidget {
  /// Creates a const instance of CupertinoTextSelectionToolbar.
  const CupertinoDesktopMainTextSelectionToolbar({
    super.key,
    required this.anchor,
    required this.children,
  }) : assert(children.length > 0);

  final Offset anchor;

  final List<Widget> children;

  static Widget _defaultToolbarBuilder(BuildContext context, Widget child) {
    return Container(
      width: _kToolbarWidth,
      decoration: BoxDecoration(
        color: _kToolbarBackgroundColor.resolveFrom(context),
        border: Border.all(
          color: _kToolbarBorderColor.resolveFrom(context),
        ),
        borderRadius: const BorderRadius.all(_kToolbarBorderRadius),
      ),
      child: Padding(
        padding: _kToolbarPadding,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));

    final double paddingAbove =
        MediaQuery.paddingOf(context).top + _kToolbarScreenPadding;
    final Offset localAdjustment = Offset(_kToolbarScreenPadding, paddingAbove);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _kToolbarScreenPadding,
        paddingAbove,
        _kToolbarScreenPadding,
        _kToolbarScreenPadding,
      ),
      child: CustomSingleChildLayout(
        delegate: DesktopTextSelectionToolbarLayoutDelegate(
          anchor: anchor - localAdjustment,
        ),
        child: _defaultToolbarBuilder(
          context,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}
