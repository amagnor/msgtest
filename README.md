# msgtest

MsgTest Projekt

## Warum das Anmelden beim ersten Start notwendig ist:
Dass der Benutzer sich nach einer Neuinstallation mindestens einmal anmelden muss, ist technisch genau richtig und gewollt:

1. **FCM-Token & Topic-Abonnement (`all_users`)**:
   Beim ersten Login wird [`_updateFcmToken()`](file:///C:/Projekte/Flutter/msgtest/lib/scaffold.dart#L112) ausgeführt. Erst in diesem Moment:
    - registriert sich die App bei den Google Play Services für Push-Benachrichtigungen,
    - abonniert das FCM-Topic `all_users` (`FirebaseMessaging.instance.subscribeToTopic('all_users')`),
    - verknüpft das FCM-Token mit dem Benutzerkonto in Supabase.

2. **System-Handling im Hintergrund / bei beendeter App**:
   Sobald das Gerät beim Topic `all_users` registriert ist, übernimmt das Betriebssystem (Android / iOS) den Empfang der Push-Nachrichten direkt über die System-Dienste – ganz unabhängig davon, ob Ihre Flutter-App läuft, minimiert oder vollständig beendet ist.

3. **Klick-Verarbeitung**:
    - **App im Hintergrund**: `FirebaseMessaging.onMessageOpenedApp` holt die App nach vorne.
    - **App beendet**: `FirebaseMessaging.instance.getInitialMessage()` liest beim Kaltstart der App die Daten der Benachrichtigung aus.

## Resumee 
Damit haben Sie eine vollständige, professionelle und lückenlose Push-Benachrichtigungs-Architektur mit Flutter, 
Firebase FCM und Supabase aufgebaut!

## Testuser mit Micmou03
- Pixel 5: andreas.magnor@gmx.de
- Pixel 10: andreas@magnorberlin.de 
- Huawai: outdoorprofi@gmx.de  