# 📱 AR-HomeViz: Non-AR Device Testing Guide

Since your device (e.g., Samsung A06) may not support Google ARCore, follow these steps to test the **Machine Learning (DeepLabV3+)** and **Neural Recommendations** using the "Standard Mode."

---

## 🚀 Step 1: Prepare the "Brain"
Ensure your new **6MB model** is in the correct location:
1. Copy `deeplabv3_plus_wall.tflite` to `assets/models/`.
2. Ensure it is registered in `pubspec.yaml` (under the assets section).
3. Run `flutter pub get`.

---

## 📸 Step 2: The "Standard Vision" Test Flow
Use this flow to test wall segmentation without needing AR support:

1. **Open the App**: Launch AR-HomeViz on your Samsung A06.
2. **Standard Mode**: On the Home Screen, tap **"Standard Vision"** (or the camera icon that doesn't say AR).
3. **Capture a Photo**: Point your phone at a room with a clear wall and take a photo.
4. **AI Processing**: 
   - The app will send the photo to your local **DeepLabV3+** model.
   - You should see a console log: `🤖 Running Local TFLite AI Segmentation (512x512)...`
5. **Mask Overlay**: If successful, a semi-transparent color will appear over the detected walls.

---

## 🎨 Step 3: Neural Recommendation Test
Test the AI's ability to understand design moods:

1. Go to the **Recommendations** screen.
2. Change the **Mood** (Modern, Warm, Calm).
3. Observe the **Neural Network Analysis** card:
   - It should pulse "ANALYZING" for a split second.
   - It should then display a style (e.g., **WARM**) that matches the color palette.
   - **Verification**: If you pick a Blue/Grey palette, the AI should detect "MODERN." If you pick Earthy tones, it should detect "WARM."

---

## 🐞 Step 4: Troubleshooting for Supervisor
If the AI doesn't respond:
- **Model Load Error**: Check the debug console for `⚠️ MLService: Error loading TFLite models`.
- **Resolution Mismatch**: Ensure the model you trained on Kaggle was 512x512.
- **Memory**: If the app crashes, it might be due to the 512x512 image being too large for the A06's RAM. (We can lower it to 257x257 if needed).

---

**Last Updated**: May 2026
**Project**: AR-ML HomeViz
