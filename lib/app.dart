import 'package:flutter/cupertino.dart';
import 'home_page.dart';
import 'widgets/iphone_frame.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Masquerade - Utility Toolbox',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
        barBackgroundColor: CupertinoColors.systemBackground,
        textTheme: CupertinoTextThemeData(
          primaryColor: CupertinoColors.label,
          textStyle: TextStyle(
            color: CupertinoColors.label,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.41,
          ),
          actionTextStyle: TextStyle(
            color: CupertinoColors.systemBlue,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.41,
          ),
          tabLabelTextStyle: TextStyle(
            color: CupertinoColors.secondaryLabel,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.24,
          ),
          navTitleTextStyle: TextStyle(
            color: CupertinoColors.label,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.41,
          ),
          navLargeTitleTextStyle: TextStyle(
            color: CupertinoColors.label,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.41,
          ),
          navActionTextStyle: TextStyle(
            color: CupertinoColors.systemBlue,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.41,
          ),
          pickerTextStyle: TextStyle(
            color: CupertinoColors.label,
            fontSize: 21,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.41,
          ),
          dateTimePickerTextStyle: TextStyle(
            color: CupertinoColors.label,
            fontSize: 21,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.41,
          ),
        ),
      ),
      home: const ResponsiveLayout(child: MyHomePage(title: 'Masquerade')),
    );
  }
}
