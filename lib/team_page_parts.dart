part of 'main.dart';

extension TeamPageParts on _TeamPageState {
  Widget otherPositionSection() {
    final known = TrackerData.teamPositions(team).map((p) => p['name']).toSet();
    final other = players.where((p) => !known.contains(p['position'])).toList()
      ..sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    if (other.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edited positions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            for (final p in other) playerCard(p),
          ],
        ),
      ),
    );
  }

  Widget skillLink(String skill) => InkWell(
    onTap: () => showSkill(skill),
    child: Text(
      skill,
      style: const TextStyle(
        decoration: TextDecoration.underline,
        color: red,
        fontSize: 13,
      ),
    ),
  );
  Widget skillWrap(Iterable<dynamic> skills) => Wrap(
    spacing: 6,
    runSpacing: 4,
    children: skills.map((s) => skillLink(s.toString())).toList(),
  );
  void showSkill(String skill) {
    final key = TrackerData.canonicalSkill(skill);
    final body =
        TrackerData.rules.entries
            .where((entry) => TrackerData.canonicalSkill(entry.key) == key)
            .map((entry) => entry.value)
            .firstOrNull ??
        'Rule text is not available in the bundled 2025 SRD.';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(skill),
        content: SingleChildScrollView(child: Text(body.toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget draftTable() {
    final positions = TrackerData.teamPositions(team);
    return Card(
      child: ExpansionTile(
        title: const Text(
          'Team draft list',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(team['league'] + ' · Tier ' + roster['tier'].toString()),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFFFE9E9),
                    ),
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: double.infinity,
                    columns: const [
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Position / Tags')),
                      DataColumn(label: Text('MA')),
                      DataColumn(label: Text('ST')),
                      DataColumn(label: Text('AG')),
                      DataColumn(label: Text('PA')),
                      DataColumn(label: Text('AV')),
                      DataColumn(label: Text('Skills')),
                      DataColumn(label: Text('Primary')),
                      DataColumn(label: Text('Secondary')),
                      DataColumn(label: Text('Price')),
                    ],
                    rows: [
                      for (final pos in positions)
                        DataRow(
                          cells: [
                            DataCell(Text('0-' + pos['max'].toString())),
                            DataCell(
                              SizedBox(
                                width: 155,
                                child: Text(
                                  pos['name'] +
                                      '\n' +
                                      (pos['tags'] as List).join(', '),
                                ),
                              ),
                            ),
                            for (final stat in ['ma', 'st', 'ag', 'pa', 'av'])
                              DataCell(Text(pos[stat].toString())),
                            DataCell(
                              SizedBox(
                                width: 220,
                                child: skillWrap(pos['skills'] as List),
                              ),
                            ),
                            DataCell(Text(pos['primary'])),
                            DataCell(Text(pos['secondary'])),
                            DataCell(Text(TrackerData.gp(pos['price']))),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Roster re-roll: ' +
                      TrackerData.gp(roster['rerollPrice'] ?? 100000) +
                      ' · Sevens re-roll: 100,000 GP · Apothecary: ' +
                      (roster['apothecary'] ? 'Yes' : 'No'),
                ),
                Text('Leagues: ' + (roster['leagues'] as List).join(' OR ')),
                for (final option in roster['creationOptions'] ?? [])
                  Text(
                    option['label'] +
                        ': ' +
                        ((team['options'] as Map?)?[option['key']] ??
                                (option['choices'] as List).first)
                            .toString(),
                  ),
                Text(
                  'Special Rules: ' +
                      ((roster['specialRules'] as List).isEmpty
                          ? 'None'
                          : (roster['specialRules'] as List).join(', ')),
                ),
                for (final note in roster['notes'] ?? []) Text(note.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget positionSection(RowData pos) {
    final group = players.where((p) => p['position'] == pos['name']).toList()
      ..sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    final journeymanAllowed =
        (pos['max'] == 16 &&
        (pos['tags'] as List).contains('Lineman') &&
        players.where(TrackerData.available).length < 7);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pos['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '0-' +
                            pos['max'].toString() +
                            ' · ' +
                            TrackerData.gp(pos['price']),
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: canAdd(pos) ? () => addPlayer(pos) : null,
                  child: const Text('Add'),
                ),
              ],
            ),
            if (journeymanAllowed)
              OutlinedButton(
                onPressed: () => addJourneyman(pos),
                child: const Text('Add Journeymen'),
              ),
            for (final p in group) playerCard(p),
          ],
        ),
      ),
    );
  }

  Widget playerCard(RowData p) {
    final stats = p['stats'] as Map;
    final tags = (p['tags'] as List).join(', ');
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#' +
                      p['number'].toString() +
                      ' ' +
                      p['name'] +
                      (p['journeyman'] == true ? ' · Journeyman' : '') +
                      (p['veteran'] == true ? ' · Veteran' : '') +
                      (p['captain'] == true ? ' · Captain' : ''),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit player',
                onPressed: () => editPlayer(p),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              IconButton(
                tooltip: 'Fire player',
                onPressed: () => firePlayer(p),
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
          Text(p['position'] + ' · ' + tags),
          Text(
            'MA ' +
                stats['ma'].toString() +
                '   ST ' +
                stats['st'].toString() +
                '   AG ' +
                stats['ag'].toString() +
                '   PA ' +
                stats['pa'].toString() +
                '   AV ' +
                stats['av'].toString(),
          ),
          const SizedBox(height: 5),
          skillWrap(p['skills'] as List),
          if (p['veteran'] == true) skillLink('Veteran'),
          if (p['captain'] == true) skillLink('Team Captain'),
          const SizedBox(height: 5),
          Text('Primary: ' + p['primary'] + '    Secondary: ' + p['secondary']),
          Text(
            'SPP: ' +
                TrackerData.spp(p, team).toString() +
                ' (spent ' +
                p['spentSpp'].toString() +
                ')' +
                '   Injury: ' +
                p['injury'],
          ),
          Text(
            'TD ' +
                p['td'].toString() +
                ' · INT ' +
                p['int'].toString() +
                ' · CAS ' +
                p['cas'].toString() +
                ' · COMP ' +
                p['comp'].toString() +
                ' · Thrown ' +
                p['throw'].toString() +
                ' · MVP ' +
                p['mvp'].toString(),
          ),
          Text(
            'Team value: ' +
                TrackerData.gp(TrackerData.playerValue(p, team['mode'])),
          ),
          Wrap(
            spacing: 6,
            children: [
              if (p['journeyman'] == true)
                TextButton(
                  onPressed: canHireJourneyman(p)
                      ? () => hireJourneyman(p)
                      : null,
                  child: Text(
                    'Hire permanently (' +
                        TrackerData.gp(p['price'] as int) +
                        ')',
                  ),
                ),
              if ((p['tags'] as List).contains('Lineman'))
                TextButton(
                  onPressed: () => toggleVeteran(p),
                  child: Text(
                    p['veteran'] == true ? 'Remove Veteran' : 'Make Veteran',
                  ),
                ),
              if (TrackerData.canDesignateCaptain(team, p))
                TextButton(
                  onPressed: () => designateCaptain(p),
                  child: const Text('Make Captain'),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => advance(p),
              child: const Text('Advance'),
            ),
          ),
        ],
      ),
    );
  }

  Widget footer() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    miniBuy('Rerolls', 'rerolls', 100000, 6),
                    miniBuy('Assistant Coaches', 'coaches', 20000, 3),
                    miniBuy('Cheerleaders', 'cheerleaders', 20000, 3),
                    if (roster['apothecary'] == true)
                      miniBuy('Apothecary', 'apothecary', 80000, 1),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: editTreasury,
                    child: Text(
                      TrackerData.gp(team['treasury']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Text(
                    'CTV ' + TrackerData.gp(TrackerData.ctv(team)),
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: history.isEmpty ? null : undo,
                child: const Text('Undo'),
              ),
              FilledButton(
                onPressed: exportDialog,
                child: const Text('Export'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget miniBuy(String label, String key, int price, int limit) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black12),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label + ' ' + team[key].toString(),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(width: 5),
        InkWell(
          onTap:
              (team[key] as int) >= limit || (team['treasury'] as int) < price
              ? null
              : () => buy(key, price, limit),
          child: const Text(
            'Buy',
            style: TextStyle(
              color: red,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
