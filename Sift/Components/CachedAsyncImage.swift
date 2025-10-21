// PATH: Sift/Components/CachedAsyncImage.swift
import SwiftUI
import ImageIO
import Combine

// MARK: - Platform Abstractions
#if os(iOS)
import UIKit
typealias PlatformImage = UIImage

private func screenScale() -> CGFloat {
    UIScreen.main.scale
}

private func makeSwiftUIImage(_ img: PlatformImage) -> Image {
    Image(uiImage: img)
}

private func cgImage(from image: PlatformImage) -> CGImage? {
    image.cgImage
}

#else
import AppKit
typealias PlatformImage = NSImage

private func screenScale() -> CGFloat {
    NSScreen.main?.backingScaleFactor ?? 2.0
}

private func makeSwiftUIImage(_ img: PlatformImage) -> Image {
    Image(nsImage: img)
}

private func cgImage(from image: PlatformImage) -> CGImage? {
    // Safely extract a CGImage from NSImage
    if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        return cg
    }
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.cgImage
}
#endif

// MARK: - Decoded Image Cache
final class _ImageDecodeCache {
    static let shared = _ImageDecodeCache()
    private let cache = NSCache<NSString, PlatformImage>()

    private init() {
        cache.countLimit = 400
        cache.totalCostLimit = 128 * 1024 * 1024 // ~128 MB for decoded images
    }

    func image(for key: String) -> PlatformImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: PlatformImage, for key: String, cost: Int) {
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

// MARK: - Cached Async Image
struct CachedAsyncImage: View {
    let url: URL?
    let contentMode: ContentMode
    let placeholder: () -> AnyView

    @State private var uiImage: PlatformImage?
    @State private var pixelBucket: Int = 0

    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> some View = {
            ZStack {
                Rectangle().fill(Color(.tertiarySystemFill))
                ProgressView().controlSize(.small)
            }
        }
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = { AnyView(placeholder()) }
    }

    var body: some View {
        ZStack {
            if let image = uiImage {
                makeSwiftUIImage(image)
                    .resizable()
                    .interpolation(.medium)
                    .antialiased(true)
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .transaction { $0.animation = nil } // Disable implicit animations to avoid hitches
        .onChangeCompat(of: url) { uiImage = nil } // Clear stale image
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { updateBucket(for: geo.size) }
                .onChangeCompat(of: geo.size) { updateBucket(for: geo.size) }
        })
        .task(id: taskKey) { await load() } // Trigger reload when key changes
    }

    private var taskKey: String {
        let u = url?.absoluteString ?? "nil"
        return "\(u)#\(pixelBucket)"
    }

    private func updateBucket(for size: CGSize) {
        let scale = screenScale()
        let maxPixels = Int(max(size.width, size.height) * scale)
        let bucket = max(400, ((maxPixels + 100) / 200) * 200) // round up to avoid thrash
        if bucket != pixelBucket {
            pixelBucket = bucket
        }
    }

    private func cacheKey(for url: URL?, bucket: Int) -> String {
        guard let url else { return "nil#\(bucket)" }
        return "\(url.absoluteString)#\(bucket)"
    }

    // MARK: - Downsampling

    private func downsample(_ data: Data, maxPixelSize: Int, scale: CGFloat) -> PlatformImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(64, maxPixelSize)
        ]

        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
        else {
            return nil
        }

        #if os(iOS)
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
        #else
        return NSImage(cgImage: cg, size: .zero)
        #endif
    }

    private func decodedCost(_ image: PlatformImage) -> Int {
        guard let cg = cgImage(from: image) else { return 1 }
        return cg.bytesPerRow * cg.height
    }

    private func loadFromDiskCacheAndDecode(url: URL, bucket: Int) async -> PlatformImage? {
        guard let data = await DiskImageCache.shared.data(for: url) else { return nil }
        let scale = screenScale()
        return downsample(data, maxPixelSize: bucket, scale: scale)
    }

    private func maybeSetImage(_ image: PlatformImage?, for key: String) async {
        guard let image else { return }
        if taskKey == key {
            await MainActor.run {
                self.uiImage = image
            }
        }
    }

    private func load() async {
        guard let url else { return }
        let key = taskKey

        // Memory cache first
        if let cached = _ImageDecodeCache.shared.image(for: key) {
            await MainActor.run { self.uiImage = cached }
            return
        }

        // Decode and cache
        if let img = await loadFromDiskCacheAndDecode(url: url, bucket: pixelBucket) {
            _ImageDecodeCache.shared.set(img, for: key, cost: decodedCost(img))
            await maybeSetImage(img, for: key)
        }
    }
}

extension View {
    /// Compatibility wrapper for SwiftUI's onChange that avoids the iOS 17 deprecation
    /// and keeps behavior consistent across OS versions.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping () -> Void) -> some View {
        if #available(iOS 17, macOS 14, *) {
            self.onChange(of: value, initial: false) { _, _ in
                action()
            }
        } else {
            self.onChange(of: value) { _ in
                action()
            }
        }
    }
}
