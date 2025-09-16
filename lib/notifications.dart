import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _notifications =
   FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
 'high_importance_channel',
 'Notificações Importantes',
 description: 'Canal para notas criadas',
 importance: Importance.max,
);

class Notifications {
 static Future<void> init() async {
   const init = InitializationSettings(
     android: AndroidInitializationSettings('@mipmap/ic_launcher'),
     iOS: DarwinInitializationSettings(),
   );
   await _notifications.initialize(init);
   await _notifications
       .resolvePlatformSpecificImplementation<
         AndroidFlutterLocalNotificationsPlugin
       >()
       ?.createNotificationChannel(_channel);
 }

 static Future<void> show({
   required int id,
   required String title,
   required String body,
   String? payload,
 }) {
   return _notifications.show(
     id,
     title,
     body,
     const NotificationDetails(
       android: AndroidNotificationDetails(
         'high_importance_channel',
         'Notificações Importantes',
         channelDescription: 'Canal para notas criadas',
         importance: Importance.max,
         priority: Priority.high,
       ),
     ),
     payload: payload,
   );
 }
}
