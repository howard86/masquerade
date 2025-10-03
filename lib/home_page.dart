import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'timestamp_display_card.dart';
import 'utils/timestamp_parser.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _inputController = TextEditingController();
  DateTime? _parsedTimestamp;
  String? _errorMessage;

  void _parseTimestamp() {
    final input = _inputController.text.trim();

    if (input.isEmpty) {
      setState(() {
        _parsedTimestamp = null;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _parsedTimestamp = TimestampParser.parseTimestamp(input);
      _errorMessage = _parsedTimestamp != null
          ? null
          : 'Invalid timestamp format. Try Unix timestamp (seconds/milliseconds) or ISO 8601 format.';
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: 20),
                      Text(
                        widget.title,
                        style: CupertinoTheme.of(
                          context,
                        ).textTheme.navLargeTitleTextStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter a timestamp to convert:',
                        style: CupertinoTheme.of(context).textTheme.textStyle
                            .copyWith(
                              color: CupertinoColors.secondaryLabel,
                              fontSize: 15,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      CupertinoTextField(
                        controller: _inputController,
                        placeholder: 'Unix timestamp or ISO 8601 date',
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(
                            CupertinoIcons.time,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 16.0,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: CupertinoColors.systemGrey4,
                            width: 0.5,
                          ),
                        ),
                        onChanged: (_) => _parseTimestamp(),
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 20),
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemRed.withOpacity(0.1),
                            border: Border.all(
                              color: CupertinoColors.systemRed.withOpacity(0.3),
                              width: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.exclamationmark_circle_fill,
                                color: CupertinoColors.systemRed,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: CupertinoTheme.of(context)
                                      .textTheme
                                      .textStyle
                                      .copyWith(
                                        color: CupertinoColors.systemRed,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_parsedTimestamp != null) ...[
                        const SizedBox(height: 20),
                        TimestampDisplayCard(timestamp: _parsedTimestamp!),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            // Clear button always at bottom
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () {
                    _inputController.clear();
                    setState(() {
                      _parsedTimestamp = null;
                      _errorMessage = null;
                    });
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.clear_circled_solid),
                      SizedBox(width: 8),
                      Text('Clear'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
