import SwiftUI

struct EnergyOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: Double

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Capsule()
                    .fill(AppTheme.gold.opacity(0.35 + progress * 0.35))
                    .frame(width: 5, height: 18 + progress * 8)
                    .offset(y: -73)
                    .rotationEffect(.degrees(Double(index) * 36))
            }

            Circle()
                .fill(AppTheme.gold.opacity(0.18 + progress * 0.18))
                .frame(width: 150, height: 150)
                .blur(radius: 18)

            Circle()
                .fill(LinearGradient(colors: [Color(hex: "FFD788"), Color(hex: "FF8D99")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 112, height: 112)
                .overlay {
                    VStack(spacing: 5) {
                        HStack(spacing: 20) {
                            Circle().fill(AppTheme.cocoa).frame(width: 6, height: 8)
                            Circle().fill(AppTheme.cocoa).frame(width: 6, height: 8)
                        }
                        Image(systemName: "mouth.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.cocoa)
                    }
                }
                .overlay(alignment: .topLeading) {
                    Circle().fill(.white.opacity(0.6)).frame(width: 22).offset(x: 22, y: 18)
                }
                .shadow(color: AppTheme.gold.opacity(0.55), radius: 20)
                .scaleEffect(0.94 + progress * 0.1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: progress)
        }
        .frame(height: 190)
        .accessibilityHidden(true)
    }
}
