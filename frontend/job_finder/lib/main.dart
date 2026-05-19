import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/signup_page.dart';
import 'features/home_screen.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'providers/job_provider.dart';
import 'providers/saved_jobs_provider.dart';
import 'providers/user_provider.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,); 
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => JobProvider()),
        ChangeNotifierProvider(create: (context) => SavedJobsProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
      ],
      child: MaterialApp(
        home: MyApp(),
        debugShowCheckedModeBanner: false,
        routes: {
          '/home': (context) => const HomeScreen(),
        },
      ),
    ),
  );
}
