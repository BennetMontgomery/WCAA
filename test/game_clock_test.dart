import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wcaa_team_tracker/main.dart';
import 'package:wcaa_team_tracker/tracker_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TrackerData.load();
    TrackerData.teams = [];
  });

  String displayedTime(WidgetTester tester, int team) => tester
      .widget<TextField>(find.byKey(Key('teamTime$team')))
      .controller!
      .text;

  testWidgets(
    'clock starts evenly, switches teams, pauses, and survives tabs',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const TrackerApp());
      expect(find.text('Teams'), findsOneWidget);
      expect(find.text('No teams created yet'), findsOneWidget);
      await tester.tap(find.text('Game Clock'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('gameTime')))
            .controller!
            .text,
        '1:30:00',
      );
      expect(displayedTime(tester, 0), '0:45:00');
      expect(displayedTime(tester, 1), '0:45:00');

      await tester.tap(find.byKey(const Key('startClock0')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(displayedTime(tester, 0), '0:44:57');
      expect(displayedTime(tester, 1), '0:45:00');

      await tester.tap(find.byKey(const Key('startClock1')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(displayedTime(tester, 0), '0:44:57');
      expect(displayedTime(tester, 1), '0:44:58');

      await tester.tap(find.byKey(const Key('pauseClock')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(displayedTime(tester, 0), '0:44:57');
      expect(displayedTime(tester, 1), '0:44:58');

      await tester.tap(find.text('Teams'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Game Clock'));
      await tester.pumpAndSettle();
      expect(displayedTime(tester, 0), '0:44:57');
      expect(displayedTime(tester, 1), '0:44:58');

      await tester.tap(find.byKey(const Key('startClock0')));
      await tester.pump();
      await tester.tap(find.text('Teams'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Game Clock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(displayedTime(tester, 0).compareTo('0:44:57'), lessThan(0));
      expect(displayedTime(tester, 1), '0:44:58');
    },
  );

  testWidgets('game and team time fields are editable', (tester) async {
    await tester.pumpWidget(const TrackerApp());
    await tester.tap(find.text('Game Clock'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('gameTime')), '2:00:00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(displayedTime(tester, 0), '1:00:00');
    expect(displayedTime(tester, 1), '1:00:00');

    await tester.enterText(find.byKey(const Key('teamName0')), 'Red Dragons');
    await tester.pump();
    expect(find.text('Start Red Dragons clock'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('teamTime0')), '30:00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(displayedTime(tester, 0), '0:30:00');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('gameTime')))
          .controller!
          .text,
      '1:30:00',
    );
  });

  testWidgets('clock stops at zero and rejects invalid time', (tester) async {
    await tester.pumpWidget(const TrackerApp());
    await tester.tap(find.text('Game Clock'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('teamTime0')), '0:01');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.byKey(const Key('startClock0')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(displayedTime(tester, 0), '0:00:00');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('startClock0')))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byKey(const Key('teamTime0')), 'bad time');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(displayedTime(tester, 0), '0:00:00');
    expect(find.text('Enter time as H:MM:SS or M:SS.'), findsOneWidget);
  });

  testWidgets('reset requires confirmation and restores every default', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TrackerApp());
    await tester.tap(find.text('Game Clock'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('teamName0')), 'Red Dragons');
    await tester.enterText(find.byKey(const Key('teamName1')), 'Blue Bears');
    await tester.enterText(find.byKey(const Key('gameTime')), '2:00:00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(displayedTime(tester, 0), '1:00:00');

    await tester.tap(find.byKey(const Key('startClock0')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('resetClock')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const Key('resetClock')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Reset game clock?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('teamName0')))
          .controller!
          .text,
      'Red Dragons',
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('pauseClock')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('resetClock')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Reset'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('teamName0')))
          .controller!
          .text,
      'Home Team',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('teamName1')))
          .controller!
          .text,
      'Away Team',
    );
    expect(displayedTime(tester, 0), '0:45:00');
    expect(displayedTime(tester, 1), '0:45:00');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('gameTime')))
          .controller!
          .text,
      '1:30:00',
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('pauseClock')))
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(displayedTime(tester, 0), '0:45:00');
  });
}
