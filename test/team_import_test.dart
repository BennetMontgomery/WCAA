import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wcaa_team_tracker/team_import.dart';
import 'package:wcaa_team_tracker/tracker_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TrackerData.load();
  });

  test('JSON round trip preserves team and player history with fresh IDs', () {
    final roster = TrackerData.roster('Human');
    final team = TrackerData.createTeam(
      roster,
      'Advanced (Default)',
      'Old World Classic',
    );
    team['name'] = 'Gazelles';
    team['treasury'] = 123456;
    team['rerolls'] = 2;
    team['coaches'] = 1;
    final player = TrackerData.createPlayer(
      team,
      TrackerData.positions(roster).first,
    );
    player['name'] = 'Ada';
    player['veteran'] = true;
    player['captain'] = true;
    player['baseSkills'].add('Pro');
    player['skills'].add('Pro');
    player['stats']['ma'] = '5';
    player['skills'].add('Block');
    player['injuryHistory'] = ['Badly Hurt', '-AV'];
    player['td'] = 2;
    player['mvp'] = 1;
    player['miscSpp'] = 3;
    player['spentSpp'] = 6;
    player['valueOverride'] = 75000;
    player['advancements'].add({
      'skill': 'Block',
      'type': 'Chosen Primary',
      'category': 'G',
      'sppCost': 6,
      'value': 20000,
    });
    (team['players'] as List).add(player);

    final source = jsonEncode(team);
    final imported = TeamImport.fromJson(source);
    final expected = TrackerData.copy(team);
    expect(imported['id'], isNot(team['id']));
    expect(imported['players'][0]['id'], isNot(player['id']));
    expected['id'] = imported['id'];
    expected['players'][0]['id'] = imported['players'][0]['id'];
    expect(imported, expected);
    expect(TrackerData.ctv(imported), TrackerData.ctv(team));
    expect(TeamImport.fromJson(source)['id'], isNot(imported['id']));
  });

  test('JSON round trip retains roster choices and accepts older files', () {
    final roster = TrackerData.roster('Elementals');
    final team = TrackerData.createTeam(
      roster,
      'Advanced (Default)',
      'Old World Classic',
    );
    team['options'] = {'element': 'Air'};
    final imported = TeamImport.fromJson(jsonEncode(team));
    expect(imported['options']['element'], 'Air');
    expect(
      TrackerData.teamPositions(
        imported,
      ).where((p) => (p['tags'] as List).contains('Big Guy')).single['name'],
      'Incarnate Elemental of Air',
    );
    team.remove('options');
    expect(TeamImport.fromJson(jsonEncode(team))['options'], isEmpty);
  });

  test('invalid and unsupported files are rejected', () {
    expect(() => TeamImport.fromJson('not json'), throwsFormatException);
    expect(() => TeamImport.fromJson('{}'), throwsFormatException);
    final team = TrackerData.createTeam(
      TrackerData.roster('Human'),
      'Advanced (Default)',
      'Old World Classic',
    );
    team['schemaVersion'] = 2;
    expect(() => TeamImport.fromJson(jsonEncode(team)), throwsFormatException);
    team['schemaVersion'] = 1;
    team['race'] = 'Unknown';
    expect(() => TeamImport.fromJson(jsonEncode(team)), throwsFormatException);
    team['race'] = 'Human';
    final player = TrackerData.createPlayer(
      team,
      TrackerData.positions(TrackerData.roster('Human')).first,
    );
    (team['players'] as List).add(player);
    player.remove('injuryHistory');
    expect(() => TeamImport.fromJson(jsonEncode(team)), throwsFormatException);
  });
}
