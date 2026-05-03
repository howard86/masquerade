/// How a tool body's initial input arrived. Drives history-recording semantics:
/// paste-class seeds record immediately, typing seeds debounce for 5s.
enum SeedSource {
  /// No seed; body opened cold.
  none,

  /// Seed came from a paste-class event (hero card paste, scanner, programmatic
  /// switch from another tool, explicit Paste button). Records immediately.
  paste,

  /// Seed arrived via typing or some other ambient source. Records after the
  /// recorder's idle window.
  typing,
}
