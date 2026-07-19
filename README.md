# Unsere Hochzeit – Wedding App 💍

Eine gemeinsame Flutter-App für die Hochzeits-Website (gehostet über GitHub
Pages), eine installierbare Android-App (APK-Download, kein Play Store nötig)
und eine iOS-PWA (installierbar über "Zum Home-Bildschirm hinzufügen").

## Funktionen

- **RSVP** – Gäste suchen sich per Namenseingabe (keine Passwörter) selbst
  auf der Gästeliste und sagen zu/ab, inkl. Begleitpersonen & Essenswünschen.
- **Sitzplan (hidden)** – Erst nach Namenseingabe sichtbar, hebt den eigenen
  Tisch/Platz hervor.
- **Kuchensektion** – Übersicht bereits geplanter Kuchen + Anmeldeformular.
  Als "üblicher Kuchen-Verdächtiger" markierte Gäste bekommen automatisch ein
  Erinnerungs-Popup.
- **Fotogalerie** – Fotos per Kamera oder Datei-Upload hochladen, live für
  alle sichtbar; Kuratierung (ausblenden/löschen) im Admin-Bereich.
- **Rede/Programmpunkt-Anmeldung** – Einfaches Formular für Reden, Diashows
  oder andere Programmpunkte.
- **Admin-Bereich** – Passwortgeschützt (Firebase E-Mail/Passwort-Login):
  Gästeliste verwalten (inkl. CSV-Bulk-Import), Fotos kuratieren.

## Architektur

- Flutter (Web, Android, iOS – eine Codebase) mit [go_router](https://pub.dev/packages/go_router)
  für Navigation und [provider](https://pub.dev/packages/provider) für den
  Gast-Session-State.
- **Firebase** als Backend:
  - Firestore: `guests`, `cakes`, `photos`, `programItems` Collections
    (siehe [lib/models/](lib/models)).
  - Firebase Storage: Foto-Uploads.
  - Firebase Auth: anonyme Sessions für Gäste (kein Login-UI nötig) +
    E-Mail/Passwort für den Admin-Bereich.
  - Security Rules: [firestore.rules](firestore.rules), [storage.rules](storage.rules).

## Einmalige Einrichtung

### 1. Firebase-Projekt anlegen

1. Gehe zu <https://console.firebase.google.com> und erstelle ein neues Projekt.
2. Aktiviere in der Konsole:
   - **Firestore Database** (im "production mode")
   - **Storage**
   - **Authentication** → Sign-in-Methoden **Anonym** und **E-Mail/Passwort** aktivieren.
3. Lege unter Authentication → Users manuell einen Admin-Account
   (E-Mail/Passwort) für das Brautpaar an.

### 2. FlutterFire CLI verbinden

```powershell
dart pub global activate flutterfire_cli
cd wedapp
flutterfire configure
```

Wähle euer Firebase-Projekt und die Plattformen **web** und **android** aus.
Das überschreibt [lib/firebase_options.dart](lib/firebase_options.dart) mit
den echten Projektwerten.

### 3. Security Rules deployen

```powershell
npm install -g firebase-tools
firebase login
firebase deploy --only firestore:rules,firestore:indexes,storage
```

### 4. Abhängigkeiten installieren

```powershell
flutter pub get
```

### 5. Gästeliste befüllen

Im Admin-Bereich (`/admin`, Login mit dem oben angelegten Account) auf
**Gästeliste verwalten** → CSV-Import-Button. Erwartetes Format:

```csv
firstName,lastName,tableId,seat,isUsualCakeSuspect
Anna,Muster,1,A1,true
Max,Mustermann,1,A2,false
```

## Lokale Entwicklung

```powershell
flutter run -d chrome   # Web
flutter run              # verbundenes Android-Gerät/Emulator
```

> **Hinweis (Windows):** Zum lokalen Bauen für Android/Windows benötigt
> Flutter symbolische Links, wofür der **Windows-Entwicklermodus**
> aktiviert sein muss (`Einstellungen → Datenschutz & Sicherheit → Für
> Entwickler`, oder `start ms-settings:developers`). Für Web-Builds ist das
> nicht nötig. Die GitHub-Actions-Workflows laufen ohnehin auf Linux-Runnern
> und sind davon nicht betroffen.

## Deployment

### Website (GitHub Pages)

Der Workflow [.github/workflows/deploy-web.yml](.github/workflows/deploy-web.yml)
baut die Web-App bei jedem Push auf `main`/`Weddapp` und deployed sie auf
GitHub Pages.

**Einmalig in den Repo-Einstellungen aktivieren:** *Settings → Pages → Source
→ "GitHub Actions"*. Die Seite ist danach unter
`https://<username>.github.io/wedapp/` erreichbar (Repo heißt aktuell
`wedapp` unter `Andi-Amo` – passe `--base-href` im Workflow an, falls das
Repo umbenannt wird oder eine eigene Domain genutzt wird).

### Android-App (APK-Download)

Der Workflow [.github/workflows/build-android.yml](.github/workflows/build-android.yml)
baut bei jedem Push eine Release-APK als Workflow-Artefakt. Um sie als
öffentlich verlinkbaren Download bereitzustellen, einen Git-Tag pushen:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

Das veröffentlicht die APK automatisch als Asset unter
`https://github.com/Andi-Amo/wedapp/releases/latest` – genau dieser Link ist
bereits als "Android-App herunterladen"-Button auf der Startseite verlinkt.
Gäste müssen beim Installieren "Installation aus unbekannten Quellen
erlauben" bestätigen (normaler Vorgang bei APKs außerhalb des Play Stores).

### iOS

Kein App-Store-Release geplant (siehe Projektplan – erfordert einen
kostenpflichtigen Apple-Developer-Account und Review-Prozess). iOS-Gäste
nutzen stattdessen die Website als **PWA**: Safari öffnen → Teilen-Symbol →
"Zum Home-Bildschirm". Ein entsprechender Hinweis wird iOS-Besuchern
automatisch auf der Startseite angezeigt.

## Projektstruktur

```
lib/
  models/       Datenmodelle (Guest, CakeEntry, WeddingPhoto, ProgramItem)
  services/     Firestore/Storage/Auth-Repositories + GuestSession-State
  screens/      Eine Datei pro Feature-Screen (RSVP, Sitzplan, Kuchen, ...)
  screens/admin Admin-Login, Dashboard, Gästeliste, Foto-Kuratierung
  widgets/      Wiederverwendbare Widgets (Namenssuche, iOS-Installhinweis)
  theme/        Zentrales App-Theming
  router.dart   Zentrale Routen-Tabelle (go_router)
  main.dart     App-Einstieg, Firebase-Init
firestore.rules, storage.rules, firestore.indexes.json, firebase.json
  Security Rules & Firebase-Projektkonfiguration
```
