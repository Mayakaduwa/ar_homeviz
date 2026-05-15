# Implementation Plan: ML Pipeline & Mobile Integration

This plan outlines the complete workflow for training the AR-HomeViz vision models and integrating them into the Flutter application for real-time interior design.

---

## Phase 1: Data Acquisition & Preprocessing
**Goal**: Build a high-quality dataset that represents real-world indoor lighting and room layouts.

- **Primary Dataset**: Utilize the **ADE20K** (Scene Parsing) dataset, specifically filtering for the "Wall," "Floor," "Ceiling," and "Window" classes.
- **Data Augmentation**: Implement a robust augmentation pipeline in the Kaggle notebook:
    - **Geometric**: Random rotation, flipping, and scaling.
    - **Photometric**: Adjusting brightness, contrast, and adding Gaussian noise (to simulate low-light phone cameras).
- **Format**: Convert labels into binary masks (Wall=1, Background=0).

---

## Phase 2: Neural Network Training (DeepLabV3+)
**Goal**: Train a lightweight yet accurate segmentation model.

- **Model Architecture**:
    - **Encoder**: MobileNetV2 (Pre-trained on ImageNet) for efficient feature extraction.
    - **Decoder**: Atrous Spatial Pyramid Pooling (ASPP) to capture wall boundaries at different scales.
- **Environment**: Kaggle Notebook using **GPU P100/T4**.
- **Training Strategy**:
    - **Fine-tuning**: Freeze initial layers and train the decoder for 50+ epochs.
    - **Loss Function**: Combined **Dice Loss + Cross-Entropy** (to handle class imbalance between large walls and small windows).

---

## Phase 3: Accuracy Evaluation & Metrics
**Goal**: Provide the "Academic Proof" required by the supervisor.

- **Metrics to Track**:
    - **mIoU (Mean Intersection over Union)**: The gold standard for segmentation accuracy (Target: >0.80).
    - **Pixel Accuracy**: Percentage of correctly classified pixels.
- **Accuracy Test Script**: A standalone cell in the notebook that:
    1. Loads a "Hold-out" test set (images the model hasn't seen).
    2. Runs inference.
    3. Displays a **Confusion Matrix** and side-by-side comparisons (Original vs. Ground Truth vs. Predicted).

---

## Phase 4: TFLite Conversion & Optimization
**Goal**: Make the model run fast on the mobile device.

- **Conversion**: Export the trained model to `.tflite` format.
- **Quantization**: Apply **Full Integer Quantization (INT8)**. 
    - *Note*: This reduces model size by 4x and increases speed by 3x on mobile CPUs, which is essential for older Android devices.
- **Metadata**: Attach input/output tensor descriptions (1, 257, 257, 3) for the Flutter interpreter.

---

## Phase 5: Mobile Bridge Integration
**Goal**: Connect the `.tflite` file to the Flutter camera UI.

- **Input Pipeline**: 
    - Convert `CameraImage` (YUV420) to `RGB` format.
    - Resize and normalize to [0, 1] range to match model training.
- **Inference Engine**: Use `tflite_flutter` to run the `deeplabv3_plus_wall.tflite` file.
- **Output Processing**: 
    - Convert the output probability map into a binary mask.
    - Use the **SVG Path Generator** (already in `MLService`) to overlay the color on the detected wall.

---

## 📊 Marks Collection Checklist for Supervisor
