# 📝 AR-HomeViz: Pending Tasks & Reminders

This file tracks critical items that need attention in the next phase of development.

---

### 1. Neural Network Integration Polish
- [ ] **Fix "Analyzing..." Loop**: The AI Analysis in the Recommendations Screen sometimes remains stuck. Verify if the TFLite model is loading correctly on all devices or if there is a threading issue with the interpreter.
- [ ] **Real-time Re-trigger**: Ensure that changing the "Mood" or "Room Type" instantly re-triggers the neural network prediction.

### 2. AR Device Testing
- [ ] **Android ARCore Validation**: Test the app on high-end AR-supported devices (e.g., Pixel series, Samsung S-series) to ensure the `arcore_flutter_plugin` and the DeepLabV3+ segmentation work in real-time.
- [ ] **Lighting Adjustment**: Test how the "Intensity" and "Smoothness" sliders react to real-world natural vs. artificial lighting.

### 3. AI & Security Config
- [ ] **Gemini API Key**: Add the Google Generative AI API Key to `chat_service.dart`.
- [ ] **Ngrok URL Update**: Remember to update the remote Colab API URL in `ml_service.dart` every time a new Colab session is started.

---

**Last Updated**: May 2026
