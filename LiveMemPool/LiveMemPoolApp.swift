//
//  LiveMemPoolApp.swift
//  LiveMemPool
//
//  Created by Abe Mangona on 5/14/25.
//

import SwiftUI

@main
struct LiveMemPoolApp: App {
    
    init () {
        loadRocketSimConnect()
    }
    ///3JMcLrQW3EVH9vXnxJbQBqzW3DQterrUiX
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func loadRocketSimConnect() {
        #if DEBUG
        guard (Bundle(path: "/Applications/RocketSim.app/Contents/Frameworks/RocketSimConnectLinker.nocache.framework")?.load() == true) else {
            print("Failed to load linker framework")
            return
        }
        print("RocketSim Connect successfully linked")
        #endif
    }
}
