import 'package:fluent_ui/fluent_ui.dart';

/// Makes a clickable widget reachable with the keyboard or a controller.
///
/// A focus border is shown around [child] while it's focused. Clicking it with
/// the mouse works as before and doesn't give it the focus.
class FocusableTap extends StatelessWidget {
  const FocusableTap(
      {super.key, required this.child, required this.onPressed, this.onFocusChange, this.autofocus = false});

  final Widget child;
  final void Function()? onPressed;
  final void Function(bool)? onFocusChange;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return HoverButton(
        onPressed: onPressed,
        onFocusChange: onFocusChange,
        autofocus: autofocus,
        builder: (context, states) {
          return FocusBorder(focused: states.isFocused, child: child);
        });
  }
}
