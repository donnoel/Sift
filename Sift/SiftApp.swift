//
//  SiftApp.swift
//  Sift
//
//  Created by Don Noel on 10/19/25.
//

import SwiftUI

@main
struct SiftApp: App {
    @StateObject private var container = AppContainer()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container).environmentObject(container.settings)
                .environmentObject(container.library)
        }
    }
}
