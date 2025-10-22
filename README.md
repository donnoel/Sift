🧭 Sift

Native SwiftUI app focused on a fast, modern, GPU-light movie library experience.
Still under active development, but already fun to play with.

Sift helps you build a personal movie library powered by TMDB. Paste a list of titles, let Sift find the best matches, fetch details/posters, and render a smooth library you can sort and search instantly.

⸻

✨ Highlights

	•	TMDB smart search matching (exact/near-title + year proximity + rating tiebreaker)
	•	One-shot image configuration caching (stable poster base URL + optimal size)
	•	Fast library UI: debounced search, locale/diacritic-aware filters, and stable sorting
	•	Import you can trust: progress indicator, error list, and belt-and-suspenders de-dupe
	•	100% SwiftUI, Swift 6.2, no third-party dependencies
	•	GPU-light rendering, responsive even on big libraries

⸻

🧰 Tech Stack

	•	Language: Swift 6.2
	•	UI: SwiftUI (no external UI libraries)
	•	Platform: iOS 17+
	•	Networking: URLSession (async/await)
	•	Caching: Disk + in-memory (posters), plus TMDB image config cache

⸻

📦 Requirements

	•	macOS 15.0+
	•	Xcode 16+
	•	iOS 17+ simulator or device
	•	A TMDB API key (free) for fetching metadata and posters

⸻

🚀 Getting Started

	1.	Clone

git clone https://github.com/yourusername/Sift.git
cd Sift

	2.	Open

xed .

	3.	Configure TMDB

	•	Launch the app
	•	Go to Settings → TMDB API Key
	•	Paste your key (create one at themoviedb.org if you don’t have it)

	4.	Build & Run

	•	Select the Sift scheme
	•	Choose an iPhone/iPad simulator (or device)
	•	Press ⌘R

No extra dependencies. Hit the ground running. 🏁

⸻

🧪 Using Sift (quick tour)

	•	Import
Open Settings, paste lines like:

Alien (1979)
Heat 1995
The Thing

Sift finds the best matches, fetches details/posters, shows progress, and lists any misses.

	•	Browse
The Library grid is stutter-free with cached posters.
	•	Search
Start typing—Sift waits a beat (debounce), then filters using locale/diacritic-aware matching.
	•	Sort
Use the top-right menu to switch: Title A–Z, Year, Rating (stable and deterministic).

⸻

🏗 Project Structure

Sift/
 ├─ App/
 │   └─ SiftApp.swift (entry) / AppContainer
 ├─ Views/
 │   ├─ Sections/
 │   │   └─ LibraryView.swift (debounced search, stable sort)
 │   └─ Components/ (cards, poster view, etc.)
 ├─ Stores/
 │   └─ LibraryStore.swift (import, progress, de-dupe, persistence)
 ├─ Services/
 │   ├─ TMDBClient.swift (ranked matching, image config cache)
 │   └─ DiskImageCache.swift (on-disk + memory poster caching)
 ├─ Resources/
 │   └─ Assets + design tokens
 └─ README.md

(Folder names may vary slightly as things evolve, but the roles above are stable.)

⸻

🔍 Design Notes

	•	Performance first
	•	Downsampled images and cached decoding
	•	Minimal overdraw and sensible animation usage
	•	Debounce user input, do work off the main actor where appropriate
	•	Deterministic behavior
	•	Stable sorting with consistent tie-breakers
	•	Explicit merge rules on import (prefer richer data)
	•	Safety & privacy
	•	No third-party SDKs
	•	TMDB key stays on device (app Settings)

⸻

🗺 Roadmap (short list)

	•	“Tonight’s Pick” (small ranked spotlight with a pinch of serendipity)
	•	Smart Lists (New This Week, Critically Acclaimed, Fill Your Gaps)
	•	Poster prefetch (background warm-up for immediate grids)
	•	Watch history polish + optional iCloud sync toggle
	•	Snapshot tests for views and import pipeline

⸻

🛡 License

MIT — have fun, learn, and build.

⸻

🙌 Acknowledgements

	•	Apple: SwiftUI + modern concurrency
	•	TMDB: Movie data

⸻

📬 Contact

Maintained by donnoel & bella ai.

⸻
