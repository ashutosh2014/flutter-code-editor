import 'dart:developer';

import 'package:flutter/cupertino.dart';

import '../../../flutter_code_editor.dart';

class OutdentIntent extends Intent {
  const OutdentIntent();
}

class OutdentIntentAction extends Action<OutdentIntent> {
  final CodeController controller;

  OutdentIntentAction({
    required this.controller,
  });

  int get tabSpaces => controller.params.tabSpaces;

  @override
  Object? invoke(OutdentIntent intent) {
    controller.modifySelectedRows(_unTab);

    return null;
  }

  String _unTab(String row) {
    if (row.length < tabSpaces) {
      return row.trimLeft();
    }

    final subStr = row.substring(0, tabSpaces);
    if (subStr == ' ' * tabSpaces) {
      return row.substring(tabSpaces, row.length);
    }
    return row.trimLeft();
  }
}
