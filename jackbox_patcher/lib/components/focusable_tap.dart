import 'package:fluent_ui/fluent_ui.dart';

/// Makes a clickable widget reachable with the keyboard or a controller.
///
/// A focus border is shown around [child] while it's focused. Clicking it with
/// the mouse works as before and doesn't give it the focus.
class FocusableTap extends StatelessWidget {
  const FocusableTap(
      {super.key,
      required this.child,
      required this.onPressed,
      this.onFocusChange,
      this.autofocus = false,
      this.focusNode,
      this.focusStyle,
      this.customActions,
      this.shortcuts});

  final Widget child;
  final void Function()? onPressed;
  final void Function(bool)? onFocusChange;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Changes the focus border of the app theme for this widget (e.g. without the glow)
  final FocusThemeData? focusStyle;

  /// Other intents handled while it's focused (e.g. a controller button)
  final Map<Type, Action<Intent>>? customActions;

  /// Keys sending other intents while it's focused
  final Map<ShortcutActivator, Intent>? shortcuts;

  @override
  Widget build(BuildContext context) {
    return HoverButton(
        onPressed: onPressed,
        onFocusChange: onFocusChange,
        autofocus: autofocus,
        focusNode: focusNode,
        customActions: customActions,
        shortcuts: shortcuts,
        builder: (context, states) {
          return FocusBorder(focused: states.isFocused, style: focusStyle, child: child);
        });
  }
}
