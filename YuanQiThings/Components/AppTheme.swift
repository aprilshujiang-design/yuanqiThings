import SwiftUI

enum AppTheme {
    static let rose = Color(hex: "F45F7A")
    static let coral = Color(hex: "FF8A7A")
    static let blush = Color(hex: "FFF0F2")
    static let cream = Color(hex: "FFF9F5")
    static let lavender = Color(hex: "9A82DE")
    static let cocoa = Color(hex: "4A2828")
    static let gold = Color(hex: "FFC857")
    static let card = Color.white.opacity(0.78)
    static let background = LinearGradient(
        colors: [Color(hex: "FFF8F4"), Color(hex: "FFF0F3")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

struct SoftCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
            }
            .shadow(color: AppTheme.rose.opacity(0.08), radius: 12, y: 5)
    }
}

struct GentleEmptyState: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 22 : 30, weight: .medium))
                .foregroundStyle(AppTheme.rose.opacity(0.72))
                .frame(width: compact ? 40 : 54, height: compact ? 40 : 54)
                .background(AppTheme.blush.opacity(0.9), in: Circle())

            Text(title)
                .font(compact ? .subheadline.weight(.semibold) : .headline)
                .foregroundStyle(AppTheme.cocoa)

            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.cocoa.opacity(0.62))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
