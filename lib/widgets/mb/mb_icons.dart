import 'package:flutter/cupertino.dart';

/// Magic Box icon set. Maps semantic names to nearest [CupertinoIcons] glyph
/// so the spec's 30 line icons render natively without bundling SVG assets.
class MBIcons {
  const MBIcons._();

  static const IconData search = CupertinoIcons.search;
  static const IconData copy = CupertinoIcons.doc_on_doc;
  static const IconData paste = CupertinoIcons.doc_on_clipboard;
  static const IconData swap = CupertinoIcons.arrow_up_arrow_down_circle;
  static const IconData clear = CupertinoIcons.clear_circled_solid;
  static const IconData star = CupertinoIcons.star;
  static const IconData starFill = CupertinoIcons.star_fill;
  static const IconData check = CupertinoIcons.check_mark;
  static const IconData warn = CupertinoIcons.exclamationmark_triangle_fill;
  static const IconData info = CupertinoIcons.info_circle;
  static const IconData chevR = CupertinoIcons.chevron_right;
  static const IconData lock = CupertinoIcons.lock_fill;
  static const IconData hash = CupertinoIcons.number;
  static const IconData clock = CupertinoIcons.time;
  static const IconData brackets =
      CupertinoIcons.chevron_left_slash_chevron_right;
  static const IconData link = CupertinoIcons.link;
  static const IconData drop = CupertinoIcons.drop_fill;
  static const IconData binary = CupertinoIcons.textformat_123;
  static const IconData pct = CupertinoIcons.percent;
  static const IconData shield = CupertinoIcons.shield_lefthalf_fill;
  static const IconData globe = CupertinoIcons.globe;
  static const IconData cron = CupertinoIcons.timer;
  static const IconData regex = CupertinoIcons.textformat_alt;
  static const IconData uuid = CupertinoIcons.barcode;
  static const IconData textCase = CupertinoIcons.textformat;
  static const IconData bytes = CupertinoIcons.square_stack_3d_down_right_fill;
  static const IconData trash = CupertinoIcons.trash;
  static const IconData plus = CupertinoIcons.add;
  static const IconData history = CupertinoIcons.clock;
  static const IconData keyboard = CupertinoIcons.keyboard;
  static const IconData setting = CupertinoIcons.gear;
  static const IconData chevL = CupertinoIcons.chevron_left;
  static const IconData chevD = CupertinoIcons.chevron_down;
  static const IconData xmark = CupertinoIcons.xmark;
  static const IconData home = CupertinoIcons.house;
}
