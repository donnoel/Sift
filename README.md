# 🧭 Sift

Sift is a Movie Recommendation App based on movies imported.  Built entirely with **SwiftUI** and **Swift 6.2**.  
Its core purpose is to **deliver a smooth, modern, GPU-light image and media caching experience**, with a clean architecture and a strong focus on performance and responsiveness.

---

## ✨ Features

- 🖼 **Intelligent Image Caching**  
  Efficient, disk-backed and memory-backed image caching for fast, stutter-free rendering.

- 🚀 **Downsampling & Decoding**  
  On-the-fly image downsampling and decoded image caching for sharp visuals without overloading the GPU.

- 🧭 **Modern Concurrency**  
  Async/await architecture built with Swift 6 actor isolation in mind.

- 💻 **iOS Native UI**  
  100% SwiftUI — no third-party dependencies. Everything integrates seamlessly with system UI and scale factors.

- 🧪 **Deterministic Performance**  
  Designed to minimize overdraw, eliminate unnecessary animations, and run smoothly even under load.

---

## 🧰 Tech Stack

- 🛠 **Language:** Swift 6.2  
- 🖥 **Platform:** iOS 
- 🪟 **UI:** SwiftUI + native Apple frameworks  
- 🧭 **Architecture:** Lightweight, actor-safe, modular  
- 💾 **Caching:** NSCache + Disk cache + Downsampling  
- 🌐 **Networking:** URLSession with async/await

---

## 📦 Requirements

- macOS 15.0 or later  
- Xcode 16+  
- Swift 6.2 toolchain

---

## 🧑‍💻 Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/Sift.git
   cd Sift
