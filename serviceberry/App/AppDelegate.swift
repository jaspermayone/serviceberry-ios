import UIKit
import CoreBluetooth

/// App delegate for handling background launch and BLE state restoration
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        // Check if launched due to BLE state restoration
        if let bluetoothCentrals = launchOptions?[.bluetoothCentrals] as? [String] {
            print("App launched for BLE restoration: \(bluetoothCentrals)")
            // The BLETransport will handle restoration via willRestoreState
        }

        // Check if launched due to location event
        if let _ = launchOptions?[.location] {
            print("App launched for location event")
        }

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("App entered background")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("App will enter foreground")
    }
}
