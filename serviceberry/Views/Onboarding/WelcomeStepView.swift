import SwiftUI

/// Welcome screen - first step of onboarding
struct WelcomeStepView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon/logo
            Image(systemName: "location.north.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text("Welcome to Serviceberry")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Help improve geolocation databases by sharing anonymous location data with your server.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "shield.checkered",
                    title: "Privacy First",
                    description: "Data stays on your local network"
                )

                FeatureRow(
                    icon: "bolt.fill",
                    title: "Automatic",
                    description: "Server requests location when needed"
                )

                FeatureRow(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Flexible",
                    description: "Connect via Bluetooth or WiFi"
                )
            }
            .padding(.horizontal)

            Spacer()

            Button(action: {
                viewModel.navigateTo(.transportChoice)
            }) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationBarHidden(true)
    }
}

/// Feature row component
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WelcomeStepView()
    }
    .environmentObject(OnboardingViewModel())
}
