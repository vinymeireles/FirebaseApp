import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WelcomeMessage extends StatelessWidget {
 const WelcomeMessage({super.key});

 @override
 Widget build(BuildContext context) {
   final docRef = FirebaseFirestore.instance
       .collection('config')
       .doc('welcome');

   return StreamBuilder<DocumentSnapshot>(
     stream: docRef.snapshots(),
     builder: (context, snapshot) {
       if (snapshot.connectionState == ConnectionState.waiting) {
         return const CircularProgressIndicator();
       }
       if (!snapshot.hasData || !snapshot.data!.exists) {
         return const Text("Mensagem não encontrada");
       }

       final data = snapshot.data!.data() as Map<String, dynamic>;
       return Text(
         data['text'] ?? 'Bem-vindo!',
         style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
       );
     },
   );
 }
}
