import 'package:flutter/material.dart';

class FontTest extends StatelessWidget {
  const FontTest({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'Roboto',
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Font Test'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Regular Roboto',
                style: TextStyle(
                  fontSize: 24,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.normal,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bold Roboto',
                style: TextStyle(
                  fontSize: 24,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Light Roboto',
                style: TextStyle(
                  fontSize: 24,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 