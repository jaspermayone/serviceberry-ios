import SwiftUI
import Combine

/// Onboarding step enumeration
enum OnboardingStep: Hashable {
    case welcome
    case transportChoice
    case bluetoothSetup
    case lanSetup
    case permissions
    case completion
}

/// Container view for the onboarding wizard
struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            WelcomeStepView()
                .navigationDestination(for: OnboardingStep.self) { step in
                    destinationView(for: step)
                }
        }
        .environmentObject(viewModel)
    }

    @ViewBuilder
    private func destinationView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStepView()
        case .transportChoice:
            TransportChoiceView()
        case .bluetoothSetup:
            BluetoothSetupView()
        case .lanSetup:
            LANSetupView()
        case .permissions:
            PermissionsRequestView()
        case .completion:
            CompletionView()
        }
    }
}

/// View model for managing onboarding state
@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var selectedMode: TransportMode?
    @Published var selectedServer: ServerInfo?
    @Published var selectedPeripheral: CBPeripheralWrapper?

    func navigateTo(_ step: OnboardingStep) {
        navigationPath.append(step)
    }

    func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
}

/// Wrapper for CBPeripheral to make it Hashable
struct CBPeripheralWrapper: Hashable, Identifiable {
    let id: UUID
    let name: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CBPeripheralWrapper, rhs: CBPeripheralWrapper) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    OnboardingContainerView()
        .environmentObject(AppState())
}
