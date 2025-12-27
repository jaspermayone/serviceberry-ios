//
//  serviceberryApp.swift
//  serviceberry
//
//  Created by Jasper Mayone on 12/27/25.
//

import SwiftUI

@main
struct serviceberryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.isOnboarded {
                DashboardView()
                    .environmentObject(appState)
            } else {
                OnboardingContainerView()
                    .environmentObject(appState)
            }
        }
    }
}
