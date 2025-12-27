import SwiftUI

/// Transport selection screen
struct TransportChoiceView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Choose Connection Method")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Select how you want to connect to your Serviceberry server.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            Spacer()

            // Transport options
            VStack(spacing: 16) {
                TransportOptionCard(
                    mode: .bluetooth,
                    isSelected: viewModel.selectedMode == .bluetooth
                ) {
                    viewModel.selectedMode = .bluetooth
                }

                TransportOptionCard(
                    mode: .lan,
                    isSelected: viewModel.selectedMode == .lan
                ) {
                    viewModel.selectedMode = .lan
                }
            }
            .padding(.horizontal)

            Spacer()

            // Continue button
            Button(action: {
                if viewModel.selectedMode == .bluetooth {
                    viewModel.navigateTo(.bluetoothSetup)
                } else {
                    viewModel.navigateTo(.lanSetup)
                }
            }) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.selectedMode != nil ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(viewModel.selectedMode == nil)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Connection")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Card component for transport option
struct TransportOptionCard: View {
    let mode: TransportMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: mode.icon)
                    .font(.title)
                    .foregroundStyle(isSelected ? .white : .blue)
                    .frame(width: 50, height: 50)
                    .background(isSelected ? Color.blue : Color.blue.opacity(0.1))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? Color.blue.opacity(0.05) : Color.clear)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        TransportChoiceView()
    }
    .environmentObject(OnboardingViewModel())
}
