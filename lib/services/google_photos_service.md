# Google Photos Integration Setup

## 1. Google Cloud Console

1. Go to https://console.cloud.google.com
2. Create (or select) a project
3. Enable **Google Photos Library API**
   - APIs & Services → Library → search "Photos Library API" → Enable
4. Create OAuth 2.0 credentials
   - APIs & Services → Credentials → Create Credentials → OAuth client ID
   - Application type: **Android** (and/or iOS)
   - For Android: paste your `SHA-1` fingerprint + package name (`com.borrowbuddy.app`)
   - For iOS: paste your bundle ID (`com.borrowbuddy.app`)
5. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

---

## 2. Android Setup

### Place google-services.json
```
flutter_app/android/app/google-services.json
```

### android/app/build.gradle — add plugin
```gradle
apply plugin: 'com.google.gms.google-services'
```

### android/build.gradle — add classpath
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
}
```

### android/app/src/main/AndroidManifest.xml — add internet permission
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

---

## 3. iOS Setup

### Place GoogleService-Info.plist
```
flutter_app/ios/Runner/GoogleService-Info.plist
```

### ios/Runner/Info.plist — add URL scheme
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Reversed client ID from GoogleService-Info.plist -->
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

---

## 4. OAuth Consent Screen

In Google Cloud Console → APIs & Services → OAuth consent screen:
- Set User Type: **External**
- Add scope: `https://www.googleapis.com/auth/photoslibrary.readonly`
- Add test users (your own Google accounts) while in testing mode

---

## 5. How It Works in the App

```
[Tap "Add Photos"]
      ↓
Bottom sheet shows 3 options:
  📷 Google Photos  →  OAuth sign-in (once) → full photo grid picker
  🖼 Device Gallery →  image_picker (local storage)
  📸 Camera         →  image_picker (camera)
```

**Google Photos flow:**
1. `GoogleSignIn` opens browser OAuth consent
2. User grants `photoslibrary.readonly` scope
3. App calls `GET /v1/mediaItems` with Bearer token
4. Paginated photo grid shown (3 columns, infinite scroll)
5. User taps to select multiple photos (checkmarks shown)
6. Tap "Add N" → photos downloaded to temp dir → shown as previews in form

---

## 6. Required pubspec packages

```yaml
google_sign_in: ^6.2.1
http: ^1.2.1
path_provider: ^2.1.3
image_picker: ^1.1.1
```
