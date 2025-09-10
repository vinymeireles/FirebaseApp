import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'welcome.dart';
import 'notes.dart';

Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();
 await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
 runApp(const MyApp());
}

class MyApp extends StatelessWidget {
 const MyApp({super.key});
 // This widget is the root of your application.
 @override
 Widget build(BuildContext context) {
   return MaterialApp(
     title: 'Firebase App',
     theme: ThemeData(primarySwatch: Colors.indigo),
     home: const AuthGate(),
   );
 }
}

class AuthGate extends StatelessWidget {
 const AuthGate({super.key});
 @override
 Widget build(BuildContext context) {
   return StreamBuilder<User?>(
     stream: FirebaseAuth.instance.authStateChanges(),
     builder: (_, snap) {
       if (snap.connectionState == ConnectionState.waiting) {
         return const Scaffold(
           body: Center(child: CircularProgressIndicator()),
         );
       }
       final user = snap.data;
       return user == null ? const LoginPage() : const HomePage();
     },
   );
 }
}

class HomePage extends StatelessWidget {
 const HomePage({super.key});

 @override
 Widget build(BuildContext context) {
   final user = FirebaseAuth.instance.currentUser;
   return Scaffold(
     appBar: AppBar(title: const Text("Home")),
     drawer: Drawer(
       child: ListView(
         padding: EdgeInsets.zero,
         children: [
           UserAccountsDrawerHeader(
             accountName: Text(user?.displayName ?? "Usuário"),
             accountEmail: Text(user?.email ?? ""),
             currentAccountPicture: const CircleAvatar(
               child: Icon(Icons.person),
             ),
           ),
           ListTile(
             leading: const Icon(Icons.note),
             title: const Text('Anotações'),
             onTap: () async {
               Navigator.push(
                 context,
                 MaterialPageRoute(builder: (_) => const NotesPage()),
               );
             },
           ),
           ListTile(
             leading: const Icon(Icons.logout),
             title: const Text('Sair'),
             onTap: () async {
               await FirebaseAuth.instance.signOut();
             },
           ),
         ],
       ),
     ),
     body: const Center(child: WelcomeMessage()),
   );
 }
}
