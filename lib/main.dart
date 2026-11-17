import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'tracker_data.dart';
import 'team_import.dart';
import 'game_clock_page.dart';
part 'team_page_parts.dart';
part 'team_actions.dart';
part 'team_export.dart';

const red = Color(0xFFB81923);
const cream = Color(0xFFF8F6EF);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TrackerData.load();
  runApp(const TrackerApp());
}

class TrackerApp extends StatelessWidget {
  const TrackerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'WCAA',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: red, primary: red),
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: red,
        foregroundColor: Colors.white,
      ),
      useMaterial3: true,
    ),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void refresh() {
    setState(() {});
    TrackerData.save();
  }

  Future<void> add() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RacePage()),
    );
    if (!mounted || id == null) return;
    refresh();
    open(id);
  }

  Future<void> open(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamPage(teamId: id, onChanged: refresh),
      ),
    );
    if (mounted) refresh();
  }

  Future<void> deleteTeam(RowData team) async {
    final id = team['id'];
    final name = team['name'];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete team?'),
        content: Text(
          'Delete $name and all its players? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => TrackerData.teams.removeWhere((t) => t['id'] == id));
    await TrackerData.save();
  }

  Future<void> importJson() async {
    try {
      const jsonFiles = XTypeGroup(
        label: 'JSON files',
        extensions: ['json'],
        mimeTypes: ['application/json'],
      );
      final file = await openFile(acceptedTypeGroups: [jsonFiles]);
      if (file == null || !mounted) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('The selected JSON file is too large.');
      }
      final imported = TeamImport.fromJson(await file.readAsString());
      TrackerData.teams.add(imported);
      try {
        await TrackerData.save();
      } catch (_) {
        TrackerData.teams.remove(imported);
        rethrow;
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Imported ${imported['name']}')));
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: ${e.message}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import failed: Could not read file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'WCAA',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        tabs: const [
          Tab(text: 'Teams'),
          Tab(text: 'Game Clock'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: [_buildTeams(), const GameClockPage()],
    ),
  );

  Widget _buildTeams() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (TrackerData.teams.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text('No teams created yet', style: TextStyle(fontSize: 18)),
          ),
        ),
      for (final team in TrackerData.teams)
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => open(team['id']),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          team['name'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete team',
                        onPressed: () => deleteTeam(team),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(team['race'] + ' - ' + team['mode']),
                  const SizedBox(height: 4),
                  Text('CTV: ' + TrackerData.gp(TrackerData.ctv(team))),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 6),
      OutlinedButton(onPressed: add, child: const Text('+ Add Team')),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: importJson,
        child: const Text('Add team from JSON'),
      ),
    ],
  );
}

class RacePage extends StatefulWidget {
  const RacePage({super.key});
  @override
  State<RacePage> createState() => _RacePageState();
}

class _RacePageState extends State<RacePage> {
  Future<void> choose(RowData roster) async {
    String mode = TrackerData.modes.first;
    String league = (roster['leagues'] as List).first.toString();
    final choices = <String, String>{
      for (final option in roster['creationOptions'] ?? [])
        option['key'] as String: (option['choices'] as List).first as String,
    };
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(
            'Creating ' +
                roster['name'] +
                ' team. Select progression mode and star player pool.',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(
                    labelText: 'Progression Mode',
                  ),
                  items: TrackerData.modes
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => mode = v);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: league,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Star player pool',
                  ),
                  items: (roster['leagues'] as List)
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.toString(),
                          child: Text(
                            m.toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => league = v);
                  },
                ),
                for (final option in roster['creationOptions'] ?? []) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: choices[option['key']],
                    isExpanded: true,
                    decoration: InputDecoration(labelText: option['label']),
                    items: (option['choices'] as List)
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value.toString(),
                            child: Text(value.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialog(() => choices[option['key']] = value);
                      }
                    },
                  ),
                ],
              ],
            ),
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
    if (created != true || !mounted) return;
    final team = TrackerData.createTeam(roster, mode, league);
    team['options'] = choices;
    TrackerData.teams.add(team);
    await TrackerData.save();
    if (mounted) Navigator.pop(context, team['id'] as String);
  }

  @override
  Widget build(BuildContext context) {
    final vanilla = TrackerData.rosters
        .where((x) => x['secret'] == false)
        .toList();
    final secret = TrackerData.rosters
        .where((x) => x['secret'] == true)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Select New Team')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'VANILLA TEAMS',
              style: TextStyle(
                color: red,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (final r in vanilla)
            ListTile(
              title: Text(r['name']),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => choose(r),
            ),
          const Divider(height: 32, thickness: 3),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'FUMBBL SECRET LEAGUE',
              style: TextStyle(
                color: red,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (final r in secret)
            ListTile(
              title: Text(r['name']),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => choose(r),
            ),
        ],
      ),
    );
  }
}

class TeamPage extends StatefulWidget {
  final String teamId;
  final VoidCallback onChanged;
  const TeamPage({super.key, required this.teamId, required this.onChanged});
  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  final history = <RowData>[];
  RowData get team =>
      TrackerData.teams.firstWhere((t) => t['id'] == widget.teamId);
  RowData get roster => TrackerData.roster(team['race']);
  List<RowData> get players => TrackerData.players(team);
  void mutate(void Function() fn) {
    history.add(TrackerData.copy(team));
    fn();
    setState(() {});
    widget.onChanged();
  }

  void undo() {
    if (history.isEmpty) return;
    final previous = history.removeLast();
    final index = TrackerData.teams.indexWhere((t) => t['id'] == widget.teamId);
    TrackerData.teams[index] = previous;
    setState(() {});
    widget.onChanged();
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<String?> askText(
    String title,
    String initial, {
    TextInputType? keyboard,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboard,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> rename() async {
    final name = await askText('Team name', team['name']);
    if (name != null && name.isNotEmpty) mutate(() => team['name'] = name);
  }

  Future<void> editTreasury() async {
    final text = await askText(
      'Team treasury (GP)',
      team['treasury'].toString(),
      keyboard: TextInputType.number,
    );
    final amount = int.tryParse((text ?? '').replaceAll(',', ''));
    if (amount != null && amount >= 0) mutate(() => team['treasury'] = amount);
  }

  bool canAdd(RowData pos) {
    if ((team['treasury'] as int) < (pos['price'] as int)) return false;
    if (players.where((p) => !p['journeyman']).length >= 11) return false;
    if (players
            .where((p) => p['position'] == pos['name'] && !p['journeyman'])
            .length >=
        (pos['max'] as int))
      return false;
    if (!(pos['tags'] as List).contains('Lineman') &&
        players
                .where(
                  (p) =>
                      !(p['tags'] as List).contains('Lineman') &&
                      !p['journeyman'],
                )
                .length >=
            4)
      return false;
    final bigGuyLimit = roster['maxBigGuys'];
    if (bigGuyLimit is int &&
        (pos['tags'] as List).contains('Big Guy') &&
        players
                .where(
                  (p) =>
                      (p['tags'] as List).contains('Big Guy') &&
                      p['journeyman'] != true,
                )
                .length >=
            bigGuyLimit) {
      return false;
    }
    return true;
  }

  void addPlayer(RowData pos) {
    if (!canAdd(pos)) return;
    mutate(() {
      final js = players.where((p) => p['journeyman'] == true).toList()
        ..sort(
          (a, b) =>
              TrackerData.spp(a, team).compareTo(TrackerData.spp(b, team)),
        );
      if (js.isNotEmpty)
        (team['players'] as List).removeWhere((p) => p['id'] == js.first['id']);
      (team['players'] as List).add(TrackerData.createPlayer(team, pos));
      team['treasury'] = (team['treasury'] as int) - (pos['price'] as int);
    });
  }

  void addJourneyman(RowData pos) {
    if (players.where(TrackerData.available).length >= 7) return;
    mutate(() {
      while (players.where(TrackerData.available).length < 7) {
        (team['players'] as List).add(
          TrackerData.createPlayer(team, pos, journeyman: true),
        );
      }
    });
  }

  void buy(String key, int price, int limit) {
    if ((team[key] as int) >= limit || (team['treasury'] as int) < price)
      return;
    mutate(() {
      team[key] = (team[key] as int) + 1;
      team['treasury'] = (team['treasury'] as int) - price;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InkWell(
              onTap: rename,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      team['name'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, size: 20),
                ],
              ),
            ),
            Text(
              team['race'] + (team['secret'] == true ? ' (SL)' : ''),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
      centerTitle: false,
    ),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        draftTable(),
        const SizedBox(height: 16),
        const Text(
          'PLAYERS',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: red,
          ),
        ),
        const SizedBox(height: 6),
        for (final pos in TrackerData.teamPositions(team)) positionSection(pos),
        otherPositionSection(),
      ],
    ),
    bottomNavigationBar: footer(),
  );
}
