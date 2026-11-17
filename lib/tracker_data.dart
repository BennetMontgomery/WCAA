import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef RowData = Map<String, dynamic>;

class TrackerData {
  static List<RowData> rosters = [];
  static List<RowData> teams = [];
  static Map<String, dynamic> rules = {};
  static final rng = Random.secure();
  static const modes = ['Advanced (Default)', 'Random', 'Resurrection'];
  static const categoryNames = {
    'A': 'Agility',
    'D': 'Devious',
    'G': 'General',
    'M': 'Mutation',
    'P': 'Passing',
    'S': 'Strength',
  };
  static const skillCategories = <String, List<String>>{
    'A': [
      'Catch',
      'Diving Catch',
      'Diving Tackle',
      'Dodge',
      'Defensive',
      'Hit and Run',
      'Jump Up',
      'Leap',
      'Safe Pair of Hands',
      'Sidestep',
      'Sprint',
      'Sure Feet',
    ],
    'D': [
      'Dirty Player',
      'Eye Gouge',
      'Fumblerooski',
      'Lethal Flight',
      'Lone Fouler',
      'Pile Driver',
      'Put the Boot In',
      'Quick Foul',
      'Saboteur',
      'Shadowing',
      'Sneaky Git',
      'Violent Innovator',
    ],
    'G': [
      'Block',
      'Dauntless',
      'Fend',
      'Frenzy',
      'Kick',
      'Pro',
      'Steady Footing',
      'Strip Ball',
      'Sure Hands',
      'Tackle',
      'Taunt',
      'Wrestle',
    ],
    'M': [
      'Big Hand',
      'Claws',
      'Disturbing Presence',
      'Extra Arms',
      'Foul Appearance',
      'Horns',
      'Iron Hard Skin',
      'Monstrous Mouth',
      'Prehensile Tail',
      'Tentacles',
      'Two Heads',
      'Very Long Legs',
    ],
    'P': [
      'Accurate',
      'Cannoneer',
      'Cloud Burster',
      'Dump-off',
      'Give and Go',
      'Hail Mary Pass',
      'Leader',
      'Nerves of Steel',
      'On the Ball',
      'Pass',
      'Punt',
      'Safe Pass',
    ],
    'S': [
      'Arm Bar',
      'Brawler',
      'Break Tackle',
      'Bullseye',
      'Grab',
      'Guard',
      'Juggernaut',
      'Mighty Blow',
      'Multiple Block',
      'Stand Firm',
      'Strong Arm',
      'Thick Skull',
    ],
  };

  static Future<void> load() async {
    rosters =
        (jsonDecode(await rootBundle.loadString('assets/rosters.json')) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    rules = Map<String, dynamic>.from(
      jsonDecode(await rootBundle.loadString('assets/rules.json')),
    );
    final prefs = await SharedPreferences.getInstance();
    try {
      teams = (jsonDecode(prefs.getString('teams_v1') ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      teams = [];
    }
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teams_v1', jsonEncode(teams));
  }

  static RowData roster(String race) =>
      rosters.firstWhere((r) => r['name'] == race);
  static RowData copy(RowData value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)));
  static List<RowData> players(RowData team) =>
      (team['players'] as List).map((e) => e as RowData).toList();
  static List<RowData> positions(RowData roster) =>
      (roster['positions'] as List).map((e) => e as RowData).toList();
  static String gp(num n) =>
      n.toInt().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
      ) +
      ' GP';

  static RowData createTeam(RowData roster, String mode, String league) => {
    'id': DateTime.now().microsecondsSinceEpoch.toString(),
    'schemaVersion': 1,
    'name': 'Unnamed ' + roster['name'] + ' Team',
    'race': roster['name'],
    'secret': roster['secret'],
    'mode': mode,
    'league': league,
    'treasury': 600000,
    'rerolls': 0,
    'coaches': 0,
    'cheerleaders': 0,
    'apothecary': 0,
    'players': <RowData>[],
    'options': <String, String>{},
  };

  static List<RowData> teamPositions(RowData team) {
    final list = positions(roster(team['race'])).map(copy).toList();
    if (team['race'] != 'Elementals') return list;
    final element = (team['options'] as Map?)?['element'] ?? 'Earth';
    return list.where((position) {
      final name = position['name'] as String;
      if (name.startsWith('Incarnate Elemental of ')) {
        return name.endsWith(element);
      }
      final selected = name == '$element Elemental';
      position['max'] = selected ? 16 : 2;
      position['tags'] = ['Elemental', selected ? 'Lineman' : 'Special'];
      return true;
    }).toList();
  }

  static int nextNumber(RowData team) {
    final taken = players(team).map((p) => p['number'] as int).toSet();
    var n = 1;
    while (taken.contains(n)) {
      n++;
    }
    return n;
  }

  static RowData createPlayer(
    RowData team,
    RowData pos, {
    bool journeyman = false,
  }) {
    final stats = {
      for (final s in ['ma', 'st', 'ag', 'pa', 'av']) s: pos[s],
    };
    final skills = List<String>.from(pos['skills'] as List);
    if (journeyman) skills.add('Loner (4+)');
    return {
      'id':
          DateTime.now().microsecondsSinceEpoch.toString() +
          rng.nextInt(1000).toString(),
      'name': 'Name',
      'number': nextNumber(team),
      'position': pos['name'],
      'tags': List<String>.from(pos['tags'] as List),
      'baseStats': stats,
      'stats': Map<String, dynamic>.from(stats),
      'baseSkills': List<String>.from(skills),
      'skills': skills,
      'primary': pos['primary'],
      'secondary': pos['secondary'],
      'price': pos['price'],
      'journeyman': journeyman,
      'veteran': false,
      'captain': false,
      'injury': 'Healthy',
      'injuryHistory': <String>[],
      'td': 0,
      'int': 0,
      'cas': 0,
      'comp': 0,
      'throw': 0,
      'mvp': 0,
      'miscSpp': 0,
      'spentSpp': 0,
      'advancements': <RowData>[],
      'valueOverride': null,
    };
  }

  static bool available(RowData p) =>
      !['MNG', 'Temporarily retired', 'Dead'].contains(p['injury']);

  static bool hasTeamCaptain(RowData team) =>
      (roster(team['race'])['specialRules'] as List).contains('Team Captain');

  static bool canDesignateCaptain(RowData team, RowData player) {
    if (!hasTeamCaptain(team) ||
        player['journeyman'] == true ||
        player['captain'] == true ||
        player['injury'] == 'Dead' ||
        (player['tags'] as List).contains('Big Guy') ||
        players(team).any((p) => p['captain'] == true)) {
      return false;
    }
    final restricted = roster(team['race'])['captainPositions'];
    return restricted == null ||
        (restricted as List).contains(player['position']);
  }

  static int spp(RowData p, RowData team) {
    final brute = (roster(team['race'])['specialRules'] as List).any(
      (x) => x.toString().contains("Brawlin' Brutes"),
    );
    return (p['td'] as int) * (brute ? 2 : 3) +
        (p['cas'] as int) * (brute ? 3 : 2) +
        (p['int'] as int) * 2 +
        (p['comp'] as int) +
        (p['throw'] as int) +
        (p['mvp'] as int) * 4 +
        (p['miscSpp'] as int);
  }

  static int _num(dynamic v) =>
      int.tryParse(v.toString().replaceAll('+', '')) ?? 0;
  static String canonicalSkill(String value) => value
      .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
      .toLowerCase()
      .replaceAll('fumblerooskie', 'fumblerooski');
  static int advancementCount(RowData p) {
    final current = (p['skills'] as List)
        .map((x) => canonicalSkill(x.toString()))
        .toSet();
    final tracked = (p['advancements'] as List)
        .map((a) => canonicalSkill((a as Map)['skill'].toString()))
        .where(current.contains)
        .toSet();
    final base = (p['baseSkills'] as List)
        .map((x) => canonicalSkill(x.toString()))
        .toSet();
    final manualSkills = (p['skills'] as List)
        .map((x) => canonicalSkill(x.toString()))
        .where(
          (x) => x != 'veteran' && !base.contains(x) && !tracked.contains(x),
        )
        .length;
    final oldStats = p['baseStats'] as Map;
    final nowStats = p['stats'] as Map;
    var gains = 0;
    for (final s in ['ma', 'st', 'ag', 'pa', 'av']) {
      final old = _num(oldStats[s]), now = _num(nowStats[s]);
      gains += (s == 'ag' || s == 'pa') ? max(0, old - now) : max(0, now - old);
    }
    return tracked.length + manualSkills + gains;
  }

  static int playerValue(RowData p, String mode) {
    if (p['valueOverride'] != null) return p['valueOverride'] as int;
    var value = p['price'] as int;
    final base = p['baseStats'] as Map, stats = p['stats'] as Map;
    for (final s in ['ma', 'st', 'ag', 'pa', 'av']) {
      final a = _num(base[s]), b = _num(stats[s]);
      final gains = (s == 'ag' || s == 'pa') ? max(0, a - b) : max(0, b - a);
      value +=
          gains *
          {'ma': 20000, 'st': 60000, 'ag': 30000, 'pa': 20000, 'av': 10000}[s]!;
    }
    final advancements = p['advancements'] as List;
    final currentSkills = (p['skills'] as List)
        .map((x) => canonicalSkill(x.toString()))
        .toSet();
    for (final a in advancements) {
      if (currentSkills.contains(
        canonicalSkill((a as Map)['skill'].toString()),
      )) {
        value += a['value'] as int;
      }
    }
    final known = [
      ...(p['baseSkills'] as List),
      ...advancements.map((a) => (a as Map)['skill']),
    ].map((x) => canonicalSkill(x.toString())).toSet();
    var manualIndex = advancements.length;
    for (final skill in p['skills'] as List) {
      if (known.contains(canonicalSkill(skill.toString())) ||
          skill == 'Veteran')
        continue;
      if (mode == 'Random') {
        value += manualIndex == 0 ? 10000 : 20000;
      } else {
        final category = skillCategories.entries
            .where(
              (entry) => entry.value.any(
                (x) => canonicalSkill(x) == canonicalSkill(skill.toString()),
              ),
            )
            .map((entry) => entry.key)
            .firstOrNull;
        final secondary = (p['secondary'] as String).contains(category ?? '?');
        final primary = (p['primary'] as String).contains(category ?? '?');
        value += secondary && !primary ? 40000 : 20000;
      }
      manualIndex++;
    }
    return value;
  }

  static int ctv(RowData team) {
    final mode = team['mode'] as String;
    return players(team)
            .where(available)
            .fold<int>(0, (sum, p) => sum + playerValue(p, mode)) +
        (team['rerolls'] as int) * 100000 +
        (team['coaches'] as int) * 20000 +
        (team['cheerleaders'] as int) * 20000 +
        (team['apothecary'] as int) * 80000;
  }

  static int advancementCost(int count, String type) {
    const costs = {
      'Random Primary': [3, 4, 6, 8, 10, 15],
      'Chosen Primary': [6, 8, 12, 16, 20, 30],
      'Chosen Secondary': [10, 12, 16, 20, 24, 34],
      'Random Secondary': [10, 12, 16, 20, 24, 34],
      'Characteristic Improvement': [14, 16, 20, 24, 28, 38],
    };
    final list = costs[type]!;
    return list[min(count, list.length - 1)];
  }

  static List<String> eligibleSkills(RowData p, String category) {
    final have = (p['skills'] as List)
        .map((x) => canonicalSkill(x.toString()))
        .toSet();
    return (skillCategories[category] ?? [])
        .where(
          (x) =>
              !have.contains(canonicalSkill(x)) && x != 'Leader' && x != 'Pro',
        )
        .toList();
  }
}
