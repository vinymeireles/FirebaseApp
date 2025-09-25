import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

class MapViewerEditorPage extends StatefulWidget {
 final DocumentReference<Map<String, dynamic>> noteRef;
 final ll.LatLng? initialLatLng;
 final double? initialZoom;
 final String? initialAddress;

 const MapViewerEditorPage({
   super.key,
   required this.noteRef,
   this.initialLatLng,
   this.initialZoom,
   this.initialAddress,
 });

 @override
 State<MapViewerEditorPage> createState() => _MapViewerEditorPageState();
}

class _MapViewerEditorPageState extends State<MapViewerEditorPage> {
 final MapController _mapController = MapController();

 static const _worldCenter = ll.LatLng(0, 0);
 static const double _worldZoom = 1.5;

 ll.LatLng? _selected;
 double _zoom = _worldZoom;
 String _address = '';
 bool _saving = false;

 @override
 void initState() {
   super.initState();
   _selected = widget.initialLatLng;
   _zoom = widget.initialZoom ?? _worldZoom;
   _address = widget.initialAddress ?? '';
   WidgetsBinding.instance.addPostFrameCallback((_) {
     _safeMove(
       _selected ?? _worldCenter,
       _selected == null ? _worldZoom : _zoom,
     );
   });
 }

 void _safeMove(ll.LatLng center, double zoom) {
   try {
     _mapController.move(center, zoom);
   } catch (_) {}
 }

 Future<String> _reverseGeocode(ll.LatLng point) async {
   final uri = Uri.parse(
     'https://nominatim.openstreetmap.org/reverse'
     '?lat=${point.latitude}&lon=${point.longitude}'
     '&format=json&addressdetails=1',
   );
   try {
     final resp = await http.get(
       uri,
       headers: const {
         'User-Agent': 'FirebaseApp/1.0 (viniciusmeireles@gmail.com)',
         'Accept': 'application/json',
       },
     );
     if (resp.statusCode == 200) {
       final json = jsonDecode(resp.body) as Map<String, dynamic>;
       return (json['display_name'] ?? '').toString();
     }
     return 'Endereço indisponível (HTTP ${resp.statusCode})';
   } catch (e) {
     return 'Endereço indisponível ($e)';
   }
 }

 Future<void> _save() async {
   if (_selected == null) {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
         content: Text('Selecione um ponto no mapa antes de salvar.'),
       ),
     );
     return;
   }
   setState(() => _saving = true);

   final address = await _reverseGeocode(_selected!);

   final geoFirePoint = GeoFirePoint(
     GeoPoint(_selected!.latitude, _selected!.longitude),
   );

   try {
     await widget.noteRef.set({
       'position': geoFirePoint.data,
       'address': address,
       'zoom': _zoom,
       'updatedAt': FieldValue.serverTimestamp(),
     }, SetOptions(merge: true));

     if (!mounted) return;
     setState(() {
       _address = address;
       _saving = false;
     });
     ScaffoldMessenger.of(
       context,
     ).showSnackBar(const SnackBar(content: Text('Local salvo.')));
     Navigator.pop(context);
   } catch (e) {
     if (!mounted) return;
     setState(() => _saving = false);
     ScaffoldMessenger.of(
       context,
     ).showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
   }
 }

 Future<void> _clear() async {
   final ok = await showDialog<bool>(
     context: context,
     builder: (_) => AlertDialog(
       title: const Text('Limpar localização'),
       content: const Text('Remover o endereço?'),
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
   if (ok != true) return;

   try {
     await widget.noteRef.update({
       'position': FieldValue.delete(),
       'address': FieldValue.delete(),
       'zoom': FieldValue.delete(),
       'updatedAt': FieldValue.serverTimestamp(),
     });
     if (!mounted) return;
     setState(() {
       _selected = null;
       _address = '';
       _zoom = _worldZoom;
     });
     ScaffoldMessenger.of(
       context,
     ).showSnackBar(const SnackBar(content: Text('Local removido.')));
   } catch (e) {
     if (!mounted) return;
     ScaffoldMessenger.of(
       context,
     ).showSnackBar(SnackBar(content: Text('Falha ao remover: $e')));
   }
 }

 @override
 Widget build(BuildContext context) {
   final markers = _selected == null
       ? const <Marker>[]
       : <Marker>[
           Marker(
             point: _selected!,
             width: 40,
             height: 40,
             child: const Icon(Icons.location_on, size: 40, color: Colors.red),
           ),
         ];

   return Scaffold(
     appBar: AppBar(
       title: const Text('Geolocalização'),
       actions: [
         IconButton(
           tooltip: 'Limpar localização',
           onPressed: _saving ? null : _clear,
           icon: const Icon(Icons.delete),
         ),
         TextButton.icon(
           onPressed: _saving ? null : _save,
           icon: _saving
               ? const SizedBox(
                   width: 16,
                   height: 16,
                   child: CircularProgressIndicator(strokeWidth: 2),
                 )
               : const Icon(Icons.check),
           label: const Text('Salvar'),
         ),
       ],
     ),
     body: Column(
       children: [
         Expanded(
           child: Center(
             child: SizedBox(
               width: 1000,
               height: 650,
               child: FlutterMap(
                 mapController: _mapController,
                 options: MapOptions(
                   initialCenter: _selected ?? _worldCenter,
                   initialZoom: _selected == null ? _worldZoom : _zoom,
                   onTap: (tapPos, point) => setState(() => _selected = point),
                   onPositionChanged: (camera, hasGesture) {
                     _zoom = camera.zoom;
                   },
                 ),
                 children: [
                   TileLayer(
                     urlTemplate:
                         'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                     subdomains: const ['a', 'b', 'c'],
                     userAgentPackageName: 'com.example.myapp',
                   ),
                   MarkerLayer(markers: markers),
                 ],
               ),
             ),
           ),
         ),
         Material(
           color: Theme.of(context).colorScheme.surfaceContainerLow,
           child: ListTile(
             leading: const Icon(Icons.place_outlined),
             title: Text(
               _address.isEmpty
                   ? 'Endereço ainda não definido.'
                   : _address,
               maxLines: 2,
               overflow: TextOverflow.ellipsis,
             ),
             trailing: FilledButton.tonalIcon(
               onPressed: _selected == null || _saving
                   ? null
                   : () async {
                       final addr = await _reverseGeocode(_selected!);
                       if (!mounted) return;
                       setState(() => _address = addr);
                     },
               icon: const Icon(Icons.search),
               label: const Text('Buscar endereço'),
             ),
           ),
         ),
       ],
     ),
   );
 }
}
