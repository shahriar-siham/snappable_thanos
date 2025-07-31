import 'package:flutter/material.dart';
import 'package:snappable_thanos/snappable_thanos.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Thanos's Snap Demo",
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.deepPurple,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _snappableKey = GlobalKey<SnappableState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Snap'),
      ),
      body: Column(
        children: [
          // Snap Widget
          Snappable(
            key: _snappableKey,
            snapOnTap: true,
            onSnapped: () => print("Snapped!"),
            child: Card(
              child: Container(
                height: 300,
                width: double.infinity,
                color: Colors.deepPurple,
                alignment: Alignment.center,
                child: Text(
                  'This will be snapped',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // Control Button
          ElevatedButton(
            child: const Text('Snap / Reverse'),
            onPressed: () {
              SnappableState state = _snappableKey.currentState!;
              if (state.isInProgress) {
                // do nothing
                debugPrint("Animation is in progress, please wait!");
              } else if (state.isGone) {
                state.reset();
              } else {
                state.snap();
              }
            },
          )
        ],
      ),
    );
  }
}