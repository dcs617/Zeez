import SwiftUI

/// Displays error alerts and status messages to the user
struct ErrorView: ViewModifier {
    @StateObject private var errorManager = ErrorManager.shared
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorManager.isShowingError) {
                Button("OK") {
                    errorManager.dismissError()
                }
            } message: {
                if let error = errorManager.currentError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error.localizedDescription)
                        if let recovery = error.recoverySuggestion {
                            Text(recovery)
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .overlay(statusOverlay)
    }
    
    @ViewBuilder
    private var statusOverlay: some View {
        if let status = errorManager.statusMessage {
            VStack {
                Spacer()
                
                Text(status)
                    .font(.subheadline)
                    .padding()
                    .background(
                        Capsule()
                            .fill(Color(UIColor.secondarySystemBackground))
                            .shadow(radius: 2)
                    )
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom))
            }
            .animation(.easeInOut, value: errorManager.statusMessage != nil)
        }
    }
}

extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorView())
    }
}

// Example usage in preview
struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Content")
            .withErrorHandling()
            .onAppear {
                ErrorManager.shared.showError(.healthKitPermissionDenied)
            }
    }
}