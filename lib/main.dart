import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
// import 'screens/home_screen.dart';
import 'services/logger_service.dart';
import 'router/app_router.dart';
import 'router/app_navigation.dart';
// import 'router/browser_url_manager.dart'; // Import new URL manager
// For web URL strategy
// import 'web_url_strategy.dart'
//    if (dart.library.html) 'package:flutter_web_plugins/flutter_web_plugins.dart';
// import 'test_fonts.dart'; // Comment out this line

// Configure the URL strategy for web (removes the hash from URLs)
void configureApp() {
  if (kIsWeb) {
    try {
      // Just log that we're initializing - the Router will handle the URL
      print('Initializing URL handling for web');

      // We'll let the Router handle URL initialization to prevent conflicts
    } catch (e) {
      print('Failed to configure URL handling: $e');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up URL strategy for web
  configureApp();

  // Initialize the logger service
  final logger = LoggerService();
  await logger.init(
    logLevel: LogLevel.debug,
    // logToConsole: true,
    // logToFile: false, // Set to true if you want file logging
  );

  logger.info('Application starting up', tag: 'INIT');

  try {
    // Try different paths to load .env file
    await dotenv
        .load(fileName: ".env")
        .catchError((_) async => await dotenv.load(fileName: "assets/.env"))
        .catchError((e) {
          logger.error('Failed to load .env file', tag: 'ENV', error: e);
          // Create default environment variables if .env file can't be loaded
          dotenv.env['OPENAI_API_KEY'] = '';
          dotenv.env['ANTHROPIC_API_KEY'] = '';
          dotenv.env['GEMINI_API_KEY'] = '';
          dotenv.env['OPENAI_API_ENDPOINT'] =
              'https://api.openai.com/v1/chat/completions';
          dotenv.env['ANTHROPIC_API_ENDPOINT'] =
              'https://api.anthropic.com/v1/messages';
        });

    logger.info('Environment loaded successfully', tag: 'ENV');
    logger.debug(
      'API Keys available: ${dotenv.env.containsKey("OPENAI_API_KEY")}',
      tag: 'ENV',
    );
  } catch (e) {
    logger.error(
      'Error during environment initialization',
      tag: 'ENV',
      error: e,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Get logger instance
    final logger = LoggerService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final chatProvider = Provider.of<ChatProvider>(context);
          final appRouter = AppRouter(chatProvider: chatProvider);

          // Initialize the navigation helper
          AppNavigation.init(appRouter);

          // Log router initialization
          logger.debug('Router initialized', tag: 'ROUTER');

          // Return to original code
          return MaterialApp.router(
            title: 'AI Chat',
            debugShowCheckedModeBanner: false,
            scrollBehavior:
                NoColorChangeScrollBehavior(), // Use custom scroll behavior
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness:
                    themeProvider.isDarkMode
                        ? Brightness.dark
                        : Brightness.light,
              ),
              // Override app bar theme to ensure consistent appearance
              appBarTheme: AppBarTheme(
                scrolledUnderElevation: 0,
                elevation: 0,
                backgroundColor:
                    Colors.transparent, // Use transparent background
                surfaceTintColor:
                    Colors.transparent, // Explicitly disable surface tint
                foregroundColor: null, // Use default text color from theme
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
              // Override app bar theme to ensure consistent appearance
              appBarTheme: AppBarTheme(
                scrolledUnderElevation: 0,
                elevation: 0,
                backgroundColor:
                    Colors.transparent, // Use transparent background
                surfaceTintColor:
                    Colors.transparent, // Explicitly disable surface tint
                foregroundColor: null, // Use default text color from theme
              ),
              // Remove fontFamily to use system default
              fontFamily: 'Roboto',
            ),
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            routerDelegate: appRouter,
            routeInformationParser: AppRouteInformationParser(),
            routeInformationProvider: PlatformRouteInformationProvider(
              initialRouteInformation: RouteInformation(uri: Uri.parse('/')),
            ),
            backButtonDispatcher: RootBackButtonDispatcher(),
          );
        },
      ),
    );
  }
}

// Custom scroll behavior to prevent app bar color changes
class NoColorChangeScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
