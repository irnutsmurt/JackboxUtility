import 'package:fluent_ui/fluent_ui.dart';

/// Show the previous item of the page (e.g. the previous game). Sent by the left
/// shoulder button of a controller.
class PreviousItemIntent extends Intent {
  const PreviousItemIntent();
}

/// Show the next item of the page (e.g. the next game). Sent by the right
/// shoulder button of a controller.
class NextItemIntent extends Intent {
  const NextItemIntent();
}

/// Launch the focused game without opening its page, like its small play
/// button. Sent by the X button of a controller.
class QuickLaunchIntent extends Intent {
  const QuickLaunchIntent();
}
