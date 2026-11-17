import 'dart:convert';

import 'tracker_data.dart';

/// Reads the version 1 JSON written by the WCAA team export.
class TeamImport {
  static RowData fromJson(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('The selected file is not valid JSON.');
    }
    final team = _object(decoded, 'Team');
    if (team['schemaVersion'] != 1) {
      throw const FormatException('Unsupported WCAA JSON version.');
    }
    _string(team, 'id', 'Team');
    _string(team, 'name', 'Team');
    final race = _string(team, 'race', 'Team');
    final matching = TrackerData.rosters.where((r) => r['name'] == race);
    if (matching.isEmpty) {
      throw FormatException('This app does not have a roster for $race.');
    }
    if (team['secret'] is! bool || team['secret'] != matching.first['secret']) {
      throw const FormatException('Team race data is invalid.');
    }
    final mode = _string(team, 'mode', 'Team');
    if (!TrackerData.modes.contains(mode)) {
      throw const FormatException('Team progression mode is not supported.');
    }
    _string(team, 'league', 'Team');
    if (team['options'] == null) {
      team['options'] = <String, String>{};
    } else if (team['options'] is! Map<String, dynamic> ||
        (team['options'] as Map).entries.any(
          (entry) => entry.key is! String || entry.value is! String,
        )) {
      throw const FormatException('Team options are invalid.');
    }
    for (final key in [
      'treasury',
      'rerolls',
      'coaches',
      'cheerleaders',
      'apothecary',
    ]) {
      _integer(team, key, 'Team');
    }
    final players = _list(team, 'players', 'Team');
    final numbers = <int>{};
    for (var i = 0; i < players.length; i++) {
      final player = _object(players[i], 'Player ${i + 1}');
      final context = 'Player ${i + 1}';
      _string(player, 'id', context);
      _string(player, 'name', context);
      final number = _integer(player, 'number', context);
      if (number < 1 || !numbers.add(number)) {
        throw FormatException('$context has an invalid or duplicate number.');
      }
      _string(player, 'position', context);
      _stringList(player, 'tags', context);
      _stats(player, 'baseStats', context);
      _stats(player, 'stats', context);
      _stringList(player, 'baseSkills', context);
      _stringList(player, 'skills', context);
      _string(player, 'primary', context);
      _string(player, 'secondary', context);
      _integer(player, 'price', context);
      if (player['journeyman'] is! bool || player['veteran'] is! bool) {
        throw FormatException('$context has invalid player flags.');
      }
      if (player['captain'] == null) {
        player['captain'] = false; // Exports made before Team Captain support.
      } else if (player['captain'] is! bool) {
        throw FormatException('$context has an invalid captain flag.');
      }
      _string(player, 'injury', context);
      _stringList(player, 'injuryHistory', context);
      for (final key in [
        'td',
        'int',
        'cas',
        'comp',
        'throw',
        'mvp',
        'miscSpp',
        'spentSpp',
      ]) {
        _integer(player, key, context);
      }
      if (player['valueOverride'] != null && player['valueOverride'] is! int) {
        throw FormatException('$context has an invalid value override.');
      }
      final advancements = _list(player, 'advancements', context);
      for (var j = 0; j < advancements.length; j++) {
        final advance = _object(
          advancements[j],
          '$context advancement ${j + 1}',
        );
        final label = '$context advancement ${j + 1}';
        _string(advance, 'skill', label);
        _string(advance, 'type', label);
        _string(advance, 'category', label);
        _integer(advance, 'sppCost', label);
        _integer(advance, 'value', label);
      }
    }

    // Team IDs identify home-page entries; new IDs allow repeated imports.
    final newId =
        '${DateTime.now().microsecondsSinceEpoch}-'
        '${TrackerData.rng.nextInt(1 << 32)}';
    team['id'] = newId;
    for (var i = 0; i < players.length; i++) {
      (players[i] as Map<String, dynamic>)['id'] = '$newId-player-$i';
    }
    return team;
  }

  static RowData _object(dynamic value, String label) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('$label data is invalid.');
    }
    return value;
  }

  static String _string(RowData data, String key, String label) {
    final value = data[key];
    if (value is! String) {
      throw FormatException('$label has an invalid $key.');
    }
    return value;
  }

  static int _integer(RowData data, String key, String label) {
    final value = data[key];
    if (value is! int || value < 0) {
      throw FormatException('$label has an invalid $key.');
    }
    return value;
  }

  static List<dynamic> _list(RowData data, String key, String label) {
    final value = data[key];
    if (value is! List) {
      throw FormatException('$label has an invalid $key.');
    }
    return value;
  }

  static void _stringList(RowData data, String key, String label) {
    if (_list(data, key, label).any((value) => value is! String)) {
      throw FormatException('$label has an invalid $key.');
    }
  }

  static void _stats(RowData data, String key, String label) {
    final stats = _object(data[key], '$label $key');
    for (final stat in ['ma', 'st', 'ag', 'pa', 'av']) {
      _string(stats, stat, '$label $key');
    }
  }
}
