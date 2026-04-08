import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:masquerade/utils/unit_parser.dart';
import 'package:masquerade/widgets/unit_conversion_display_card.dart';
import 'package:masquerade/widgets/timestamp_display_card.dart';
import 'package:masquerade/widgets/encoding_display_card.dart';

class UnitConverterPage extends StatefulWidget {
  const UnitConverterPage({super.key});

  @override
  State<UnitConverterPage> createState() => _UnitConverterPageState();
}

class _UnitConverterPageState extends State<UnitConverterPage> {
  final TextEditingController _inputController = TextEditingController();
  UnitParseResult? _result;
  Timer? _debounceTimer;

  void _parseDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), _parse);
  }

  void _parse() {
    final input = _inputController.text.trim();
    setState(() {
      _result = input.isEmpty ? null : UnitParser.parse(input);
    });
  }

  void _clear() {
    _debounceTimer?.cancel();
    _inputController.clear();
    setState(() => _result = null);
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
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        'Converter',
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .navLargeTitleTextStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Units, Timestamps & Encodings',
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
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
                            'Enter value with unit (e.g. 100km, 5GB, 98.6F, 1714000000)',
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(
                            CupertinoIcons.arrow_2_squarepath,
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
                        onChanged: (_) => _parseDebounced(),
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 20),
                      if (_result != null)
                        if (_result!.isSuccess)
                          _buildResultCard()
                        else
                          _ErrorBanner(message: _result!.errorMessage ?? 'Invalid input'),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: 16.0,
              ),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _clear,
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

  Widget _buildResultCard() {
    final r = _result!;
    switch (r.category) {
      case UnitCategory.timestamp:
        return TimestampDisplayCard(timestamp: r.timestamp!);
      case UnitCategory.encoding:
        return EncodingDisplayCard(
          originalValue: r.encodingResult!.original,
          encodingType: r.encodingResult!.type.name,
          decodedValue: r.encodingResult!.result!,
        );
      default:
        return UnitConversionDisplayCard(result: r);
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              message,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.systemRed,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
