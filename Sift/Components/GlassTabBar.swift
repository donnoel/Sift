import SwiftUI

private struct TabItemBoundsKey: PreferenceKey {
    static var defaultValue: [Section: Anchor<CGRect>] = [:]
    static func reduce(value: inout [Section: Anchor<CGRect>], nextValue: () -> [Section: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct GlassTabBar: View {
    @Binding var selected: Section
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var selNS

    private let barCorner: CGFloat = 22

    var body: some View {
        ZStack(alignment: .bottom) {
            barBackground
                .frame(height: 70)
                .overlay(alignment: .topLeading) { luminousEdgeOverlay }
                .accessibilityHidden(true)

            HStack(spacing: 8) {
                ForEach(Section.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) {
                            selected = tab
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.systemImage)
                                .imageScale(.large)
                                .font(.system(size: 18, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .opacity(selected == tab ? 1 : 0.75)
                        }
                        .foregroundStyle(selected == tab ? .primary : .secondary)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(selectionBackground(for: tab))
                        .anchorPreference(key: TabItemBoundsKey.self, value: .bounds) { [tab: $0] }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var luminousEdgeOverlay: some View {
        GeometryReader { proxy in
            Color.clear.overlayPreferenceValue(TabItemBoundsKey.self) { dict in
                if let anchor = dict[selected] {
                    let rect = proxy[anchor]
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [selected.accentPrimary, selected.accentSecondary],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(rect.width - 12, 20), height: 3)
                        .offset(x: rect.minX + 6, y: -1)
                        .shadow(color: selected.accentPrimary.opacity(0.35), radius: 6, x: 0, y: 0)
                        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8), value: selected)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func selectionBackground(for tab: Section) -> some View {
        Group {
            if selected == tab {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "pill", in: selNS)
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "pill", in: selNS)
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                }
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.clear)
            }
        }
    }

    private var barBackground: some View {
        Group {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: barCorner, style: .continuous)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: barCorner, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
            } else {
                RoundedRectangle(cornerRadius: barCorner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: barCorner, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
            }
        }
    }
}
