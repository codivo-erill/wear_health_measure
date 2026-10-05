import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wear_health_measure/wear_health_measure.dart';

void main() => runApp(const ExampleApp());

/// Entrypoint for the multi-engine check. It is executed in a second, headless
/// FlutterEngine by `MainActivity.spawnAndDestroySecondEngine()`. Plugins are
/// registered in that engine too; destroying it must not affect the first one.
@pragma('vm:entry-point')
Future<void> secondEngineMain() async {
  // Headless engine: no runApp(), so the binding must be set up by hand.
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[second engine] started, plugin registered');
  final caps = await const WearHealthMeasure().getCapabilities();
  debugPrint('[second engine] capabilities: $caps');
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'wear_health_measure',
      theme: ThemeData.dark(useMaterial3: true),
      home: const MeasurePage(),
    );
  }
}

class MeasurePage extends StatefulWidget {
  const MeasurePage({super.key});

  @override
  State<MeasurePage> createState() => _MeasurePageState();
}

class _MeasurePageState extends State<MeasurePage> {
  static const _multiEngine = MethodChannel(
    'wear_health_measure_example/multi_engine',
  );

  final _client = const WearHealthMeasure();
  late Future<Set<MeasureDataType>> _capabilities;
  final Map<MeasureDataType, StreamSubscription<MeasureEvent>> _subscriptions =
      {};
  final Map<MeasureDataType, String> _lastValue = {};
  final Map<MeasureDataType, String> _availability = {};
  final Map<MeasureDataType, String> _errors = {};
  String? _multiEngineStatus;

  @override
  void initState() {
    super.initState();
    _capabilities = _client.getCapabilities();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  void _toggle(MeasureDataType type, bool start) {
    if (!start) {
      _subscriptions.remove(type)?.cancel();
      setState(() {});
      return;
    }
    _errors.remove(type);
    _subscriptions[type] = _client
        .measure(type)
        .listen(
          (event) => setState(() {
            switch (event) {
              case MeasureSample(:final value, :final timestamp):
                final v = value is double ? value.toStringAsFixed(1) : '$value';
                final t = timestamp.toLocal().toIso8601String().substring(
                  11,
                  19,
                );
                _lastValue[type] = '$v  @ $t';
              case MeasureAvailabilityChanged(:final availability):
                _availability[type] = availability.name;
            }
          }),
          onError: (Object e) => setState(() {
            _errors[type] = e.toString();
            _subscriptions.remove(type);
          }),
          onDone: () => setState(() => _subscriptions.remove(type)),
        );
    setState(() {});
  }

  Future<void> _spawnAndDestroySecondEngine() async {
    setState(() => _multiEngineStatus = 'second engine running…');
    await _multiEngine.invokeMethod<void>('spawnAndDestroy');
    await Future<void>.delayed(const Duration(seconds: 4));
    if (mounted) {
      setState(
        () => _multiEngineStatus =
            'second engine destroyed – values above must keep updating',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Set<MeasureDataType>>(
        future: _capabilities,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final types = snapshot.data!.toList()
            ..sort((a, b) => a.index.compareTo(b.index));
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
            children: [
              Center(
                child: Text(
                  '${types.length} measurable types',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final type in types) _tile(type),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _spawnAndDestroySecondEngine,
                child: const Text('Multi-engine check'),
              ),
              if (_multiEngineStatus != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _multiEngineStatus!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(MeasureDataType type) {
    final active = _subscriptions.containsKey(type);
    final subtitle = [
      ?_availability[type],
      ?_lastValue[type],
      ?_errors[type],
    ].join('\n');
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(type.name, style: const TextStyle(fontSize: 13)),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: _errors.containsKey(type) ? Colors.redAccent : null,
              ),
            ),
      value: active,
      onChanged: (value) => _toggle(type, value),
    );
  }
}
