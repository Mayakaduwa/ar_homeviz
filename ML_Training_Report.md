# AR-HomeViz Intelligence: Machine Learning Training Report

This report documents the machine learning lifecycle for the AR-HomeViz project, specifically focusing on the **DeepLabV3+ Wall Segmentation** and the **Neural Color Recommendation** engines.

---

## 1. Wall Segmentation Model (DeepLabV3+)

### Objective
To automatically identify wall surfaces in a 2D camera image to allow for real-time virtual color visualization.

### Methodology
- **Architecture**: DeepLabV3+ with a MobileNetV2 backbone (optimized for mobile).
- **Dataset**: A custom-curated dataset of 5,000+ interior design images, supplemented by the **ADE20K** dataset (Indoor Scene parsing).
- **Technique**: **Transfer Learning**. We utilized a pre-trained MobileNetV2 model and fine-tuned the decoder layers specifically for "Wall" and "Floor" classes.

### Training Parameters
- **Loss Function**: Sparse Categorical Cross-Entropy (penalizing boundary errors).
- **Epochs**: 60 Epochs on an NVIDIA T4 GPU.
- **Evaluation Metric**: Mean Intersection over Union (mIoU).
- **Result**: Achieved a pixel accuracy of **97.74%** on training data and **75.05%** on validation data.

### Mobile Deployment
- **Optimization**: Post-training **Full Integer Quantization**.
- **Compression**: Reduced model size from ~100MB (Keras) to **6.12MB** (TFLite INT8 Quantized).
- **File**: `deeplabv3_plus_wall.tflite`

---

## 2. Neural Color Recommendation Engine (MLP)

### Objective
To move beyond static rule-based suggestions and provide a "feeling-aware" design assistant.

### Methodology
- **Architecture**: Multi-Layer Perceptron (MLP) Neural Network.
- **Dataset**: A synthetic dataset of 10,000 color-mood pairings generated based on established **Color Theory Principles**.
  - **Modern**: Slate Blue/Grey tones (Cold & Sharp).
  - **Warm**: Terracotta/Beige tones (Earthy & Inviting).
  - **Calm**: Sky Blue/Sage Green tones (Soft & Peaceful).

### Neural Layers
1. **Input Layer**: 3 Nodes (RGB Normalized values).
2. **Hidden Layer 1**: 16 Neurons (ReLU Activation).
3. **Hidden Layer 2**: 8 Neurons (ReLU Activation).
4. **Output Layer**: 3 Neurons (Softmax Activation) representing probability scores for each Mood.

### Result
- **Accuracy**: 100% on the theoretical design dataset.
- **File**: `color_reco_model.tflite`

---

## 3. Hybrid Inference Pipeline

To ensure a "Premium" user experience, the system utilizes a **Hybrid Pipeline**:
1. **Cloud Inference (Primary)**: Uses high-power GPU servers (via Ngrok/Colab) for maximum precision during live sessions.
2. **Local TFLite Inference (Fallback)**: If the internet is unavailable, the app automatically switches to the `assets/models/*.tflite` files stored on the device.

---

**Prepared By**: AR-HomeViz AI Development Team
**Date**: May 2026
