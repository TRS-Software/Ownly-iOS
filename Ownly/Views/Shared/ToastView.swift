import SwiftUI

// MARK: - Toast Type

enum ToastType {
    case success
    case error

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String
    let type: ToastType

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(type.color)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .background(type.color.opacity(0.1))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

// MARK: - Toast View Modifier

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let type: ToastType

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isPresented {
                    ToastView(message: message, type: type)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isPresented = false
                                }
                            }
                        }
                        .zIndex(999)
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.2), value: isPresented)
    }
}

// MARK: - View Extension

extension View {
    func toast(isPresented: Binding<Bool>, message: String, type: ToastType = .success) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, type: type))
    }
}
