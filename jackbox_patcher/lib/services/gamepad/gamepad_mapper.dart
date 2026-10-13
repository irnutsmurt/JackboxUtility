/// State of one controller at a given time.
///
/// [buttons] is a combination of [GamepadButtons] and the sticks go from -32768
/// to 32767 (up and right are positive).
typedef GamepadSnapshot = ({int buttons, int leftX, int leftY, int rightY});

/// Bits of the buttons of a [GamepadSnapshot].
///
/// They have the same values as XInput, so an XInput state is used as is.
/// Another library must convert its buttons to them.
class GamepadButtons {
  static const int dpadUp = 0x0001;
  static const int dpadDown = 0x0002;
  static const int dpadLeft = 0x0004;
  static const int dpadRight = 0x0008;
  static const int leftShoulder = 0x0100;
  static const int rightShoulder = 0x0200;
  static const int a = 0x1000;
  static const int b = 0x2000;
}

/// Navigation commands sent by a controller
enum GamepadCommand { UP, DOWN, LEFT, RIGHT, ACTIVATE, BACK, PREVIOUS, NEXT, SCROLL_UP, SCROLL_DOWN }

/// Turns controller states into navigation commands.
///
/// Buttons fire once per press. Directions (D-pad or left stick) and scrolling
/// (right stick) fire when pressed, then repeat while they are held.
class GamepadMapper {
  /// A stick counts as pressed above 50% and as released under 30%, so it
  /// doesn't flicker around a single threshold
  static const int stickPressThreshold = 16384;
  static const int stickReleaseThreshold = 9830;

  static const Duration directionRepeatDelay = Duration(milliseconds: 400);
  static const Duration directionRepeatInterval = Duration(milliseconds: 110);
  static const Duration scrollRepeatInterval = Duration(milliseconds: 80);

  static const Map<int, GamepadCommand> _buttonCommands = {
    GamepadButtons.a: GamepadCommand.ACTIVATE,
    GamepadButtons.b: GamepadCommand.BACK,
    GamepadButtons.leftShoulder: GamepadCommand.PREVIOUS,
    GamepadButtons.rightShoulder: GamepadCommand.NEXT,
  };

  static const Map<GamepadCommand, int> _dpadDirectionButtons = {
    GamepadCommand.UP: GamepadButtons.dpadUp,
    GamepadCommand.DOWN: GamepadButtons.dpadDown,
    GamepadCommand.LEFT: GamepadButtons.dpadLeft,
    GamepadCommand.RIGHT: GamepadButtons.dpadRight,
  };

  static const int _dpadButtons =
      GamepadButtons.dpadUp | GamepadButtons.dpadDown | GamepadButtons.dpadLeft | GamepadButtons.dpadRight;

  int _previousButtons = 0;

  GamepadCommand? _heldDirection;
  bool _directionFromStick = false;
  bool _directionBlocked = false;
  Duration _nextDirectionRepeat = Duration.zero;

  GamepadCommand? _heldScroll;
  bool _scrollBlocked = false;
  Duration _nextScrollRepeat = Duration.zero;

  bool _rebasePending = false;

  /// Inputs held during the next [update] will only count once released and
  /// pressed again (e.g. the button used to quit a game).
  void rebase() {
    _rebasePending = true;
  }

  /// Read the state of every connected controller and return the commands to run
  List<GamepadCommand> update(List<GamepadSnapshot> pads, Duration now) {
    if (pads.isEmpty) {
      _reset();
      return [];
    }

    // Every controller can be used at the same time
    int buttons = 0;
    GamepadSnapshot leftStick = pads.first;
    GamepadSnapshot rightStick = pads.first;
    for (GamepadSnapshot pad in pads) {
      buttons |= pad.buttons;
      if (_leftStickAmount(pad) > _leftStickAmount(leftStick)) {
        leftStick = pad;
      }
      if (pad.rightY.abs() > rightStick.rightY.abs()) {
        rightStick = pad;
      }
    }

    GamepadCommand? direction = _readDirection(buttons, leftStick.leftX, leftStick.leftY);
    bool directionFromStick = direction != null && (buttons & _dpadButtons) == 0;
    GamepadCommand? scroll = _readScroll(rightStick.rightY);

    if (_rebasePending) {
      _rebasePending = false;
      _previousButtons = buttons;
      _heldDirection = direction;
      _directionFromStick = directionFromStick;
      _directionBlocked = direction != null;
      _heldScroll = scroll;
      _scrollBlocked = scroll != null;
      return [];
    }

    List<GamepadCommand> commands = [];

    int pressedButtons = buttons & ~_previousButtons;
    _previousButtons = buttons;
    _buttonCommands.forEach((int button, GamepadCommand command) {
      if ((pressedButtons & button) != 0) {
        commands.add(command);
      }
    });

    if (direction != _heldDirection) {
      _heldDirection = direction;
      _directionBlocked = false;
      if (direction != null) {
        commands.add(direction);
        _nextDirectionRepeat = now + directionRepeatDelay;
      }
    } else if (direction != null && !_directionBlocked && now >= _nextDirectionRepeat) {
      commands.add(direction);
      _nextDirectionRepeat = now + directionRepeatInterval;
    }
    _directionFromStick = directionFromStick;

    if (scroll != _heldScroll) {
      _heldScroll = scroll;
      _scrollBlocked = false;
      if (scroll != null) {
        commands.add(scroll);
        _nextScrollRepeat = now + scrollRepeatInterval;
      }
    } else if (scroll != null && !_scrollBlocked && now >= _nextScrollRepeat) {
      commands.add(scroll);
      _nextScrollRepeat = now + scrollRepeatInterval;
    }

    return commands;
  }

  /// Forget every held input (e.g. when every controller is disconnected)
  void _reset() {
    _previousButtons = 0;
    _heldDirection = null;
    _directionFromStick = false;
    _directionBlocked = false;
    _heldScroll = null;
    _scrollBlocked = false;
  }

  int _leftStickAmount(GamepadSnapshot pad) {
    return pad.leftX.abs() > pad.leftY.abs() ? pad.leftX.abs() : pad.leftY.abs();
  }

  GamepadCommand? _readDirection(int buttons, int stickX, int stickY) {
    // Keep the current D-pad direction while it's held, even on diagonals
    if (_heldDirection != null &&
        !_directionFromStick &&
        (buttons & _dpadDirectionButtons[_heldDirection]!) != 0) {
      return _heldDirection;
    }
    // The D-pad wins over the stick
    if ((buttons & GamepadButtons.dpadUp) != 0) return GamepadCommand.UP;
    if ((buttons & GamepadButtons.dpadDown) != 0) return GamepadCommand.DOWN;
    if ((buttons & GamepadButtons.dpadLeft) != 0) return GamepadCommand.LEFT;
    if ((buttons & GamepadButtons.dpadRight) != 0) return GamepadCommand.RIGHT;

    // Keep the current stick direction until the stick is released, even on diagonals
    if (_heldDirection != null &&
        _directionFromStick &&
        _stickValueInDirection(_heldDirection!, stickX, stickY) > stickReleaseThreshold) {
      return _heldDirection;
    }
    if (stickX.abs() < stickPressThreshold && stickY.abs() < stickPressThreshold) {
      return null;
    }
    if (stickX.abs() > stickY.abs()) {
      return stickX > 0 ? GamepadCommand.RIGHT : GamepadCommand.LEFT;
    }
    return stickY > 0 ? GamepadCommand.UP : GamepadCommand.DOWN;
  }

  int _stickValueInDirection(GamepadCommand direction, int stickX, int stickY) {
    switch (direction) {
      case GamepadCommand.UP:
        return stickY;
      case GamepadCommand.DOWN:
        return -stickY;
      case GamepadCommand.LEFT:
        return -stickX;
      case GamepadCommand.RIGHT:
        return stickX;
      default:
        return 0;
    }
  }

  GamepadCommand? _readScroll(int stickY) {
    if (_heldScroll == GamepadCommand.SCROLL_UP && stickY > stickReleaseThreshold) return GamepadCommand.SCROLL_UP;
    if (_heldScroll == GamepadCommand.SCROLL_DOWN && -stickY > stickReleaseThreshold) return GamepadCommand.SCROLL_DOWN;
    if (stickY > stickPressThreshold) return GamepadCommand.SCROLL_UP;
    if (stickY < -stickPressThreshold) return GamepadCommand.SCROLL_DOWN;
    return null;
  }
}
