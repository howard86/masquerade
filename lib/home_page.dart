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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 20),
                    Text(
                      'Enter a timestamp to convert:',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText:
                            'Enter Unix timestamp (seconds/milliseconds) or ISO 8601 date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      onChanged: (_) => _parseTimestamp(),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
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
              child: ElevatedButton.icon(
                onPressed: () {
                  _inputController.clear();
                  setState(() {
                    _parsedTimestamp = null;
                    _errorMessage = null;
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
