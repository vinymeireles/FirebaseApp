import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotesPage extends StatefulWidget {
 const NotesPage({super.key});
 @override
 State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
 final createController = TextEditingController();

 String? editingId;
 final inlineController = TextEditingController();
 final inlineFocus = FocusNode();

 bool loading = false;
 String? message;

 CollectionReference<Map<String, dynamic>> get _col {
   final uid = FirebaseAuth.instance.currentUser!.uid;
   return FirebaseFirestore.instance
       .collection('users')
       .doc(uid)
       .collection('notes');
 }

 @override
 void dispose() {
   createController.dispose();
   inlineController.dispose();
   inlineFocus.dispose();
   super.dispose();
 }

 Future<void> _add() async {
   final text = createController.text.trim();
   if (text.isEmpty) {
     setState(() => message = 'Preencha a descrição.');
     return;
   }
   setState(() {
     loading = true;
     message = null;
   });
   try {
     await _col.add({
       'description': text,
       'createdAt': FieldValue.serverTimestamp(),
     });
     createController.clear();
   } catch (e) {
     setState(() => message = 'Erro: $e');
   } finally {
     if (mounted) setState(() => loading = false);
   }
 }

 void _startInlineEdit(DocumentSnapshot<Map<String, dynamic>> doc) {
   final data = doc.data();
   setState(() {
     editingId = doc.id;
     inlineController.text = (data?['description'] ?? '').toString();
   });
   Future.microtask(() => inlineFocus.requestFocus());
 }

 void _cancelInlineEdit() {
   setState(() {
     editingId = null;
     inlineController.clear();
     inlineFocus.unfocus();
   });
 }

 Future<void> _commitInlineEdit(String docId) async {
   final newText = inlineController.text.trim();
   if (newText.isEmpty) {
     setState(() => message = 'A descrição não pode ser vazia.');
     return;
   }
   try {
     await _col.doc(docId).update({
       'description': newText,
       'updatedAt': FieldValue.serverTimestamp(),
     });
     _cancelInlineEdit();
   } catch (e) {
     setState(() => message = 'Erro ao atualizar: $e');
   }
 }

 Future<void> _remove(String docId) async {
   final ok = await showDialog<bool>(
     context: context,
     builder: (_) => AlertDialog(
       title: const Text('Remover nota'),
       content: const Text('Tem certeza que deseja remover esta nota?'),
       actions: [
         TextButton(
           onPressed: () => Navigator.pop(context, false),
           child: const Text('Cancelar'),
         ),
         FilledButton.tonal(
           onPressed: () => Navigator.pop(context, true),
           child: const Text('Remover'),
         ),
       ],
     ),
   );
   if (ok == true) {
     await _col.doc(docId).delete();
     if (editingId == docId) _cancelInlineEdit();
   }
 }

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(title: const Text('Notas')),
     body: Center(
       child: ConstrainedBox(
         constraints: const BoxConstraints(maxWidth: 460),
         child: Column(
           children: [
             Padding(
               padding: const EdgeInsets.all(16),
               child: Column(
                 children: [
                   TextField(
                     controller: createController,
                     decoration: const InputDecoration(labelText: 'Descrição'),
                     onSubmitted: (_) => _add(),
                   ),
                   const SizedBox(height: 16),
                   SizedBox(
                     width: double.infinity,
                     child: FilledButton(
                       onPressed: loading ? null : _add,
                       child: const Text('Adicionar'),
                     ),
                   ),
                 ],
               ),
             ),
             if (loading) const CircularProgressIndicator(),
             if (message != null)
               Padding(
                 padding: const EdgeInsets.only(top: 12),
                 child: Text(
                   message!,
                   style: TextStyle(
                     color: Theme.of(context).colorScheme.primary,
                   ),
                 ),
               ),
             const Divider(),
             Expanded(
               child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                 stream: _col
                     .orderBy('createdAt', descending: true)
                     .snapshots(),
                 builder: (context, snapshot) {
                   if (snapshot.connectionState == ConnectionState.waiting) {
                     return const Center(child: CircularProgressIndicator());
                   }
                   if (snapshot.hasError) {
                     return Center(child: Text('Erro: ${snapshot.error}'));
                   }
                   final docs = snapshot.data?.docs ?? [];
                   if (docs.isEmpty) {
                     return const Center(
                       child: Text('Nenhuma nota cadastrada.'),
                     );
                   }
                   return ListView.separated(
                     itemCount: docs.length,
                     separatorBuilder: (_, __) => const Divider(height: 0),
                     itemBuilder: (context, i) {
                       final doc = docs[i];
                       final data = doc.data();
                       final isEditing = editingId == doc.id;
                       if (isEditing) {
                         return Padding(
                           padding: const EdgeInsets.symmetric(
                             horizontal: 12,
                             vertical: 6,
                           ),
                           child: Row(
                             children: [
                               Expanded(
                                 child: TextField(
                                   controller: inlineController,
                                   focusNode: inlineFocus,
                                   autofocus: true,
                                   decoration: const InputDecoration(
                                     labelText: 'Editar descrição',
                                     isDense: true,
                                     border: OutlineInputBorder(),
                                   ),
                                   onSubmitted: (_) =>
                                       _commitInlineEdit(doc.id),
                                 ),
                               ),
                               const SizedBox(width: 8),
                               IconButton(
                                 tooltip: 'Salvar',
                                 onPressed: () => _commitInlineEdit(doc.id),
                                 icon: const Icon(Icons.check_circle_outline),
                               ),
                               IconButton(
                                 tooltip: 'Cancelar',
                                 onPressed: _cancelInlineEdit,
                                 icon: const Icon(Icons.close),
                               ),
                             ],
                           ),
                         );
                       }
                       return ListTile(
                         title: Text((data['description'] ?? '').toString()),
                         onTap: () => _startInlineEdit(doc),
                         trailing: IconButton(
                           icon: const Icon(Icons.delete_outline),
                           tooltip: 'Remover',
                           onPressed: () => _remove(doc.id),
                         ),
                       );
                     },
                   );
                 },
               ),
             ),
           ],
         ),
       ),
     ),
   );
 }
}
