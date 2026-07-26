import SwiftUI

enum FocusFlowTheme {
    static let accent = Color(red: 0.94, green: 0.32, blue: 0.23)
    static let accentSoft = Color(red: 1.00, green: 0.91, blue: 0.87)
    static let mint = Color(red: 0.18, green: 0.67, blue: 0.55)
    static let sky = Color(red: 0.26, green: 0.55, blue: 0.92)
    static let amber = Color(red: 0.96, green: 0.66, blue: 0.20)
    static let violet = Color(red: 0.53, green: 0.40, blue: 0.88)

    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevatedBackground = Color(uiColor: .systemBackground)
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    static let separator = Color(uiColor: .separator).opacity(0.55)

    static let cornerRadius: CGFloat = 14
    static let compactCornerRadius: CGFloat = 10
    static let horizontalPadding: CGFloat = 18

    static let categoryColors: [Color] = [accent, mint, sky, amber, violet]

    static func categoryColor(at index: Int) -> Color {
        categoryColors[index.modulo(categoryColors.count)]
    }
}

private extension Int {
    func modulo(_ divisor: Int) -> Int {
        guard divisor > 0 else { return 0 }
        let value = self % divisor
        return value >= 0 ? value : value + divisor
    }
}

struct SurfaceCard: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: FocusFlowTheme.cornerRadius, style: .continuous)
                    .fill(FocusFlowTheme.cardBackground)
                    .shadow(color: .black.opacity(0.035), radius: 12, y: 4)
            )
    }
}

extension View {
    func surfaceCard(padding: CGFloat = 16) -> some View {
        modifier(SurfaceCard(padding: padding))
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    var color: Color = FocusFlowTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Capsule()
                    .fill(color.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct QuietActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(FocusFlowTheme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(uiColor: .tertiarySystemFill))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(FocusFlowTheme.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(FocusFlowTheme.secondaryText)
                }
            }

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FocusFlowTheme.accent)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    var systemImage: String?
    var count: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                if let count {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(isSelected ? .white.opacity(0.22) : Color(uiColor: .tertiarySystemFill)))
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : FocusFlowTheme.secondaryText)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isSelected ? FocusFlowTheme.accent : FocusFlowTheme.cardBackground)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint.opacity(0.13)))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(FocusFlowTheme.primaryText)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(FocusFlowTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: FocusFlowTheme.compactCornerRadius, style: .continuous)
                .fill(FocusFlowTheme.cardBackground)
        )
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(FocusFlowTheme.accent)
                .frame(width: 68, height: 68)
                .background(Circle().fill(FocusFlowTheme.accent.opacity(0.11)))

            Text(title)
                .font(.headline)
                .foregroundStyle(FocusFlowTheme.primaryText)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(FocusFlowTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(QuietActionButtonStyle())
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .surfaceCard()
    }
}

struct CircularProgressView: View {
    let progress: Double
    var lineWidth: CGFloat = 9
    var tint: Color = FocusFlowTheme.accent

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(uiColor: .tertiarySystemFill), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: progress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("完成进度")
        .accessibilityValue("\(Int(min(max(progress, 0), 1) * 100))%")
    }
}

/// 番茄计数点：实心为已完成，浅色为剩余，超过上限时以数字补充。
struct PomodoroDots: View {
    let completed: Int
    let estimated: Int

    private let maxDots = 6

    private var dotCount: Int { min(max(estimated, 1), maxDots) }
    private var filledCount: Int { min(max(completed, 0), dotCount) }

    var body: some View {
        HStack(spacing: 3.5) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(index < filledCount ? FocusFlowTheme.accent : FocusFlowTheme.accent.opacity(0.18))
                    .frame(width: 6, height: 6)
            }
            if estimated > maxDots {
                Text("×\(estimated)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(FocusFlowTheme.secondaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("番茄进度，已完成 \(completed) 个，计划 \(estimated) 个")
    }
}

struct PlayCircleButton: View {
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: size * 0.03)
                .frame(width: size, height: size)
                .background(Circle().fill(FocusFlowTheme.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("开始专注")
    }
}
