# WCAA Team Tracker progress

## 2026-11-16

1. Inspected the workspace: it was empty except for Git metadata. Flutter and Android SDK are installed.
2. Initialized a Flutter Android project with `flutter create`.
3. Verified the 2025 core rules and 2026 Spike! #22 online. Key Sevens rules: 600,000 GP budget; 7 to 11 permanent players; at most four non-Lineman players; team rerolls 100,000 GP; assistant coaches and cheerleaders 20,000 GP each (maximum three); apothecary 80,000 GP (maximum one where allowed); one Lineman veteran with -1 MA and one reroll per game.
4. ADB currently reports no attached device. The project can still be built and analyzed locally.
5. Added bundled roster data for all 30 vanilla teams and Cathay. The Secret League MVP supports Cathay; other Secret League rosters await supplied data.
6. Added bundled 2025 skill/trait rule text, local persistence, team creation and editing, player management, progression modes, staff purchases, undo, and PNG/JSON/CSV sharing.
7. Added Advanced and Resurrection characteristic improvements using the 2025 D8 table and SPP costs. Added rule-name normalization so every bundled roster skill and trait opens its local rule text.
8. Ran Flutter tests (7 passing) and static analysis (no errors or warnings; style infos remain).
9. Built the final Android debug APK at build/app/outputs/flutter-apk/app-debug.apk.
10. Started an optional release APK build, then stopped it when the user requested a halt for today. The debug APK remains complete and installable. No device installation or device testing was attempted.

## 2026-11-16 — connected Android device

1. Connected to a Samsung SM-S901W running Android 16 and installed the debug APK. Confirmed the empty home screen and alphabetical team selector.
2. Created an Advanced Amazons team. Verified 600,000 GP starting treasury, hiring an Eagle Warrior for 50,000 GP, CTV calculation, the tappable Dodge rule, veteran designation with -1 MA, and reroll purchase followed by Undo.
3. Edited a player's name, exported PNG/JSON/CSV, and read the JSON and CSV files back from the device. The JSON uses schema version 1; CSV parsed as one player row. Force-stopped and relaunched the app to verify local persistence.
4. Created a Random Cathay team from the Secret League section. Verified the (SL) header, draft list, star player pool, positional prices, and a random advancement that fired the player after a failed d6 retention roll.
5. Created a Resurrection Amazons team. Added Block without SPP, verified CTV rose by 20,000 GP, and confirmed that the injury choices omit Miss Next Game and characteristic reduction.
6. Cleared the app data containing only the test teams created above, returning the installed app to its empty starting state.
7. Built the release APK at `build/app/outputs/flutter-apk/app-release.apk` (50.0 MB). Replaced the debug build on the device with the release build, launched it, and visually confirmed the empty home screen.

## Remaining

- Other Secret League rosters require their roster data; Cathay is the only Secret League team in this MVP, as requested.

## 2026-11-16 — home and footer polish

1. Increased footer control text from 11 to 13 points and expanded chip padding and spacing. On the connected phone, all four controls remain readable in two rows beside the treasury.
2. Added a delete icon to each home-page team card. It opens a confirmation dialog naming the team; Cancel preserves it, while Delete removes the team and persists the updated list.
3. Added a widget test for Cancel, confirmed Delete, and persisted removal. All eight Flutter tests pass. Static analysis reports no errors or warnings; existing style notices remain.
4. Built and installed the updated 50.0 MB release APK over the existing app. The two teams already saved on the device survived the update. Opened and cancelled the delete dialog on the device, then verified both teams remained.

## 2026-11-16 — JSON import

1. Added Flutter's official `file_selector` dependency to open JSON files with the Android system picker.
2. Added **Add team from JSON** to the home page. It reads a selected file, validates version 1 WCAA team and player fields, saves a copy with fresh internal IDs, and reports import errors without changing existing teams.
3. Added JSON round-trip and malformed-file tests covering player history, statistics, advancements, value override, and duplicate imports. All ten Flutter tests pass. Static analysis reports style infos only.
4. Built and installed the updated 50.1 MB release APK over the existing app without clearing local data.
5. Picked a version 1 WCAA JSON file from Android Downloads. The imported team appeared with the expected 170,000 GP CTV; its player card showed the name, skill, event totals, SPP, and team value, and the editor retained the injury history.
6. Force-stopped and relaunched the app to verify that the imported team persisted. Deleted only the temporary test team and its Downloads file afterward. The two previously saved teams remain on the device.

## 2026-11-16 — Secret League expansion and Team Captain

1. Compared the supplied Secret League 2025 sheets against the public FUMBBL roster API to check team and positional names, then transcribed the supplied sheets into `tooling/secret_2025.tsv`. Added a repeatable generator in `tooling/build_secret_rosters.py` and regenerated `assets/rosters.json`: 30 vanilla and 103 Secret League rosters, 605 positions total. The older API snapshot was discarded; the app asset uses the supplied screenshots.
2. Corrected Orc Goblin Lineman PA to 4+. Updated Cathay to the latest supplied sheet, including its tier and Foo Statue details.
3. Added Team Captain designation for Human, Orcs, Araby, Clan Mors, Everpeak, Nuln, Pirates of Sartosa, and Sisters of Sigmar. Araby requires the Sheikh and Pirates of Sartosa requires the Captain. Designation adds Pro at no extra player value and restricts firing according to the 2025 rule. Captain status is included in JSON, CSV, and PNG exports, and older JSON imports remain valid.
4. Added Elementals' lineman-element choice and matching Incarnate Elemental restriction, Eonir kin choice, and screenshot-specific Big Guy limits. The choices are stored in JSON and restored on import. Added custom Soul Weave and Changeling popup rule summaries.
5. Added roster, Team Captain, Elemental choice, Orc PA, and JSON round-trip tests. All 14 Flutter tests pass; static analysis reports style infos only, with no errors or warnings.
6. Built the 50.2 MB release APK and installed it over the existing Android app without clearing data. The three pre-existing teams were still present after launch.
7. On the Samsung SM-S901W, verified the expanded Secret League selector, created a temporary Clan Mors team, hired a Clan Rat, and designated that player Captain. Pro and the Team Captain link appeared; CTV stayed at 50,000 GP. Deleted only the temporary test team and confirmed the pre-existing three teams remained.

## 2026-11-17 — permanent Journeyman hiring

1. Added a **Hire permanently** action to Journeyman player cards, priced at the player's base positional cost. The action checks treasury, the 11-player permanent roster cap, and the positional limit.
2. Hiring retains the existing player record and all accrued SPP, advancements, and injury history. It removes the Journeyman flag and Loner from base and current skills, then deducts GP through the existing undoable team mutation.
3. Added a widget test covering GP deduction, unchanged identity and history, preserved SPP and learned skill, Loner removal, and Undo. All 15 Flutter tests pass. Static analysis has no errors or warnings; existing style infos remain.
4. Built and installed the 50.2 MB release APK over the existing Android app without clearing its data. Created a temporary Amazons team on the Samsung SM-S901W, added Journeymen, and hired one. The player lost the Journeyman label and Loner, while treasury fell from 600,000 to 550,000 GP. Deleted only the temporary team and confirmed the two pre-existing teams remain.

## 2026-11-17 — draft list row sizing

1. Changed the draft DataTable to keep its 48 pixel minimum row height while allowing each row to grow to fit wrapped skills and tags.
2. Added a Chaos Renegades widget regression test that checks the Troll's final skill ends above the Ogre row. All 16 Flutter tests pass. Static analysis has no errors or warnings; existing style infos remain.
3. Built and installed the 50.2 MB release APK over the Android app, preserving saved teams. Expanded the existing Chaos Renegades draft list on the Samsung SM-S901W and confirmed its long Troll skill list stays within its row, with the Ogre row starting below it.

## 2026-11-17 — crossed-out roster values

1. Audited the bundled roster data for `~~` markup. Corrected the Chaos Renegades Ogre from `Loner (~~4+~~ 3+)` to `Loner (4+)`, using the user's confirmed value. Corrected the Human, Imperial Nobility, and Old World Alliance Ogre secondary access fields from `AG~~M~~` to `AG`, matching the supplied screenshots.
2. Added a regression test that rejects crossed-out values in any of the 133 roster records and checks all four corrected fields. All 17 Flutter tests pass; static analysis has no errors or warnings, only existing style infos.
3. Built and installed the 50.2 MB release APK over the existing Android app without clearing data. On the Samsung SM-S901W, confirmed the saved Chaos Renegades draft list displays `Loner (4+)` for the Ogre and the two saved teams remain.

## 2026-11-17 — original artwork launcher icon

1. Copied the user's `tfl logo.png` unchanged to `assets/branding/tfl_logo.png` and confirmed matching SHA-256 hashes. Added a repeatable Pillow script to generate standard Android launcher sizes and a padded adaptive foreground, with a black background that keeps the shield's white outline visible.
2. Added the Android adaptive icon resource. Built the 50.2 MB release APK and installed it over the existing app without clearing data.
3. Checked Android's WCAA app details screen on the Samsung SM-S901W: the supplied shield artwork is displayed as the app icon. Reopened WCAA and confirmed its saved team remained available.

## 2026-11-17 — game clock

1. Added **Teams** and **Game Clock** tabs to the home-page header. The Teams tab retains roster management.
2. Added editable team names and time fields. Game time starts at 1:30:00, split into 45:00 for each team. Starting either team clock stops the other, and a fixed Pause button stops the active clock. Clock state survives tab changes.
3. Added widget coverage for defaults, switching, pausing, editing, expiration, invalid input, and tab changes. All 20 Flutter tests pass; static analysis has no errors or warnings, only existing style notices.
4. Built and installed the 50.7 MB release APK over the existing app on the Samsung SM-S901W without clearing data. Visually checked both tabs and the fixed Pause control; the saved team remained available.

## 2026-11-17 — game clock reset

1. Added **Reset to defaults** beneath both team clocks. A confirmation dialog offers Cancel or Reset; confirming stops the active clock and restores Home Team, Away Team, 1:30:00 total, and 45:00 per team.
2. Added a widget test for cancellation and confirmed reset while a clock is running. All 21 Flutter tests pass; static analysis has no errors or warnings, only existing style notices.
3. Built and installed the updated 50.7 MB release APK on the Samsung SM-S901W without clearing saved teams. Visually checked the button placement and confirmation dialog.
