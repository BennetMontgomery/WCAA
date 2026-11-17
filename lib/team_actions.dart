part of 'main.dart';

extension TeamActions on _TeamPageState {
  bool canHireJourneyman(RowData player) {
    if (player['journeyman'] != true || player['injury'] == 'Dead') {
      return false;
    }
    if ((team['treasury'] as int) < (player['price'] as int) ||
        players.where((p) => p['journeyman'] != true).length >= 11) {
      return false;
    }
    final position = TrackerData.teamPositions(
      team,
    ).where((p) => p['name'] == player['position']).firstOrNull;
    if (position == null || !(position['tags'] as List).contains('Lineman')) {
      return false;
    }
    return players
            .where(
              (p) =>
                  p['position'] == position['name'] && p['journeyman'] != true,
            )
            .length <
        (position['max'] as int);
  }

  void hireJourneyman(RowData player) {
    if (!canHireJourneyman(player)) return;
    mutate(() {
      team['treasury'] = (team['treasury'] as int) - (player['price'] as int);
      player['journeyman'] = false;
      for (final key in ['baseSkills', 'skills']) {
        (player[key] as List).removeWhere(
          (skill) => TrackerData.canonicalSkill(skill.toString()) == 'loner',
        );
      }
    });
  }

  void designateCaptain(RowData p) {
    if (!TrackerData.canDesignateCaptain(team, p)) return;
    mutate(() {
      p['captain'] = true;
      if (!(p['baseSkills'] as List).contains('Pro')) {
        (p['baseSkills'] as List).add('Pro');
      }
      if (!(p['skills'] as List).contains('Pro')) {
        (p['skills'] as List).add('Pro');
      }
    });
  }

  void toggleVeteran(RowData p) {
    if (!(p['tags'] as List).contains('Lineman') || p['journeyman'] == true) {
      message('Choose a permanently hired Lineman.');
      return;
    }
    mutate(() {
      for (final other in players.where(
        (x) => x['veteran'] == true && x['id'] != p['id'],
      )) {
        other['veteran'] = false;
        final s = other['stats'] as Map;
        s['ma'] = (int.parse(s['ma'].toString()) + 1).toString();
      }
      final was = p['veteran'] == true;
      p['veteran'] = !was;
      final s = p['stats'] as Map;
      s['ma'] = (int.parse(s['ma'].toString()) + (was ? 1 : -1)).toString();
    });
  }

  Future<void> firePlayer(RowData p) async {
    if (p['captain'] == true &&
        p['injury'] != 'Dead' &&
        !(p['injuryHistory'] as List).any(
          (x) => x.toString().startsWith('-'),
        )) {
      message(
        'A Team Captain can only be fired after a characteristic reduction.',
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fire player?'),
        content: Text(
          'Fire #' +
              p['number'].toString() +
              ' ' +
              p['name'] +
              '? All player data will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Fire'),
          ),
        ],
      ),
    );
    if (ok == true)
      mutate(
        () => (team['players'] as List).removeWhere((x) => x['id'] == p['id']),
      );
  }

  Widget field(
    String label,
    String value,
    void Function(String) changed, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) => TextFormField(
    initialValue: value,
    keyboardType: keyboard,
    maxLines: maxLines,
    decoration: InputDecoration(labelText: label),
    onChanged: changed,
  );
  Future<void> editPlayer(RowData original) async {
    final draft = TrackerData.copy(original);
    final skills = TextEditingController(
      text: (draft['skills'] as List).join(', '),
    );
    final tags = TextEditingController(
      text: (draft['tags'] as List).join(', '),
    );
    final historyText = TextEditingController(
      text: (draft['injuryHistory'] as List).join(', '),
    );
    final statuses = team['mode'] == 'Resurrection'
        ? ['Healthy', 'Badly Hurt', 'Dead']
        : ['Healthy', 'MNG', 'Temporarily retired', 'Badly Hurt', 'Dead'];
    String reduction = 'MA';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(
            'Edit #' + original['number'].toString() + ' ' + original['name'],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  field('Name', draft['name'], (v) => draft['name'] = v),
                  field(
                    'Number',
                    draft['number'].toString(),
                    (v) => draft['number'] = int.tryParse(v) ?? 0,
                    keyboard: TextInputType.number,
                  ),
                  field(
                    'Position',
                    draft['position'],
                    (v) => draft['position'] = v,
                  ),
                  TextFormField(
                    controller: tags,
                    decoration: const InputDecoration(
                      labelText: 'Tags (comma separated)',
                    ),
                  ),
                  Row(
                    children: [
                      for (final s in ['ma', 'st', 'ag', 'pa', 'av'])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: field(
                              s.toUpperCase(),
                              (draft['stats'] as Map)[s].toString(),
                              (v) => (draft['stats'] as Map)[s] = v,
                            ),
                          ),
                        ),
                    ],
                  ),
                  TextFormField(
                    controller: skills,
                    decoration: const InputDecoration(
                      labelText: 'Skills and traits (comma separated)',
                    ),
                    maxLines: 2,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: field(
                          'Primary',
                          draft['primary'],
                          (v) => draft['primary'] = v.toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: field(
                          'Secondary',
                          draft['secondary'],
                          (v) => draft['secondary'] = v.toUpperCase(),
                        ),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: draft['injury'],
                    decoration: const InputDecoration(
                      labelText: 'Injury status',
                    ),
                    items: statuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialog(() => draft['injury'] = v);
                    },
                  ),
                  if (team['mode'] != 'Resurrection')
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: reduction,
                            decoration: const InputDecoration(
                              labelText: 'Characteristic reduction',
                            ),
                            items: ['MA', 'ST', 'AG', 'PA', 'AV']
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text('-' + s),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setDialog(() => reduction = v);
                            },
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final s = reduction.toLowerCase(),
                                stats = draft['stats'] as Map;
                            final current =
                                int.tryParse(
                                  stats[s].toString().replaceAll('+', ''),
                                ) ??
                                0;
                            final next = (s == 'ag' || s == 'pa')
                                ? current + 1
                                : current - 1;
                            stats[s] = (s == 'ag' || s == 'pa' || s == 'av')
                                ? next.toString() + '+'
                                : next.toString();
                            (draft['injuryHistory'] as List).add(
                              '-' + reduction,
                            );
                            historyText.text = (draft['injuryHistory'] as List)
                                .join(', ');
                            setDialog(() {});
                          },
                          child: const Text('Record'),
                        ),
                      ],
                    ),
                  TextFormField(
                    controller: historyText,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Injury history (comma separated)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: field(
                          'TD',
                          draft['td'].toString(),
                          (v) => draft['td'] = int.tryParse(v) ?? 0,
                          keyboard: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: field(
                          'INT',
                          draft['int'].toString(),
                          (v) => draft['int'] = int.tryParse(v) ?? 0,
                          keyboard: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: field(
                          'CAS',
                          draft['cas'].toString(),
                          (v) => draft['cas'] = int.tryParse(v) ?? 0,
                          keyboard: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: field(
                          'Completions',
                          draft['comp'].toString(),
                          (v) => draft['comp'] = int.tryParse(v) ?? 0,
                          keyboard: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: field(
                          'Thrown teammates',
                          draft['throw'].toString(),
                          (v) => draft['throw'] = int.tryParse(v) ?? 0,
                          keyboard: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: field(
                          'MVPs (last 5)',
                          draft['mvp'].toString(),
                          (v) => draft['mvp'] = int.tryParse(v) ?? 0,
                          keyboard: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: field(
                          'Misc SPP',
                          draft['miscSpp'].toString(),
                          (v) => draft['miscSpp'] = int.tryParse(v) ?? 0,
                          keyboard: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  field(
                    'SPP spent',
                    draft['spentSpp'].toString(),
                    (v) => draft['spentSpp'] = int.tryParse(v) ?? 0,
                    keyboard: TextInputType.number,
                  ),
                  field(
                    'Team value contribution (GP; blank = automatic)',
                    draft['valueOverride']?.toString() ?? '',
                    (v) => draft['valueOverride'] = v.trim().isEmpty
                        ? null
                        : int.tryParse(v.replaceAll(',', '')),
                    keyboard: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      draft['skills'] = skills.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (draft['captain'] == true &&
          !(draft['skills'] as List).contains('Pro')) {
        (draft['skills'] as List).add('Pro');
      }
      draft['tags'] = tags.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      draft['injuryHistory'] = historyText.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final number = draft['number'] as int;
      if (number < 1 ||
          players.any(
            (p) => p['id'] != original['id'] && p['number'] == number,
          )) {
        message('Player number must be positive and unique.');
        return;
      }
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
        if ((draft[key] as int) < 0) {
          message('Event counts and SPP cannot be negative.');
          return;
        }
      }
      if ((draft['mvp'] as int) > 5) {
        message('Track up to five recent MVPs.');
        return;
      }
      if (team['mode'] == 'Resurrection' &&
          (draft['injuryHistory'] as List).any(
            (x) => x.toString().startsWith('-'),
          )) {
        message('Characteristic reductions are unavailable in Resurrection.');
        return;
      }
      mutate(() {
        final index = (team['players'] as List).indexWhere(
          (p) => p['id'] == original['id'],
        );
        (team['players'] as List)[index] = draft;
      });
    }
    skills.dispose();
    tags.dispose();
    historyText.dispose();
  }

  Future<void> advance(RowData p) async {
    final mode = team['mode'] as String;
    final primary = (p['primary'] as String)
        .split('')
        .where((x) => TrackerData.skillCategories.containsKey(x))
        .toList();
    final secondary = (p['secondary'] as String)
        .split('')
        .where((x) => TrackerData.skillCategories.containsKey(x))
        .toList();
    if (primary.isEmpty && (mode == 'Random' || secondary.isEmpty)) {
      message('No eligible skill category.');
      return;
    }
    String type = mode == 'Random'
        ? 'Random Primary'
        : primary.isEmpty
        ? 'Chosen Secondary'
        : 'Chosen Primary';
    String category = primary.isNotEmpty ? primary.first : secondary.first;
    String? selectedSkill;
    final types = mode == 'Random'
        ? ['Random Primary']
        : [
            if (primary.isNotEmpty) ...['Random Primary', 'Chosen Primary'],
            if (secondary.isNotEmpty) ...[
              'Random Secondary',
              'Chosen Secondary',
            ],
            'Characteristic Improvement',
          ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final cats =
              (type.contains('Primary') ? p['primary'] : p['secondary'])
                  .toString()
                  .split('')
                  .where((x) => TrackerData.skillCategories.containsKey(x))
                  .toList();
          if (cats.isNotEmpty && !cats.contains(category))
            category = cats.first;
          final options = TrackerData.eligibleSkills(p, category);
          if (selectedSkill != null && !options.contains(selectedSkill))
            selectedSkill = null;
          final cost = mode == 'Resurrection' || mode == 'Random'
              ? 0
              : TrackerData.advancementCost(
                  TrackerData.advancementCount(p),
                  type,
                );
          return AlertDialog(
            title: Text(
              mode == 'Random' ? 'Random advancement' : 'Player advancement',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mode != 'Random')
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Advancement type',
                    ),
                    items: types
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null)
                        setDialog(() {
                          type = v;
                          selectedSkill = null;
                        });
                    },
                  ),
                if (type != 'Characteristic Improvement')
                  DropdownButtonFormField<String>(
                    key: ValueKey(type + category),
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Skill category',
                    ),
                    items: cats
                        .map(
                          (x) => DropdownMenuItem(
                            value: x,
                            child: Text(TrackerData.categoryNames[x] ?? x),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null)
                        setDialog(() {
                          category = v;
                          selectedSkill = null;
                        });
                    },
                  ),
                if (type.startsWith('Chosen'))
                  DropdownButtonFormField<String>(
                    key: ValueKey('skills' + category + type),
                    initialValue: selectedSkill,
                    decoration: const InputDecoration(labelText: 'Skill'),
                    items: options
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) => setDialog(() => selectedSkill = v),
                  ),
                const SizedBox(height: 10),
                Text(
                  mode == 'Random'
                      ? 'All advanced players roll for departure after this advance.'
                      : mode == 'Resurrection'
                      ? 'No SPP required.'
                      : 'Cost: ' +
                            cost.toString() +
                            ' SPP · Available: ' +
                            (TrackerData.spp(p, team) - (p['spentSpp'] as int))
                                .toString() +
                            ' SPP',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Accept'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    final cost = mode == 'Resurrection' || mode == 'Random'
        ? 0
        : TrackerData.advancementCost(TrackerData.advancementCount(p), type);
    if (mode == 'Advanced (Default)' &&
        TrackerData.spp(p, team) - (p['spentSpp'] as int) < cost) {
      message('Not enough SPP.');
      return;
    }
    if (type == 'Characteristic Improvement') {
      await improveCharacteristic(p, cost);
      return;
    }
    final options = TrackerData.eligibleSkills(p, category);
    if (options.isEmpty) {
      message('No eligible skills in that category.');
      return;
    }
    if (type.startsWith('Chosen') && selectedSkill == null) {
      message('Choose a skill.');
      return;
    }
    String skill;
    if (type.startsWith('Random') && mode != 'Random') {
      final first = options[TrackerData.rng.nextInt(options.length)];
      final second = options[TrackerData.rng.nextInt(options.length)];
      final picked = first == second
          ? first
          : await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Choose a random result'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text(first),
                      onTap: () => Navigator.pop(ctx, first),
                    ),
                    ListTile(
                      title: Text(second),
                      onTap: () => Navigator.pop(ctx, second),
                    ),
                  ],
                ),
              ),
            );
      if (picked == null) return;
      skill = picked;
    } else {
      skill = type.startsWith('Random')
          ? options[TrackerData.rng.nextInt(options.length)]
          : selectedSkill!;
    }
    final prior = TrackerData.advancementCount(p);
    final value = mode == 'Random'
        ? (prior == 0 ? 10000 : 20000)
        : type.contains('Secondary')
        ? 40000
        : 20000;
    final departures = <String>[];
    mutate(() {
      (p['skills'] as List).add(skill);
      (p['advancements'] as List).add({
        'skill': skill,
        'type': type,
        'category': category,
        'sppCost': cost,
        'value': value,
      });
      p['spentSpp'] = (p['spentSpp'] as int) + cost;
      if (mode == 'Random') {
        for (final x in players) {
          final count = TrackerData.advancementCount(x);
          if (count == 0) continue;
          final roll = TrackerData.rng.nextInt(6) + 1;
          departures.add(
            '#' +
                x['number'].toString() +
                ' ' +
                x['name'] +
                ': rolled ' +
                roll.toString() +
                ' vs ' +
                count.toString() +
                (roll <= count ? ' — fired' : ' — stays'),
          );
          if (roll <= count)
            (team['players'] as List).removeWhere((y) => y['id'] == x['id']);
        }
      }
    });
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gained ' + skill),
        content: SingleChildScrollView(
          child: Text(
            departures.isEmpty
                ? 'Advancement recorded.'
                : departures.join('\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> improveCharacteristic(RowData p, int cost) async {
    final roll = TrackerData.rng.nextInt(8) + 1;
    final offered = switch (roll) {
      1 => ['AV'],
      2 => ['AV', 'PA'],
      3 || 4 => ['AV', 'MA', 'PA'],
      5 => ['MA', 'PA'],
      6 => ['AG', 'MA'],
      7 => ['AG', 'ST'],
      _ => ['MA', 'ST', 'AG', 'PA', 'AV'],
    };
    final stats = p['stats'] as Map, base = p['baseStats'] as Map;
    int numeric(dynamic x) =>
        int.tryParse(x.toString().replaceAll('+', '')) ?? 0;
    final allowed = offered.where((stat) {
      final s = stat.toLowerCase(),
          now = numeric(stats[s]),
          original = numeric(base[s]);
      if (now == 0) return false;
      if (s == 'ag' || s == 'pa') return now > 1 && original - now < 2;
      final maximum = {'ma': 10, 'st': 8, 'av': 11}[s]!;
      return now < maximum && now - original < 2;
    }).toList();
    if (allowed.isEmpty) {
      message('D8 roll ' + roll.toString() + ': no eligible characteristic.');
      return;
    }
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('D8 rolled ' + roll.toString()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose a characteristic to improve:'),
            for (final stat in allowed)
              ListTile(
                title: Text('+1 ' + stat),
                onTap: () => Navigator.pop(ctx, stat),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    mutate(() {
      final s = picked.toLowerCase(), current = numeric(stats[s]);
      final next = (s == 'ag' || s == 'pa') ? current - 1 : current + 1;
      stats[s] = (s == 'ag' || s == 'pa' || s == 'av')
          ? next.toString() + '+'
          : next.toString();
      (p['advancements'] as List).add({
        'skill': '+1 ' + picked,
        'type': 'Characteristic Improvement',
        'category': '',
        'sppCost': cost,
        'value': 0,
      });
      p['spentSpp'] = (p['spentSpp'] as int) + cost;
    });
    message('+1 ' + picked + ' recorded.');
  }
}
