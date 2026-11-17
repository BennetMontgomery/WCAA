part of 'main.dart';

extension TeamExport on _TeamPageState {
  Future<void> exportDialog() async {
    String format = 'PNG';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Export team'),
          content: DropdownButtonFormField<String>(
            initialValue: format,
            decoration: const InputDecoration(labelText: 'Format'),
            items: [
              'PNG',
              'Json',
              'CSV',
            ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (v) {
              if (v != null) setDialog(() => format = v);
            },
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
        ),
      ),
    );
    if (accepted != true) return;
    try {
      final directory = await getTemporaryDirectory();
      final clean = team['name'].toString().replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );
      final extension = format == 'Json' ? 'json' : format.toLowerCase();
      final file = File(directory.path + '/' + clean + '.' + extension);
      if (format == 'Json') {
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(team),
        );
      } else if (format == 'CSV') {
        await file.writeAsString(csvExport());
      } else {
        await file.writeAsBytes(await pngExport());
      }
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'WCAA Blood Bowl Sevens team: ' + team['name']);
    } catch (e) {
      message('Export failed: ' + e.toString());
    }
  }

  String csvValue(dynamic value) {
    final s = value is List || value is Map
        ? jsonEncode(value)
        : value?.toString() ?? '';
    return '"' + s.replaceAll('"', '""') + '"';
  }

  String csvExport() {
    const teamKeys = [
      'name',
      'race',
      'secret',
      'mode',
      'league',
      'treasury',
      'rerolls',
      'coaches',
      'cheerleaders',
      'apothecary',
    ];
    const playerKeys = [
      'number',
      'name',
      'position',
      'tags',
      'stats',
      'skills',
      'primary',
      'secondary',
      'injury',
      'injuryHistory',
      'td',
      'int',
      'cas',
      'comp',
      'throw',
      'mvp',
      'miscSpp',
      'spentSpp',
      'journeyman',
      'veteran',
      'captain',
      'advancements',
      'valueOverride',
    ];
    final header = [
      ...teamKeys.map((x) => 'team_' + x),
      'team_ctv',
      ...playerKeys.map((x) => 'player_' + x),
      'player_spp',
      'player_value',
    ];
    final rows = <List<dynamic>>[];
    for (final p in players) {
      rows.add([
        ...teamKeys.map((x) => team[x]),
        TrackerData.ctv(team),
        ...playerKeys.map((x) => p[x]),
        TrackerData.spp(p, team),
        TrackerData.playerValue(p, team['mode']),
      ]);
    }
    if (rows.isEmpty)
      rows.add([
        ...teamKeys.map((x) => team[x]),
        TrackerData.ctv(team),
        ...List.filled(playerKeys.length + 2, ''),
      ]);
    return [
      header.map(csvValue).join(','),
      ...rows.map((r) => r.map(csvValue).join(',')),
    ].join('\r\n');
  }

  List<String> exportLines() {
    final lines = <String>[
      'WCAA — BLOOD BOWL SEVENS',
      team['name'].toString(),
      team['race'].toString() +
          (team['secret'] == true ? ' (SL)' : '') +
          '  •  ' +
          team['mode'].toString(),
      'Star player pool: ' + team['league'].toString(),
      'CTV: ' +
          TrackerData.gp(TrackerData.ctv(team)) +
          '    Treasury: ' +
          TrackerData.gp(team['treasury']),
      'Rerolls: ' +
          team['rerolls'].toString() +
          '    Assistant Coaches: ' +
          team['coaches'].toString() +
          '    Cheerleaders: ' +
          team['cheerleaders'].toString() +
          '    Apothecary: ' +
          team['apothecary'].toString(),
      '',
    ];
    final ordered = players.toList()
      ..sort((a, b) {
        final pa = TrackerData.positions(
          roster,
        ).indexWhere((x) => x['name'] == a['position']);
        final pb = TrackerData.positions(
          roster,
        ).indexWhere((x) => x['name'] == b['position']);
        final c = pa.compareTo(pb);
        return c != 0 ? c : (a['number'] as int).compareTo(b['number'] as int);
      });
    for (final p in ordered) {
      final s = p['stats'] as Map;
      lines.add(
        '#' +
            p['number'].toString() +
            ' ' +
            p['name'] +
            ' — ' +
            p['position'] +
            (p['veteran'] == true ? ' · Veteran' : '') +
            (p['journeyman'] == true ? ' · Journeyman' : '') +
            (p['captain'] == true ? ' · Captain' : ''),
      );
      lines.add('Tags: ' + (p['tags'] as List).join(', '));
      lines.add(
        'MA ' +
            s['ma'].toString() +
            '  ST ' +
            s['st'].toString() +
            '  AG ' +
            s['ag'].toString() +
            '  PA ' +
            s['pa'].toString() +
            '  AV ' +
            s['av'].toString() +
            '  Primary ' +
            p['primary'] +
            '  Secondary ' +
            p['secondary'],
      );
      lines.add(
        'Skills: ' +
            (p['skills'] as List).join(', ') +
            (p['veteran'] == true ? ', Veteran' : ''),
      );
      lines.add(
        'SPP ' +
            TrackerData.spp(p, team).toString() +
            '  Spent ' +
            p['spentSpp'].toString() +
            '  TD ' +
            p['td'].toString() +
            '  INT ' +
            p['int'].toString() +
            '  CAS ' +
            p['cas'].toString() +
            '  COMP ' +
            p['comp'].toString() +
            '  Thrown ' +
            p['throw'].toString() +
            '  MVP ' +
            p['mvp'].toString() +
            '  Misc ' +
            p['miscSpp'].toString(),
      );
      lines.add(
        'Injury: ' +
            p['injury'] +
            '  History: ' +
            (p['injuryHistory'] as List).join(', '),
      );
      lines.add(
        'Advancements: ' +
            (p['advancements'] as List)
                .map(
                  (a) =>
                      (a as Map)['skill'].toString() +
                      ' (' +
                      a['type'].toString() +
                      ')',
                )
                .join(', '),
      );
      lines.add(
        'Team value: ' +
            TrackerData.gp(TrackerData.playerValue(p, team['mode'])),
      );
      lines.add('');
    }
    return lines;
  }

  Future<Uint8List> pngExport() async {
    const width = 1400.0, pad = 34.0;
    final textPainters = <TextPainter>[];
    var height = pad;
    for (final line in exportLines()) {
      final painter = TextPainter(
        text: TextSpan(
          text: line,
          style: TextStyle(
            color: Colors.black,
            fontSize: line.startsWith('WCAA') ? 28 : 20,
            fontWeight: line.startsWith('WCAA') || line.startsWith('#')
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: null,
      );
      painter.layout(maxWidth: width - 2 * pad);
      textPainters.add(painter);
      height += painter.height + 10;
    }
    height += pad;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );
    var y = pad;
    for (final painter in textPainters) {
      painter.paint(canvas, Offset(pad, y));
      y += painter.height + 10;
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    return data!.buffer.asUint8List();
  }
}
