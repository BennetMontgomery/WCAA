import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wcaa_team_tracker/tracker_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TrackerData.load();
  });
  test('all supplied rosters have usable positions and Cathay pool', () {
    expect(TrackerData.rosters.length, 133);
    expect(TrackerData.rosters.where((r) => r['secret'] == false).length, 30);
    expect(TrackerData.roster('Cathay')['leagues'], ['Old World Classic']);
    for (final roster in TrackerData.rosters) {
      final positions = TrackerData.positions(roster);
      expect(positions, isNotEmpty, reason: roster['name']);
      expect(
        positions.every(
          (p) => (p['price'] as int) > 0 && (p['max'] as int) > 0,
        ),
        isTrue,
        reason: roster['name'],
      );
    }
  });
  test('every roster skill and trait resolves to bundled rule text', () {
    final names = TrackerData.rules.keys
        .map(TrackerData.canonicalSkill)
        .toSet();
    for (final roster in TrackerData.rosters) {
      for (final position in TrackerData.positions(roster)) {
        for (final skill in position['skills'] as List) {
          expect(
            names.contains(TrackerData.canonicalSkill(skill.toString())),
            isTrue,
            reason: roster['name'].toString() + ' / ' + skill.toString(),
          );
        }
      }
    }
  });
  test('team starts with Sevens treasury and player values feed CTV', () {
    final roster = TrackerData.roster('Human');
    final team = TrackerData.createTeam(
      roster,
      TrackerData.modes.first,
      'Old World Classic',
    );
    expect(team['treasury'], 600000);
    final lineman = TrackerData.createPlayer(
      team,
      TrackerData.positions(roster).first,
    );
    (team['players'] as List).add(lineman);
    expect(TrackerData.ctv(team), 50000);
    lineman['stats']['st'] = '4';
    expect(TrackerData.playerValue(lineman, team['mode']), 110000);
    lineman['injury'] = 'MNG';
    expect(TrackerData.ctv(team), 0);
  });
  test('Brawlin Brutes swaps TD and casualty SPP', () {
    final roster = TrackerData.roster('Orcs');
    final team = TrackerData.createTeam(
      roster,
      'Advanced (Default)',
      'Badlands Brawl',
    );
    final p = TrackerData.createPlayer(
      team,
      TrackerData.positions(roster).first,
    );
    p['td'] = 1;
    p['cas'] = 1;
    p['mvp'] = 1;
    expect(TrackerData.spp(p, team), 9);
  });
  test(
    'manual secondary skills and non-stock gains affect value and departure count',
    () {
      final roster = TrackerData.roster('Human');
      final team = TrackerData.createTeam(
        roster,
        'Advanced (Default)',
        'Old World Classic',
      );
      final p = TrackerData.createPlayer(
        team,
        TrackerData.positions(roster).first,
      );
      (p['skills'] as List).add('Dodge'); // A is Secondary for Human Linemen.
      expect(TrackerData.playerValue(p, team['mode']), 90000);
      expect(TrackerData.advancementCount(p), 1);
      p['stats']['ma'] = '7';
      expect(TrackerData.advancementCount(p), 2);
    },
  );
  test('characteristic improvement costs follow the 2025 table', () {
    expect(TrackerData.advancementCost(0, 'Characteristic Improvement'), 14);
    expect(TrackerData.advancementCost(1, 'Characteristic Improvement'), 16);
    expect(TrackerData.advancementCost(5, 'Characteristic Improvement'), 38);
  });
  test('Orc Goblin Lineman has PA 4+', () {
    final goblin = TrackerData.positions(
      TrackerData.roster('Orcs'),
    ).firstWhere((p) => p['name'] == 'Goblin Lineman');
    expect(goblin['pa'], '4+');
  });
  test('roster data has no crossed-out values', () {
    for (final roster in TrackerData.rosters) {
      expect(
        jsonEncode(roster).contains('~~'),
        isFalse,
        reason: roster['name'],
      );
    }
    final renegadeOgre = TrackerData.positions(
      TrackerData.roster('Chaos Renegades'),
    ).firstWhere((p) => p['name'] == 'Ogre*');
    expect(renegadeOgre['skills'], contains('Loner (4+)'));
    for (final race in ['Human', 'Imperial Nobility', 'Old World Alliance']) {
      final ogre = TrackerData.positions(
        TrackerData.roster(race),
      ).firstWhere((p) => p['name'].toString().startsWith('Ogre'));
      expect(ogre['secondary'], 'AG', reason: race);
    }
  });
  test('Team Captain rosters can designate one eligible player', () {
    final captainRosters = TrackerData.rosters.where(
      (r) => (r['specialRules'] as List).contains('Team Captain'),
    );
    expect(captainRosters.map((r) => r['name']).toSet(), {
      'Human',
      'Orcs',
      'Araby',
      'Clan Mors',
      'Everpeak',
      'Nuln',
      'Pirates of Sartosa',
      'Sisters of Sigmar',
    });
    for (final roster in captainRosters) {
      final team = TrackerData.createTeam(
        roster,
        'Advanced (Default)',
        (roster['leagues'] as List).first,
      );
      final eligiblePosition = TrackerData.positions(roster).firstWhere(
        (p) =>
            !(p['tags'] as List).contains('Big Guy') &&
            (roster['captainPositions'] == null ||
                (roster['captainPositions'] as List).contains(p['name'])),
      );
      final player = TrackerData.createPlayer(team, eligiblePosition);
      (team['players'] as List).add(player);
      expect(
        TrackerData.canDesignateCaptain(team, player),
        isTrue,
        reason: roster['name'],
      );
      if (roster['captainPositions'] != null) {
        final otherPosition = TrackerData.positions(roster).first;
        final other = TrackerData.createPlayer(team, otherPosition);
        (team['players'] as List).add(other);
        expect(TrackerData.canDesignateCaptain(team, other), isFalse);
      }
      player['captain'] = true;
      expect(TrackerData.canDesignateCaptain(team, player), isFalse);
    }
  });
  test('Elementals use selected lineman and matching Incarnate', () {
    final roster = TrackerData.roster('Elementals');
    final team = TrackerData.createTeam(
      roster,
      'Advanced (Default)',
      'Old World Classic',
    );
    team['options'] = {'element': 'Water'};
    final positions = TrackerData.teamPositions(team);
    expect(
      positions.firstWhere((p) => p['name'] == 'Water Elemental')['max'],
      16,
    );
    expect(
      positions.firstWhere((p) => p['name'] == 'Earth Elemental')['max'],
      2,
    );
    expect(
      positions
          .where((p) => (p['tags'] as List).contains('Big Guy'))
          .single['name'],
      'Incarnate Elemental of Water',
    );
  });
}
