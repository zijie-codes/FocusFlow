import SwiftUI

enum FocusFlowTheme {
    /// 主题蓝紫（periwinkle），对齐番茄ToDo 风格截图。
    static let accent = Color(red: 0.49, green: 0.53, blue: 0.76)
    static let accentDeep = Color(red: 0.44, green: 0.48, blue: 0.72)
    static let accentSoft = Color(red: 0.91, green: 0.92, blue: 0.96)
    /// 顶部横幅与统计页整页背景。
    static let banner = Color(red: 0.54, green: 0.58, blue: 0.78)
    static let statsBackground = Color(red: 0.61, green: 0.65, blue: 0.82)
    static let mint = Color(red: 0.18, green: 0.67, blue: 0.55)
    static let sky = Color(red: 0.26, green: 0.55, blue: 0.92)
    static let amber = Color(red: 0.96, green: 0.66, blue: 0.20)
    static let violet = Color(red: 0.53, green: 0.40, blue: 0.88)
    static let coral = Color(red: 0.95, green: 0.45, blue: 0.40)

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

    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.56, green: 0.60, blue: 0.80),
            Color(red: 0.45, green: 0.49, blue: 0.73)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func listColor(hex: String?) -> Color {
        guard let hex, let color = Color(focusFlowHex: hex) else { return accent }
        return color
    }

    /// 待办卡片的情绪化渐变背景（替代照片素材），按任务 ID 稳定分配。
    static let cardGradientPresets: [[Color]] = [
        [Color(red: 0.38, green: 0.40, blue: 0.51), Color(red: 0.63, green: 0.52, blue: 0.50)],
        [Color(red: 0.52, green: 0.80, blue: 0.76), Color(red: 0.32, green: 0.64, blue: 0.61)],
        [Color(red: 0.56, green: 0.63, blue: 0.68), Color(red: 0.41, green: 0.50, blue: 0.56)],
        [Color(red: 0.66, green: 0.64, blue: 0.79), Color(red: 0.53, green: 0.60, blue: 0.75)],
        [Color(red: 0.17, green: 0.42, blue: 0.45), Color(red: 0.10, green: 0.30, blue: 0.33)],
        [Color(red: 0.67, green: 0.71, blue: 0.77), Color(red: 0.54, green: 0.61, blue: 0.68)]
    ]

    static func cardGradient(seed: String) -> LinearGradient {
        let sum = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let colors = cardGradientPresets[sum % cardGradientPresets.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

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
    var track: Color = Color(uiColor: .tertiarySystemFill)

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
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

extension Color {
    /// 解析 "#RRGGBB" 形式的清单颜色，供列表配色使用。
    init?(focusFlowHex hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard value.count == 6, let integer = UInt64(value, radix: 16) else { return nil }
        self.init(
            red: Double((integer >> 16) & 0xff) / 255,
            green: Double((integer >> 8) & 0xff) / 255,
            blue: Double(integer & 0xff) / 255
        )
    }
}
