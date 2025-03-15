import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'dart:developer' as developer;
// import 'test_fonts.dart'; // Comment out this line

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Try different paths to load .env file
    await dotenv.load(fileName: ".env")
        .catchError((_) async => await dotenv.load(fileName: "assets/.env"))
        .catchError((e) {
      developer.log('Failed to load .env file: $e');
      // Create default environment variables if .env file can't be loaded
      dotenv.env['OPENAI_API_KEY'] = '';
      dotenv.env['ANTHROPIC_API_KEY'] = '';
      dotenv.env['GEMINI_API_KEY'] = '';
      dotenv.env['OPENAI_API_ENDPOINT'] = 'https://api.openai.com/v1/chat/completions';
      dotenv.env['ANTHROPIC_API_ENDPOINT'] = 'https://api.anthropic.com/v1/messages';
    });
    
    developer.log('Environment loaded successfully.');
    developer.log('API Keys available: ${dotenv.env.containsKey("OPENAI_API_KEY")}');
  } catch (e) {
    developer.log('Error during environment initialization: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // Return to original code
          return MaterialApp(
            title: 'AI Chat',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
              ),
              // Remove fontFamily to use system default
              fontFamily: 'Roboto',
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              // Remove fontFamily to use system default
              fontFamily: 'Roboto',
            ),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
