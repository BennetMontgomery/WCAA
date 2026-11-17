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
  testWidgets('create a Human team and hire a Lineman', (tester) async {
    await tester.pumpWidget(const TrackerApp());
    expect(find.text('No teams created yet'), findsOneWidget);
    expect(find.text('Add team from JSON'), findsOneWidget);
    await tester.tap(find.text('+ Add Team'));
    await tester.pumpAndSettle();
    expect(find.text('Select New Team'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Human'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Human'));
    await tester.pumpAndSettle();
    expect(find.text('Advanced (Default)'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(find.text('Unnamed Human Team'), findsOneWidget);
    expect(find.text('600,000 GP'), findsOneWidget);
    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('#1 Name'), findsOneWidget);
    expect(find.text('550,000 GP'), findsOneWidget);
  });

  testWidgets('home deletion requires confirmation and persists', (
    tester,
  ) async {
    TrackerData.teams = [
      TrackerData.createTeam(
        TrackerData.roster('Human'),
        TrackerData.modes.first,
        'Old World Classic',
      ),
    ];
    await tester.pumpWidget(const TrackerApp());
    await tester.tap(find.byTooltip('Delete team'));
    await tester.pumpAndSettle();
    expect(find.text('Delete team?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Unnamed Human Team'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete team'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No teams created yet'), findsOneWidget);
    expect(TrackerData.teams, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('teams_v1'), '[]');
  });

  testWidgets('hiring a journeyman preserves progress and can be undone', (
    tester,
  ) async {
    final roster = TrackerData.roster('Human');
    final team = TrackerData.createTeam(
      roster,
      'Advanced (Default)',
      'Old World Classic',
    );
    final player = TrackerData.createPlayer(
      team,
      TrackerData.positions(roster).first,
      journeyman: true,
    );
    player['name'] = 'Veteran Hopeful';
    player['td'] = 1;
    player['mvp'] = 1;
    player['injuryHistory'] = ['Badly Hurt'];
    (player['skills'] as List).add('Block');
    (team['players'] as List).add(player);
    TrackerData.teams = [team];
    final playerId = player['id'];

    await tester.pumpWidget(const TrackerApp());
    await tester.tap(find.text(team['name']));
    await tester.pumpAndSettle();
    final hire = find.text('Hire permanently (50,000 GP)');
    await tester.ensureVisible(hire);
    await tester.pumpAndSettle();
    await tester.tap(hire);
    await tester.pumpAndSettle();

    expect(team['treasury'], 550000);
    expect(player['journeyman'], false);
    expect(player['id'], playerId);
    expect(player['name'], 'Veteran Hopeful');
    expect(TrackerData.spp(player, team), 7);
    expect(player['injuryHistory'], ['Badly Hurt']);
    expect(player['skills'], contains('Block'));
    expect(player['skills'], isNot(contains('Loner (4+)')));
    expect(player['baseSkills'], isNot(contains('Loner (4+)')));
    expect(find.textContaining('Journeyman'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    final restored = TrackerData.players(TrackerData.teams.single).single;
    expect(TrackerData.teams.single['treasury'], 600000);
    expect(restored['journeyman'], true);
    expect(restored['skills'], contains('Loner (4+)'));
  });

  testWidgets('draft rows grow to contain long Big Guy skill lists', (
    tester,
  ) async {
    final roster = TrackerData.roster('Chaos Renegades');
    TrackerData.teams = [
      TrackerData.createTeam(
        roster,
        'Advanced (Default)',
        (roster['leagues'] as List).first,
      ),
    ];
    await tester.pumpWidget(const TrackerApp());
    await tester.tap(find.text('Unnamed Chaos Renegades Team'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team draft list'));
    await tester.pumpAndSettle();

    final table = find.byType(DataTable);
    final trollLastSkill = find
        .descendant(of: table, matching: find.text('Throw Team-mate'))
        .first;
    final nextPosition = find
        .descendant(of: table, matching: find.textContaining('Ogre*'))
        .first;
    expect(
      tester.getBottomLeft(trollLastSkill).dy,
      lessThan(tester.getTopLeft(nextPosition).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
