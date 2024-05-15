//
//  ColorRaceVisionTargetApp.swift
//  ColorRaceVisionTarget
//
//  Created by Chunyi Liu on 5/15/24.
//

import SwiftUI

@main
struct ColorRaceVisionTargetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
    }
}
