//
//  SiftApp.swift
//  Sift
//
//  Created by Don Noel on 10/19/25.
//

import SwiftUI
import UIKit

@main
struct SiftApp: App {
    @StateObject private var container = AppContainer()
    init() {
    }
    var body: some Scene {
        WindowGroup {
            RootView()
                .overlay(TabBarTitleEnforcer().allowsHitTesting(false)) // icons-only in iPhone portrait
                .environmentObject(container).environmentObject(container.settings)
                .environmentObject(container.library)
        }
    }
}

// Enforces icons-only on iPhone portrait by directly toggling UITabBarItem titles.
private struct TabBarTitleEnforcer: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        DispatchQueue.main.async { apply() } // apply once mounted
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { apply() }
    }

    private func apply() {
        #if os(iOS)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.keyWindow,
              let tab = findTabBarController(in: window.rootViewController) else { return }

        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let isPortrait = scene.interfaceOrientation.isPortrait

        if isPhone && isPortrait {
            // Cache originals once
            if OriginalTitles.storage.isEmpty {
                for (idx, item) in (tab.tabBar.items ?? []).enumerated() {
                    OriginalTitles.storage[idx] = item.title
                }
            }
            // Hide titles (icons only)
            for item in tab.tabBar.items ?? [] {
                item.title = "" // remove visible text
                // Nudge icon a bit for balance
                item.imageInsets = UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)
            }
            tab.tabBar.setNeedsLayout()
            tab.tabBar.layoutIfNeeded()
        } else {
            // Restore titles when not iPhone portrait
            for (idx, item) in (tab.tabBar.items ?? []).enumerated() {
                if let title = OriginalTitles.storage[idx] {
                    item.title = title
                    item.imageInsets = .zero
                }
            }
            tab.tabBar.setNeedsLayout()
            tab.tabBar.layoutIfNeeded()
        }
        #endif
    }

    private func findTabBarController(in vc: UIViewController?) -> UITabBarController? {
        guard let vc = vc else { return nil }
        if let t = vc as? UITabBarController { return t }
        for child in vc.children {
            if let t = findTabBarController(in: child) { return t }
        }
        if let presented = vc.presentedViewController {
            return findTabBarController(in: presented)
        }
        return nil
    }

    private enum OriginalTitles {
        static var storage: [Int: String?] = [:]
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? {
        return self.windows.first(where: { $0.isKeyWindow })
    }
}
