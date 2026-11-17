import 'package:flutter/material.dart';

class GameClockPage extends StatefulWidget {
  const GameClockPage({super.key});

  @override
  State<GameClockPage> createState() => _GameClockPageState();
}

class _GameClockPageState extends State<GameClockPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static const _defaultTeamNames = ['Home Team', 'Away Team'];
  final _names = [
    TextEditingController(text: _defaultTeamNames[0]),
    TextEditingController(text: _defaultTeamNames[1]),
  ];
  final _times = [
    TextEditingController(text: '0:45:00'),
    TextEditingController(text: '0:45:00'),
  ];
  final _totalTime = TextEditingController(text: '1:30:00');
  final _timeFocus = [FocusNode(), FocusNode(), FocusNode()];
  final _remainingMs = [2700000, 2700000];
  late final AnimationController _clock;
  int? _runningTeam;
  int _startRemainingMs = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this)..addListener(_onTick);
    _clock.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && _runningTeam != null) {
        final team = _runningTeam!;
        setState(() {
          _remainingMs[team] = 0;
          _runningTeam = null;
          _syncTimeFields();
        });
      }
    });
    for (var i = 0; i < _timeFocus.length; i++) {
      final field = i;
      _timeFocus[i].addListener(() {
        if (_timeFocus[field].hasFocus) {
          _pauseClock();
        } else {
          _applyTimeEdit(field);
        }
      });
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    for (final controller in [..._names, ..._times, _totalTime]) {
      controller.dispose();
    }
    for (final focus in _timeFocus) {
      focus.dispose();
    }
    super.dispose();
  }

  static String _formatTime(int milliseconds) {
    final seconds = (milliseconds + 999) ~/ 1000;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainder = seconds % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  static int? _parseTime(String input) {
    final parts = input.trim().split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final values = parts.map(int.tryParse).toList();
    if (values.any((value) => value == null)) return null;
    final hours = parts.length == 3 ? values[0]! : 0;
    final minutes = parts.length == 3 ? values[1]! : values[0]!;
    final seconds = values.last!;
    if (hours < 0 ||
        hours > 99 ||
        minutes < 0 ||
        (parts.length == 3 && minutes > 59) ||
        seconds < 0 ||
        seconds > 59) {
      return null;
    }
    final totalSeconds = hours * 3600 + minutes * 60 + seconds;
    if (totalSeconds > 99 * 3600 + 59 * 60 + 59) return null;
    return totalSeconds * 1000;
  }

  void _syncTimeFields() {
    for (var i = 0; i < 2; i++) {
      if (!_timeFocus[i].hasFocus) {
        _times[i].text = _formatTime(_remainingMs[i]);
      }
    }
    if (!_timeFocus[2].hasFocus) {
      _totalTime.text = _formatTime(_remainingMs[0] + _remainingMs[1]);
    }
  }

  void _onTick() {
    final team = _runningTeam;
    if (team == null) return;
    final next = (_startRemainingMs * _clock.value).ceil();
    if (_formatTime(next) != _formatTime(_remainingMs[team])) {
      setState(() {
        _remainingMs[team] = next;
        _syncTimeFields();
      });
    } else {
      _remainingMs[team] = next;
    }
  }

  void _stopRunningClock() {
    final team = _runningTeam;
    if (team == null) return;
    _remainingMs[team] = (_startRemainingMs * _clock.value).ceil();
    _runningTeam = null;
    _clock.stop();
  }

  void _pauseClock() {
    if (_runningTeam == null) return;
    setState(() {
      _stopRunningClock();
      _syncTimeFields();
    });
  }

  void _startClock(int team) {
    _stopRunningClock();
    if (_remainingMs[team] <= 0) return;
    setState(() {
      _runningTeam = team;
      _startRemainingMs = _remainingMs[team];
      _clock.duration = Duration(milliseconds: _startRemainingMs);
      _clock.reverse(from: 1);
      _syncTimeFields();
    });
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset game clock?'),
        content: const Text(
          'Restore the default team names and 1:30:00 game time, split into 45:00 for each team? The running clock will stop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _stopRunningClock();
      _remainingMs[0] = 2700000;
      _remainingMs[1] = 2700000;
      _names[0].text = _defaultTeamNames[0];
      _names[1].text = _defaultTeamNames[1];
      _times[0].text = '0:45:00';
      _times[1].text = '0:45:00';
      _totalTime.text = '1:30:00';
    });
  }

  void _applyTimeEdit(int field) {
    if (!mounted) return;
    final controller = field == 2 ? _totalTime : _times[field];
    final parsed = _parseTime(controller.text);
    if (parsed == null) {
      _syncTimeFields();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter time as H:MM:SS or M:SS.')),
      );
      return;
    }
    setState(() {
      _stopRunningClock();
      if (field == 2) {
        _remainingMs[0] = (parsed ~/ 2000) * 1000;
        _remainingMs[1] = parsed - _remainingMs[0];
      } else {
        _remainingMs[field] = parsed;
      }
      _syncTimeFields();
    });
  }

  String _teamName(int team) {
    final name = _names[team].text.trim();
    return name.isEmpty ? _defaultTeamNames[team] : name;
  }

  Widget _teamCard(int team) {
    final running = _runningTeam == team;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: Key('teamName$team'),
              controller: _names[team],
              decoration: InputDecoration(
                labelText: team == 0 ? 'Home team name' : 'Away team name',
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              key: Key('teamTime$team'),
              controller: _times[team],
              focusNode: _timeFocus[team],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 40,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.bold,
                color: running ? Theme.of(context).colorScheme.primary : null,
              ),
              decoration: const InputDecoration(
                labelText: 'Remaining time',
                hintText: 'H:MM:SS',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _timeFocus[team].unfocus(),
              onTapOutside: (_) => _timeFocus[team].unfocus(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: Key('startClock$team'),
              onPressed: _remainingMs[team] > 0 && !running
                  ? () => _startClock(team)
                  : null,
              icon: Icon(running ? Icons.timer : Icons.play_arrow),
              label: Text(
                running
                    ? '${_teamName(team)} clock running'
                    : 'Start ${_teamName(team)} clock',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const Key('gameTime'),
                controller: _totalTime,
                focusNode: _timeFocus[2],
                decoration: const InputDecoration(
                  labelText: 'Game time',
                  hintText: 'H:MM:SS',
                  helperText:
                      'Editing this splits time evenly between both teams.',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _timeFocus[2].unfocus(),
                onTapOutside: (_) => _timeFocus[2].unfocus(),
              ),
              const SizedBox(height: 20),
              _teamCard(0),
              _teamCard(1),
              OutlinedButton.icon(
                key: const Key('resetClock'),
                onPressed: _confirmReset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset to defaults'),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: const Key('pauseClock'),
                onPressed: _runningTeam == null ? null : _pauseClock,
                icon: const Icon(Icons.pause),
                label: const Text('Pause game clock'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
