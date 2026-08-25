# Chatt App

A WhatsApp-style real-time messaging app built with Flutter — complete with authentication, media sharing, voice messages, and an **offline on-device AI chatbot** powered by LLaMA 3.2.

Built as a portfolio project to explore real-time data sync, cloud storage, and running a large language model entirely on the device with no internet connection.

---

## Features

### Authentication
- Email / password sign up and login (Firebase Auth)
- Email verification flow with a dedicated verification screen
- Forgot password / reset via email
- Form validation on all auth fields

### Messaging
- Real-time one-to-one chat powered by Cloud Firestore
- Chat list sorted by most recent activity
- Contacts screen with user search
- Online / offline presence and "last seen"
- Typing indicator
- Message delivery ticks (sent / delivered / read)

### Media Sharing
- **Images** — send from gallery or camera
- **Documents** — send PDFs and other files, open them with the system viewer
- **Voice messages** — record, send, and play back with a waveform-style bubble
- All media uploaded to Supabase Storage; only the public URL is stored in Firestore

### Chat Management
- Delete a chat, or clear messages while keeping the chat
- User profile screen (name, email, nickname)
- Set a custom nickname per contact — shown across chat list and chat screen
- Edit your own profile

### Offline AI Chatbot
- On-device inference using **LLaMA 3.2 1B Instruct (Q4_K_M GGUF)** via the `fllama` package
- Model downloaded once (~800 MB) and stored in the app's documents directory
- Works with **zero internet** after the initial download — verified in airplane mode
- Token-by-token streaming responses
- Conversation history persisted locally with `shared_preferences`
- Clear-chat with confirmation dialog

### UI
- Custom teal gradient auth header with curved bottom and elevated logo
- Subtle dotted chat background pattern
- Modern grid-style attachment sheet with colored icons
- Custom app icon and splash screen

---


## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Authentication | Firebase Auth |
| Database | Cloud Firestore (real-time) |
| File Storage | Supabase Storage |
| On-device LLM | fllama (llama.cpp bindings) + LLaMA 3.2 1B Instruct |
| Local Storage | shared_preferences |
| State Management | Provider |

### Key Packages

```yaml
dependencies:
  firebase_core:
  firebase_auth:
  cloud_firestore:
  supabase_flutter:
  provider:
  image_picker:
  file_picker: ^8.1.2   # v11 has a broken FilePicker.platform getter
  record:               # voice recording (AudioRecorder + RecordConfig)
  audioplayers:         # voice playback
  url_launcher:         # opening documents
  path_provider:
  shared_preferences:
  fllama:
    git:
      url: https://github.com/Telosnex/fllama.git
```

---

## Project Structure

```
lib/
├── core/          # constants, utils, theme
├── models/        # user_model, message_model, chat_model
├── services/      # auth_service, firestore_service, storage_service,
│                  # llama_model_manager, llama_chat_service
├── providers/     # auth_provider, chat_provider
├── screens/
│   ├── auth/      # login, signup, verify_email, forgot_password
│   ├── home/      # home_screen + chat_tile
│   ├── chat/      # chat_screen + message_bubble, message_input
│   ├── ai/        # ai_chat_screen
│   ├── contacts/
│   └── profile/
└── widgets/       # auth_header, chat_background, custom_button, etc.
```

---

## Getting Started

### Prerequisites
- Flutter SDK (stable channel)
- A Firebase project
- A Supabase project (free tier is enough)
- Android NDK **27.0.12077973** and CMake — required only for the AI chatbot feature

### 1. Clone and install

```bash
git clone https://github.com/AlihaAsif/chat_app.git
cd chat_app
flutter pub get
```

### 2. Firebase setup

1. Create a project in the [Firebase Console](https://console.firebase.google.com)
2. Enable **Authentication → Email/Password**
3. Create a **Cloud Firestore** database
4. Connect the app:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart`.

5. Set Firestore rules so only signed-in users can read/write:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 3. Supabase Storage setup

1. Create a project at [supabase.com](https://supabase.com)
2. Create a **public** storage bucket named `chat-media`
3. Add a storage policy allowing `SELECT`, `INSERT`, `UPDATE`, `DELETE` where `bucket_id = 'chat-media'`
   - Skipping this step causes a `403 row-level security` error on upload
4. Add your project URL and publishable key to the app's config file

### 4. Android permissions

Add microphone and internet permissions, plus a `<queries>` block for `url_launcher` so documents can be opened:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>

<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:mimeType="*/*" />
  </intent>
</queries>
```

### 5. AI chatbot setup (optional)

The `fllama` package compiles native code, so the NDK must be discoverable:

```bash
setx ANDROID_NDK_HOME "D:\androidsdk\ndk\27.0.12077973"
setx ANDROID_NDK_ROOT "D:\androidsdk\ndk\27.0.12077973"
```

Also add the NDK and CMake `bin` folders to your system `PATH`.

The model is downloaded at runtime from Hugging Face the first time you open the AI chat screen.

### 6. Run

```bash
flutter run
```

---

## Known Limitations

- **Voice recording on emulators** produces silent files — the Android emulator can't reliably capture mic input. Test on a real device.
- **AI chatbot on emulators** requires `numGpuLayers: 0`, since emulators lack reliable Vulkan/GPU support for llama.cpp. On a physical device, GPU layers can be enabled for faster inference.
- **Stopping generation mid-response** is not supported — `fllama` blocks its background isolate during inference.
- The AI model is downloaded per device (~800 MB). This is standard practice for on-device models, similar to Google Translate's offline language packs.

---


## Author

**Aliha Asif** — [@AlihaAsif](https://github.com/AlihaAsif)

