import 'package:flutter/cupertino.dart';
import 'package:device_frame/device_frame.dart';

/// A responsive wrapper that shows device frame on larger screens
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // iPhone Pro dimensions: 393x852
        const double iphoneWidth = 393;
        const double iphoneHeight = 852;

        // Show device frame if screen is larger than iPhone Pro
        if (constraints.maxWidth > iphoneWidth + 100 ||
            constraints.maxHeight > iphoneHeight + 200) {
          return Container(
            padding: const EdgeInsets.all(16.0),
            color: CupertinoColors.systemGrey6,
            child: Center(
              child: DeviceFrame(
                device: Devices.ios.iPhone16Pro,
                isFrameVisible: true,
                orientation: Orientation.portrait,
                screen: child,
              ),
            ),
          );
        }

        // For smaller screens, show content directly
        return child;
      },
    );
  }
}
