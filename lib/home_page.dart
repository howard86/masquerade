import 'package:flutter/cupertino.dart';
import 'package:masquerade/widgets/timestamp_display_card.dart';
import 'package:masquerade/widgets/encoding_display_card.dart';
import 'utils/timestamp_parser.dart';
import 'utils/encoding_parser.dart';
import 'dart:async';

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
  String? _originalValue;
  String? _encodingType;
  EncodingResult? _encodingResult;
  Timer? _debounceTimer;

  void _parseTimestampDebounced() {
    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Set a new timer for 500ms
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      _parseTimestamp();
    });
  }

  void _parseTimestamp() {
    final input = _inputController.text.trim();

    if (input.isEmpty) {
      setState(() {
        _parsedTimestamp = null;
        _errorMessage = null;
        _originalValue = null;
        _encodingType = null;
        _encodingResult = null;
      });
      return;
    }

    // Check for encoding (hex or base64) - this runs in parallel with timestamp parsing
    final encodingResult = EncodingParser.detectAndConvert(input);
    final hasValidEncoding = encodingResult.isSuccess;

    // Try parsing as timestamp (both direct and through encoded formats)
    final parseResult = TimestampParser.parseAnyFormat(input);
    final hasValidTimestamp = parseResult.isSuccess;

    setState(() {
      // Set encoding information if valid
      if (hasValidEncoding) {
        _originalValue = input;
        _encodingType = encodingResult.type.name;
        _encodingResult = encodingResult;
      } else {
        _originalValue = null;
        _encodingType = null;
        _encodingResult = null;
      }

      // Set timestamp information if valid
      if (hasValidTimestamp) {
        _parsedTimestamp = parseResult.timestamp;
      } else {
        _parsedTimestamp = null;
      }

      // Set error message only if neither parsing succeeded
      if (!hasValidEncoding && !hasValidTimestamp) {
        _errorMessage =
            'Invalid input format. Supported formats:\n'
            '• Unix timestamp (seconds/milliseconds)\n'
            '• ISO 8601 date format\n'
            '• Base64 encoded strings\n'
            '• Hex encoded strings';
      } else {
        _errorMessage = null;
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
                        'Timestamp Converter Tool',
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
                        placeholder:
                            'Enter timestamp (Unix, ISO 8601, Base64, or Hex)',
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
                        onChanged: (_) => _parseTimestampDebounced(),
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 20),
                      if (_errorMessage != null)
                        AnimatedOpacity(
                          opacity: _errorMessage != null ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemRed.withOpacity(0.1),
                              border: Border.all(
                                color: CupertinoColors.systemRed.withOpacity(
                                  0.3,
                                ),
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
                        ),
                      // Show encoding display for hex/base64 inputs
                      if (_originalValue != null && _encodingType != null) ...[
                        AnimatedOpacity(
                          opacity: _originalValue != null ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: EncodingDisplayCard(
                            originalValue: _originalValue!,
                            encodingType: _encodingType!,
                            decodedValue: _encodingResult!.result!,
                          ),
                        ),
                      ],

                      // Show timestamp display for timestamp inputs
                      if (_parsedTimestamp != null) ...[
                        // Timestamp display
                        AnimatedOpacity(
                          opacity: _parsedTimestamp != null ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: TimestampDisplayCard(
                            timestamp: _parsedTimestamp!,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Clear button always at bottom
            Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: 16.0,
              ),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () {
                    _debounceTimer?.cancel();
                    _inputController.clear();
                    setState(() {
                      _parsedTimestamp = null;
                      _errorMessage = null;
                      _originalValue = null;
                      _encodingType = null;
                      _encodingResult = null;
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
