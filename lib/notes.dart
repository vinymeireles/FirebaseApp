import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'notifications.dart';
import 'maps.dart';

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
     await _col
         .add({
           'description': text,
           'createdAt': FieldValue.serverTimestamp(),
           'date': null,
           'timeMinutes': null,
         })
         .then(
           (note) => Notifications.show(
             id: note.id.hashCode,
             title: 'Nota criada',
             body: text,
             payload: note.id,
           ),
         );
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

 void _openMapViewer(
   DocumentReference<Map<String, dynamic>> noteRef,
   Map<String, dynamic> data,
 ) {
   GeoPoint? gp;
   final pos = data['position'];
   if (pos is GeoPoint) {
     gp = pos;
   } else if (pos is Map && pos['geopoint'] is GeoPoint) {
     gp = pos['geopoint'] as GeoPoint;
   }

   ll.LatLng? initialLatLng = gp == null
       ? null
       : ll.LatLng(gp.latitude, gp.longitude);
   final double? initialZoom = (data['zoom'] as num?)?.toDouble();
   String? initialAddress =
       (data['address'] as String?)?.trim().isEmpty == true
       ? null
       : data['address']?.toString();

   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (_) => MapViewerEditorPage(
         noteRef: noteRef,
         initialLatLng: initialLatLng,
         initialZoom: initialZoom,
         initialAddress: initialAddress,
       ),
     ),
   );
 }

 String formatDate(Timestamp? ts) {
   if (ts == null) return '--';
   final d = ts.toDate();
   return '${d.month.toString().padLeft(2, '0')}/${d.year}';
 }

 String formatTimeMinutes(int? minutes) {
   if (minutes == null) return '--';
   final h = (minutes ~/ 60).toString().padLeft(2, '0');
   final m = (minutes % 60).toString().padLeft(2, '0');
   return '$h:$m';
 }

 Future<void> _pickDate(
   DocumentReference<Map<String, dynamic>> noteRef,
   Timestamp? current,
 ) async {
   final initial = (current ?? Timestamp.fromDate(DateTime.now())).toDate();
   final selected = await showDatePicker(
     context: context,
     initialDate: initial,
     firstDate: DateTime(2000),
     lastDate: DateTime(2100),
   );
   if (selected != null) {
     try {
       await noteRef.update({
         'date': Timestamp.fromDate(selected),
         'updatedAt': FieldValue.serverTimestamp(),
       });
       if (mounted) setState(() {});
     } catch (e) {
       setState(() => message = 'Erro ao salvar data: $e');
     }
   }
 }

 Future<void> _pickTime(
   DocumentReference<Map<String, dynamic>> noteRef,
   int? currentMinutes,
 ) async {
   final initialHour = (currentMinutes ?? 540) ~/ 60;
   final initialMinute = (currentMinutes ?? 540) % 60;

   final selected = await showTimePicker(
     context: context,
     initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
   );
   if (selected != null) {
     final minutes = selected.hour * 60 + selected.minute;
     try {
       await noteRef.update({
         'timeMinutes': minutes,
         'updatedAt': FieldValue.serverTimestamp(),
       });
       if (mounted) setState(() {});
     } catch (e) {
       setState(() => message = 'Erro ao salvar horário: $e');
     }
   }
 }

 Widget _iconWithLabel({
   required IconData icon,
   required String label,
   required VoidCallback? onPressed,
   String? tooltip,
 }) {
   final textTheme = Theme.of(context).textTheme;
   return SizedBox(
     width: 56,
     child: Column(
       mainAxisSize: MainAxisSize.min,
       children: [
         IconButton(
           icon: Icon(icon, size: 20),
           tooltip: tooltip,
           padding: EdgeInsets.zero,
           constraints: const BoxConstraints.tightFor(width: 40, height: 36),
           visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
           onPressed: onPressed,
         ),
         const SizedBox(height: 2),
         Text(
           label.isEmpty ? '—' : label,
           maxLines: 1,
           overflow: TextOverflow.ellipsis,
           style: textTheme.labelSmall?.copyWith(
             height: 1.0,
             color: Theme.of(context).colorScheme.onSurfaceVariant,
           ),
         ),
       ],
     ),
   );
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

                       final String? subtitleText =
                           (data['address'] as String?)?.trim().isEmpty == true
                           ? null
                           : data['address']?.toString();

                       final Timestamp? tsDate = data['date'] as Timestamp?;
                       final int? timeMinutes = (data['timeMinutes'] as num?)
                           ?.toInt();

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
                         isThreeLine: subtitleText != null,
                         minVerticalPadding: 8,
                         title: Text((data['description'] ?? '').toString()),
                         subtitle: subtitleText == null
                             ? null
                             : Text(
                                 subtitleText,
                                 maxLines: 2,
                                 overflow: TextOverflow.ellipsis,
                               ),
                         onTap: () => _startInlineEdit(doc),
                         trailing: FittedBox(
                           fit: BoxFit.scaleDown,
                           alignment: Alignment.centerRight,
                           child: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               _iconWithLabel(
                                 icon: Icons.map_rounded,
                                 label: 'Mapa',
                                 tooltip: 'Abrir mapa',
                                 onPressed: () =>
                                     _openMapViewer(_col.doc(doc.id), data),
                               ),
                               const SizedBox(width: 4),
                               _iconWithLabel(
                                 icon: Icons.event,
                                 label: formatDate(tsDate),
                                 tooltip: 'Selecionar data',
                                 onPressed: () =>
                                     _pickDate(_col.doc(doc.id), tsDate),
                               ),
                               const SizedBox(width: 4),
                               _iconWithLabel(
                                 icon: Icons.access_time,
                                 label: formatTimeMinutes(timeMinutes),
                                 tooltip: 'Selecionar horário',
                                 onPressed: () =>
                                     _pickTime(_col.doc(doc.id), timeMinutes),
                               ),
                               const SizedBox(width: 4),
                               _iconWithLabel(
                                 icon: Icons.delete_outline,
                                 label: 'Remover',
                                 tooltip: 'Remover nota',
                                 onPressed: () => _remove(doc.id),
                               ),
                             ],
                           ),
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
   );}}
