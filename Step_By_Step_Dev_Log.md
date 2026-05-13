# Step-by-Step Development Log: AR-ML HomeViz
**Developer:** Tharushi Upeksha

## 🗓 2026-05-12
### 🔹 Step 1: Project Initialization
- Created Flutter project with organization `com.tharushi.upeksha`.
- Relocated project to the main workspace for better management.
- Organized `Docs/` and `Reports/` inside the project structure.

### 🔹 Step 2: Base UI Implementation
- Implemented a Dark Modern UI theme in `lib/main.dart`.
- Added the following components:
    - Custom AppBar with Back and Clear buttons.
    - Horizontal Scrolling Color Palette.
    - Shade Intensity Slider.
    - Primary Action Bar (Gallery, Capture, Save).

### 🔹 Step 3: Visual Identity & Assets
- Generated a custom high-resolution logo using AI.
- Implemented Animated Splash Screen with the new logo.
- Created `assets/images/` and configured `logo.png`.
- Updated `lib/main.dart` to display the actual logo asset.

### 🔹 Step 4: System Dependencies
- Configured `pubspec.yaml` with core project libraries:
    - `arcore_flutter_plugin` (AR Engine)
    - `tflite_flutter` (ML Engine)
    - `image_picker` (Gallery functionality)
    - `permission_handler` (Access management)
- Successfully updated system

### 🔹 Step 6: Build Configuration & Bug Fixes
- **Namespace Fix:** Applied a Gradle hook in `build.gradle.kts` to resolve the "Namespace not specified" error for the `arcore_flutter_plugin`.
- **Manifest Cleaner:** Implemented an automatic regex-based script to remove the `package` attribute from library manifests for AGP 8.0+ compatibility.
- **Dependency Bridge:** Enabled **Jetifier** in `gradle.properties` to resolve Duplicate Class conflicts.
- **Android 14 Compatibility:** Lowered `targetSdk` to **33** to resolve the `SecurityException` (RECEIVER_EXPORTED) on modern Samsung devices.
- **AR & ML Compatibility:** Updated `minSdkVersion` to **26** in `app/build.gradle.kts`.

### 🔹 Step 5: Gallery Photo Picker
- Integrated `image_picker` library.
- Implemented `_pickImage()` logic to access the phone's gallery.
- Updated the main viewport to switch between the AR Camera feed and the selected Gallery Photo.
- Linked the UI "Upload" button to the image selection process.### 🔹 Step 7: Core Navigation & Interactions
- **Back Navigation:** Implemented `SystemNavigator.pop()` for the Back button.
- **Capture System:** Integrated `RepaintBoundary` and `ui.Image` conversion for real-time design capturing.
- **Feedback UI:** Added `SnackBar` notifications for Capture/Save success.
- **State Management:** Fixed color intensity mapping for the slider.

### 🔹 Step 8: Hybrid Vision Engine (ARCore + AI Camera)
- **Architectural Pivot:** Moved from AR-exclusive to a **Hybrid Vision Engine**.
- **AI-Driven Visualization:** Prepared the system to use TFLite Segmentation for wall detection on all devices, ensuring universal compatibility.
- **UI Unified:** Renamed AR states to "Live View" for a consistent user experience.
### 🔹 Step 9: Branding & Final Stability
- **Bug Fix:** Resolved the `MainAxisSize` typo in the Splash Screen.
- **App Branding:** Renamed the application to **"AR-HomeViz"** in both Flutter and Android Manifest.
### 🔹 Step 11: UX Refinement & Branding Installation
- **App Icon Deployment:** Successfully ran `flutter_launcher_icons` to install the professional logo as the Android menu icon.
- **Smart Navigation:** Implemented conditional back-button logic to improve app flow (Photo -> Camera -> Exit).
### 🔹 Step 12: Professional UI Refactoring & Security Compliance
- **Security Upgrade:** Migrated the project to **targetSdkVersion 34** to satisfy Google Play Protect requirements and remove installation warnings.
- **Dual-Mode UX:** Split the application into "Live AI Camera" and "Photo Designer" modes with context-aware navigation.
### 🔹 Step 13: UI/UX Finalization & Hybrid Engine Stability
- **Codebase Reconstruction:** Performed a full rewrite of `main.dart` to fix layout rendering bugs and camera preview initialization.
- **Visual Polish:** Implemented a non-destructive state management for colors, allowing the intensity slider to function without corrupting the base color selection.
- **Adaptive Padding:** Utilized `MediaQuery` to ensure the UI sits perfectly above system navigation bars across different screen aspect ratios.
- **Interactive Viewer:** Optimized the Zoom/Pan functionality to use `BoxFit.contain`, preserving the original image's aspect ratio as per design requirements.

### 🔹 Step 15: Plan V4 Update & AI Objectives
- Integrated new project requirements for Miss M.T. Upeksha: **AI Chatbot** and **Trained Recommendation Model**.
- Created `Reports/ML_Chatbot_Implementation_Guide.md` covering Python/TFLite training and Gemini API integration.
- Finalized **Full Project Plan V4**, expanding Objective 2 into a complete AI-driven design system.
- Updated project file structure to support `chatbot_screen.dart` and `recommendation_model_service.dart`.

### 🔹 Step 16: Firebase & AI Setup (Phase 1 Finalization)
- Updated `pubspec.yaml` with core AI and Backend dependencies:
    - `firebase_core`: Fundamental Firebase link.
    - `firebase_auth`: Secure user access management.
    - `firebase_database`: Real-time cloud sync for palettes and preferences.
    - `firebase_storage`: Cloud storage for AR design snapshots.
    - `google_generative_ai`: Powering the "Interior Design Chatbot" (Gemini).
- Prepared the environment for Phase 3 (User Authentication).

### 🔹 Step 17: Firebase Connectivity & Configuration
- Successfully integrated `google-services.json` into the `android/app/` directory.
- Configured Firebase Console with Email/Password Authentication and Realtime Database.
- Verified Package Name (`com.tharushi.upeksha.ar_homeviz`) and established SHA-1 security handshake.
### 🔹 Step 18: Wall Segmentation Optimization (Performance)
- **Problem:** UI thread crashes (OOM) due to drawing 66,000+ individual rectangles for the wall mask.
- **Solution:** Re-engineered the `SegmentationPainter` to use **Horizontal Segment Rendering**.
- **Result:** Reduced draw calls from thousands to ~300 per frame, stabilizing the app on budget devices (Samsung A06).

### 🔹 Step 19: Robust Heuristic Segmentation (Fallback)
- **Problem:** TFLite model incompatibility with custom `Convolution2DTransposeBias` operators on mobile.
- **Solution:** Implemented a high-fidelity **LAB Color Space** detector using Delta-E perceptual distance.
- **Result:** Created a reliable wall detection engine that works without TFLite, sampling upper room zones for color reference.

### 🔹 Step 20: AI Interior Design Chatbot UI (Phase 6)
- **Design:** Implemented a premium **Glassmorphism Chat Panel** that slides over the AR view.
- **Features:**
    - Real-time interaction with an AI persona.
    - **Interactive Suggestions:** AI-suggested colors appear as clickable buttons.
    - **One-Tap Apply:** Users can apply a suggested color from chat directly to the wall in real-time.

### 🔹 Step 21: Custom ML Model Training (Objective 2)
- **Requirement:** supervisor required "Actual Model Training" for research validation.
- **Implementation:** Developed a Python-based **Neural Network (MLP)** in Google Colab.
- **Training:** Trained the model on 10,000 design rules to recommend colors based on room "Mood" (Modern, Warm, Calm).
- **Export:** Successfully generated `color_reco_model.tflite` for on-device inference.

### 🔹 Step 22: Hybrid AI Architecture (Objective 1)
- **Innovation:** Transitioned from local-only to a **Hybrid Client-Server AI System**.
- **Backend:** Deployed a **FastAPI Inference Server** on Google Colab (utilizing Free NVIDIA T4 GPU).
- **Network Bridge:** Integrated **Ngrok Tunneling** to expose the Cloud-AI to the mobile device.
- **Outcome:** The app now sends photos to the Cloud for professional-grade DeepLabV3+ segmentation, while maintaining a local fallback.

### 🔹 Step 23: Project Plan V5 & Supervisor Documentation
- Finalized **Full Project Plan V5**, documenting the new Hybrid architecture and ML training specifics.
- Updated `MLService` and `ChatService` to bridge the gap between Cloud AI and the Mobile UI.
### 🔹 Step 24: Dual-Surface Visualization (Objective 1 Complete)
- **Feature:** Implemented **Floor Visualization** alongside Wall detection.
- **UI:** Added a professional glassmorphic **Wall/Floor Selector** in the AR View.
- **Engine Logic:** Updated `MLService` to perform context-aware sampling (Top for walls, Bottom for floors).
- **Result:** Successfully fulfilled the research objective for "Wall & Floor Color Visualization."

### 🔹 Step 25: Phase 8 — Local Persistence & Cloud History (Next)
- **Plan:** Transition from ephemeral designs to persistent history.
- **Storage Strategy:** Use **Internal Phone Storage** for high-res design snapshots (Privacy-focused).
- **Metadata Sync:** Save design parameters (Color, Date, Surface) to Firebase Realtime Database.
