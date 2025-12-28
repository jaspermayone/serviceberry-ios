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
    @StateObject private var logManager = LogManager.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                if appState.isOnboarded {
                    DashboardView()
                        .environmentObject(appState)
                } else {
                    OnboardingContainerView()
                        .environmentObject(appState)
                }

                LogOverlayView()

                // Floating log toggle button (bottom-right corner)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { LogManager.shared.toggleOverlay() }) {
                            Image(systemName: logManager.isOverlayVisible ? "doc.text.fill" : "doc.text")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
            .environmentObject(logManager)
            .onAppear {
                LogManager.shared.info("App launched", source: "App")
            }
        }
    }
}
