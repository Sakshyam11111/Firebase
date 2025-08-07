import 'package:assignment_firebase/login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: kIsWeb
        ? const FirebaseOptions(
            apiKey: "AIzaSyA-bWALUcnVNcJYNkjFU_2HQiDT2MsfJV0",
            authDomain: "fir-3f347.firebaseapp.com",
            projectId: "fir-3f347",
            storageBucket: "fir-3f347.firebasestorage.app",
            messagingSenderId: "537714448141",
            appId: "1:537714448141:web:b40c519145cbbca49f0244",
            measurementId: "G-WZWMSWHW6G",
          )
        : DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class DefaultFirebaseOptions {
  static var currentPlatform;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
      ),
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  AuthWrapper({super.key});

  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const WeatherApp();
        }
        return const LoginPage();
      },
    );
  }
}