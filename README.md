# WCAA Team Tracker

An Android Flutter app for Blood Bowl Sevens teams. Team data is stored locally on the device. It includes all 30 supplied vanilla rosters and 103 supplied Secret League rosters.

On the home page, tap a team card to open it, its trash icon to delete it after confirmation, or **Add team from JSON** to import a WCAA JSON export through the system file picker. The footer of each team page contains enlarged counters and purchase controls for rerolls, assistant coaches, cheerleaders, and an eligible apothecary.

## Run and build

From this directory:

    flutter pub get
    flutter test
    flutter analyze --no-fatal-infos
    flutter build apk --release

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. Install it on an attached Android device with `adb install -r build/app/outputs/flutter-apk/app-release.apk`. The project currently uses the Flutter template's development signing key, so configure a production signing key before distributing through an app store.

## Rules and app decisions

- The 2025 skills, traits, SPP costs, and value increases come from [Blood Bowl Base core rules](https://bloodbowlbase.ru/bb2025/core_rules/).
- Sevens budget, roster limits, staff prices, veteran, and Random progression are based on [Spike! Journal 22](https://bloodbowlbase.ru/bb2025/spike_journal/issue_22/).
- User-requested overrides: journeymen have Loner (4+); in Random mode a departure roll equal to or below the number of non-stock advancements fires a player immediately. Spike! #22 instead uses Loner (5+) and offers a payment to retain drafted players.
- Advanced is the default progression. Skill and characteristic improvement SPP costs follow the 2025 advancement table. Characteristic improvements roll a D8 for available options. Random Secondary is available at the Chosen Secondary SPP cost because the request includes that option; the published table has no separate Random Secondary cost.
- Resurrection advancement spends no SPP and excludes MNG and characteristic-reduction injury options.
- CTV includes available players, rerolls and purchased staff; players marked MNG, Temporarily retired, or Dead are excluded.
- Veteran designation applies to one permanent Lineman. The veteran's MA falls by one; changing the designation restores the previous veteran's MA. Veteran is not counted as a paid advancement.
- A Journeyman can be hired permanently from their player card for their original positional cost. Hiring keeps the same player, SPP, injuries, skills, and history, removes Loner (4+), and can be undone from the team page.
- Teams with the Team Captain rule can designate one eligible player. Araby requires the Sheikh and Pirates of Sartosa requires the Captain. The Captain gains Pro without raising player value and can only be fired after a characteristic reduction or death.
- Elementals choose their Lineman element at team creation. The other three elemental types have a 0-2 limit, and only the matching Incarnate Elemental is available. Eonir choose Forest Born or City Born at creation; Soul Weave's league effects are shown in its rule popup.
- The team editor keeps one undo history per open team page. History is cleared when the page is closed.

## Export format

JSON is UTF-8, one object per team, with schemaVersion 1. The importer reads this format. It includes:

- Team fields: id, name, race, secret, mode, league, treasury, rerolls, coaches, cheerleaders, apothecary, players, options. `options` stores roster choices such as `element` or `kin`; older version 1 files without it are accepted.
- Each player: id, name, number, position, tags, baseStats, stats, baseSkills, skills, primary, secondary, price, journeyman, veteran, captain, injury, injuryHistory, td, int, cas, comp, throw, mvp, miscSpp, spentSpp, advancements, valueOverride. Older version 1 files without `captain` are accepted.
- Each advancement: skill, type, category, sppCost, value. valueOverride is null for automatic value.
- Computed SPP, player value, and CTV are derived from these fields and the bundled roster data; they are not persisted in JSON.

CSV is UTF-8 with one row per player, repeated team fields, computed SPP/value, and JSON-encoded nested fields. A team with no players produces one row with empty player columns.

PNG is a shareable image listing team information and every player's stats, skills, event counts, injury status/history, advancements, SPP, and value.

Exports open Android's system share sheet. Save or share a JSON export to a location available in the device's file picker, then use **Add team from JSON** on the home page. Import preserves team and player data and gives the copy new internal IDs, so the same export can be imported more than once. Invalid files leave existing teams untouched. The importer accepts version 1 files up to 5 MB for races bundled in this app.

## Data

`assets/rosters.json` contains the supplied roster data without icons. `tooling/secret_2025.tsv` records the Secret League sheets in an editable form; `python3 tooling/build_secret_rosters.py` regenerates the roster asset. `assets/rules.json` bundles rule text from the 2025 SRD for offline skill popups and the supplied Secret League custom rules. See PROGRESS.md for the implementation and verification log.

The Android launcher icon uses the supplied original artwork in `assets/branding/tfl_logo.png`. Run `python3 tooling/build_launcher_icons.py` to regenerate the density-specific and adaptive launcher icons; this requires Pillow. The source artwork is kept unchanged.

The release APK has been installed and checked on a Samsung SM-S901W running Android 16. App updates preserve teams stored on the device.
