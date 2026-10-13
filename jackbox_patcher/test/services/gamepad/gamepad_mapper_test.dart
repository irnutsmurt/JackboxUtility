import 'package:flutter_test/flutter_test.dart';
import 'package:jackbox_patcher/services/gamepad/gamepad_mapper.dart';

GamepadSnapshot pad({int buttons = 0, int leftX = 0, int leftY = 0, int rightY = 0}) {
  return (buttons: buttons, leftX: leftX, leftY: leftY, rightY: rightY);
}

Duration ms(int milliseconds) => Duration(milliseconds: milliseconds);

void main() {
  late GamepadMapper mapper;

  setUp(() {
    mapper = GamepadMapper();
  });

  group('Buttons', () {
    test('A fires once per press and never repeats', () {
      expect(mapper.update([pad(buttons: GamepadButtons.a)], ms(0)), [GamepadCommand.ACTIVATE]);
      expect(mapper.update([pad(buttons: GamepadButtons.a)], ms(16)), isEmpty);
      expect(mapper.update([pad(buttons: GamepadButtons.a)], ms(1000)), isEmpty);
      expect(mapper.update([pad()], ms(1016)), isEmpty);
      expect(mapper.update([pad(buttons: GamepadButtons.a)], ms(1032)), [GamepadCommand.ACTIVATE]);
    });

    test('B, LB and RB are mapped', () {
      expect(mapper.update([pad(buttons: GamepadButtons.b)], ms(0)), [GamepadCommand.BACK]);
      expect(
          mapper.update([pad(buttons: GamepadButtons.leftShoulder | GamepadButtons.rightShoulder)], ms(16)),
          [GamepadCommand.PREVIOUS, GamepadCommand.NEXT]);
    });
  });

  group('Directions', () {
    test('a held D-pad direction repeats after 400 ms, then every 110 ms', () {
      expect(mapper.update([pad(buttons: GamepadButtons.dpadDown)], ms(0)), [GamepadCommand.DOWN]);
      expect(mapper.update([pad(buttons: GamepadButtons.dpadDown)], ms(399)), isEmpty);
      expect(mapper.update([pad(buttons: GamepadButtons.dpadDown)], ms(400)), [GamepadCommand.DOWN]);
      expect(mapper.update([pad(buttons: GamepadButtons.dpadDown)], ms(509)), isEmpty);
      expect(mapper.update([pad(buttons: GamepadButtons.dpadDown)], ms(510)), [GamepadCommand.DOWN]);
      expect(mapper.update([pad()], ms(600)), isEmpty);
    });

    test('the left stick needs 50% to press and goes under 30% to release', () {
      expect(mapper.update([pad(leftY: -9000)], ms(0)), isEmpty);
      expect(mapper.update([pad(leftY: -16000)], ms(16)), isEmpty);
      expect(mapper.update([pad(leftY: -17000)], ms(32)), [GamepadCommand.DOWN]);
      // Between both thresholds: still held, so no new command
      expect(mapper.update([pad(leftY: -12000)], ms(48)), isEmpty);
      expect(mapper.update([pad(leftY: -9000)], ms(64)), isEmpty);
      // Released: between both thresholds isn't enough to press again
      expect(mapper.update([pad(leftY: -12000)], ms(80)), isEmpty);
      expect(mapper.update([pad(leftX: 17000)], ms(96)), [GamepadCommand.RIGHT]);
    });

    test('a diagonal stick keeps its first direction', () {
      expect(mapper.update([pad(leftX: 20000, leftY: 19000)], ms(0)), [GamepadCommand.RIGHT]);
      expect(mapper.update([pad(leftX: 19000, leftY: 20000)], ms(16)), isEmpty);
      expect(mapper.update([pad(leftX: 19000, leftY: 20000)], ms(400)), [GamepadCommand.RIGHT]);
    });

    test('the D-pad wins over the stick', () {
      expect(mapper.update([pad(buttons: GamepadButtons.dpadUp, leftY: -32768)], ms(0)), [GamepadCommand.UP]);
    });

    test('a D-pad diagonal keeps the held direction', () {
      expect(mapper.update([pad(buttons: GamepadButtons.dpadRight)], ms(0)), [GamepadCommand.RIGHT]);
      expect(mapper.update([pad(buttons: GamepadButtons.dpadRight | GamepadButtons.dpadDown)], ms(16)), isEmpty);
      expect(mapper.update([pad(buttons: GamepadButtons.dpadRight)], ms(32)), isEmpty);
      expect(mapper.update([pad(buttons: GamepadButtons.dpadRight)], ms(400)), [GamepadCommand.RIGHT]);
    });

    test('the stick doesn\'t keep a direction started with the D-pad', () {
      expect(mapper.update([pad(buttons: GamepadButtons.dpadRight)], ms(0)), [GamepadCommand.RIGHT]);
      expect(mapper.update([pad(leftX: 12000)], ms(16)), isEmpty);
      expect(mapper.update([pad(leftX: 17000)], ms(32)), [GamepadCommand.RIGHT]);
    });
  });

  group('Right stick', () {
    test('scrolls and repeats every 80 ms', () {
      expect(mapper.update([pad(rightY: -20000)], ms(0)), [GamepadCommand.SCROLL_DOWN]);
      expect(mapper.update([pad(rightY: -20000)], ms(79)), isEmpty);
      expect(mapper.update([pad(rightY: -20000)], ms(80)), [GamepadCommand.SCROLL_DOWN]);
      expect(mapper.update([pad(rightY: 20000)], ms(96)), [GamepadCommand.SCROLL_UP]);
    });

    test('keeps scrolling until the stick goes under 30%', () {
      expect(mapper.update([pad(rightY: -20000)], ms(0)), [GamepadCommand.SCROLL_DOWN]);
      expect(mapper.update([pad(rightY: -12000)], ms(80)), [GamepadCommand.SCROLL_DOWN]);
      expect(mapper.update([pad(rightY: -9000)], ms(160)), isEmpty);
      expect(mapper.update([pad(rightY: -12000)], ms(240)), isEmpty);
    });
  });

  group('Rebase', () {
    test('a button held when rebasing only counts once released', () {
      expect(mapper.update([pad(buttons: GamepadButtons.b)], ms(0)), [GamepadCommand.BACK]);
      mapper.rebase();
      expect(mapper.update([pad(buttons: GamepadButtons.b)], ms(16)), isEmpty);
      expect(mapper.update([pad(buttons: GamepadButtons.b)], ms(32)), isEmpty);
      expect(mapper.update([pad()], ms(48)), isEmpty);
      expect(mapper.update([pad(buttons: GamepadButtons.b)], ms(64)), [GamepadCommand.BACK]);
    });

    test('a direction held when rebasing doesn\'t repeat', () {
      mapper.rebase();
      expect(mapper.update([pad(buttons: GamepadButtons.dpadLeft)], ms(0)), isEmpty);
      expect(mapper.update([pad(buttons: GamepadButtons.dpadLeft)], ms(1000)), isEmpty);
      expect(mapper.update([pad()], ms(1016)), isEmpty);
      expect(mapper.update([pad(buttons: GamepadButtons.dpadLeft)], ms(1032)), [GamepadCommand.LEFT]);
    });

    test('sticks held when rebasing only count once released', () {
      mapper.rebase();
      expect(mapper.update([pad(leftY: -20000, rightY: -20000)], ms(0)), isEmpty);
      expect(mapper.update([pad(leftY: -12000, rightY: -12000)], ms(1000)), isEmpty);
      expect(mapper.update([pad(leftY: -9000)], ms(1016)), isEmpty);
      expect(mapper.update([pad(leftY: -17000)], ms(1032)), [GamepadCommand.DOWN]);
    });
  });

  group('Controllers', () {
    test('a disconnection forgets the held inputs', () {
      expect(mapper.update([pad(buttons: GamepadButtons.a | GamepadButtons.dpadUp)], ms(0)),
          [GamepadCommand.ACTIVATE, GamepadCommand.UP]);
      expect(mapper.update([], ms(100)), isEmpty);
      expect(mapper.update([], ms(500)), isEmpty);
      // The service rebases when a controller is connected, the mapper itself starts over
      expect(mapper.update([pad(buttons: GamepadButtons.a | GamepadButtons.dpadUp)], ms(600)),
          [GamepadCommand.ACTIVATE, GamepadCommand.UP]);
    });

    test('every connected controller can be used', () {
      expect(mapper.update([pad(buttons: GamepadButtons.dpadRight), pad(buttons: GamepadButtons.a)], ms(0)),
          [GamepadCommand.ACTIVATE, GamepadCommand.RIGHT]);
      expect(mapper.update([pad(), pad(leftY: 30000)], ms(16)), [GamepadCommand.UP]);
    });
  });
}
