# 🧭 Sift

Sift is a **native iOS application** built entirely with **SwiftUI** and **Swift 6.2**.  
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
- 🖥 **Platform:** iOS 17+ 
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

	2.	Open in Xcode

xed .


	3.	Build & Run
	•	Select the Sift scheme
	•	Choose My Mac as the run destination
	•	Press ⌘R to build and run

That’s it — no external dependencies required. 🏁

⸻

📂 Project Structure

Sift/
 ├─ App/
 │  └─ SiftApp.swift
 ├─ Components/
 │  ├─ CachedAsyncImage.swift
 │  └─ Glass primitives & helpers
 ├─ Services/
 │  ├─ DiskImageCache.swift
 │  └─ TMDBClient.swift
 ├─ Resources/
 │  └─ Design tokens and assets
 └─ README.md


⸻

🧪 Development Notes
	•	Optimized for modern Swift concurrency with strict actor isolation.
	•	No external libraries — everything uses Apple frameworks.
	•	Image pipeline tuned to avoid layout thrash, animation hitches, and excessive memory usage.

⸻

🛡 License

This project is licensed under the MIT License.
Feel free to fork, learn, or contribute.

⸻

🙌 Acknowledgements
	•	Apple for SwiftUI and its modern concurrency model
	•	TMDB for optional image sources (if you choose to enable them)

⸻

📬 Contact

Maintained by Don Noel
For questions or contributions, open an issue or pull request.

⸻

Would you like me to make this README sound a bit more recruiter-friendly (i.e., highlight your engineering skills more prominently), or keep it clean and minimal like this version?
