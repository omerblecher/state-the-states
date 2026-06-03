// Source: C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_mode.dart
// Renamed: flagsMaster → statesMaster (Claude's discretion; see RESEARCH.md §1)
// Phase 6: Added speedTyping value + GameModeDisplay extension (D-08)
enum GameMode { learn, statesMaster, geographicalMaster, grandMaster, speedTyping }

extension GameModeDisplay on GameMode {
  String get displayName => switch (this) {
        GameMode.learn => 'Learn',
        GameMode.statesMaster => 'States Master',
        GameMode.geographicalMaster => 'Geographical Master',
        GameMode.grandMaster => 'Grand Master',
        GameMode.speedTyping => 'Name all the states',
      };
}
