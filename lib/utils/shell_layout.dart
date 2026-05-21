import '../state/view_mode_controller.dart';
import '../theme/mq_metrics.dart';

// The mobile UI renders inside the iPhone silhouette once the viewport exceeds
// the reference phone (iPhone 16 Pro, 393×852 logical) plus cushion; below this
// it renders bare. These mirror IphoneFrame's logical size but live here so the
// resolver stays free of widget-layer dependencies.
const double _framedMinWidth = 393 + 100;
const double _framedMinHeight = 852 + 200;

/// The three ways the app shell can present itself.
enum MqShellLayout {
  /// Mobile UI rendered directly (small viewport — a real phone or a narrow
  /// browser window).
  bareMobile,

  /// Mobile UI scaled inside the hand-drawn iPhone silhouette (large viewport
  /// running the mobile presentation).
  framedMobile,

  /// Full desktop layout: sidebar nav + multi-column content (web only).
  desktop,
}

/// Pure classifier for the shell layout. Kept free of `kIsWeb` so it can be
/// unit-tested directly — callers pass [isWeb] (production passes `kIsWeb`).
MqShellLayout resolveShellLayout({
  required bool isWeb,
  required double width,
  required double height,
  required MqViewMode viewMode,
}) {
  if (isWeb &&
      width >= MqLayout.desktopBreakpoint &&
      viewMode == MqViewMode.desktop) {
    return MqShellLayout.desktop;
  }
  if (width > _framedMinWidth || height > _framedMinHeight) {
    return MqShellLayout.framedMobile;
  }
  return MqShellLayout.bareMobile;
}

/// Whether the desktop↔mobile toggle should be offered. True only on a wide
/// web window, regardless of the current [MqViewMode].
bool toggleAvailable({required bool isWeb, required double width}) =>
    isWeb && width >= MqLayout.desktopBreakpoint;
