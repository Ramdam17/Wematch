import SwiftUI

/// The Settings theme control: `System | Pastel | Cosmic`.
///
/// Mirrors the Figma `ThemeRow`'s `.segmented` pill, with two departures — both of them
/// measured rather than stylistic.
///
/// **The selected segment is filled, not glazed.** Figma marks it with `glass/fill` over
/// the `bg/1` track, which measures 1.07:1 in Pastel Light and 1.55:1 in Dark Cosmic
/// against the 3:1 a state indicator needs (WCAG SC 1.4.11). The only other cue was the
/// label's weight plus a 2.18:1 colour step, so in the light theme the selection was
/// effectively invisible. `actionGradient` is the app's existing "this one is active"
/// surface and clears the bar along its whole ramp, not just at its stops: the worst of
/// eleven samples is 3.90:1 against the light track and 3.19:1 against the dark one, with
/// the white label never below 4.60:1.
///
/// **It is full width under its label, not inline beside it.** Three segments do not fit
/// next to a row label at 345pt — Figma drew two, and `System` comes from the validated
/// design brief. Going full width also lifts each target from Figma's 62x24pt to roughly
/// 104x32pt, matching `UISegmentedControl`'s own height.
struct ThemePicker: View {

    let selection: ThemePreference
    let onSelect: (ThemePreference) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var selectionIndicator

    /// Three labels side by side stop fitting at the accessibility sizes — at AX5 they
    /// truncate to "Sys… Past… Cos…". Stacking is the only honest answer; scaling the
    /// text down would be undoing the setting the user asked for.
    private var isStacked: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        // AnyLayout rather than an if/else on two stacks: it keeps view identity across
        // the switch, so the selection pill and its animation survive a Dynamic Type
        // change instead of jumping.
        let layout = isStacked
            ? AnyLayout(VStackLayout(spacing: 2))
            : AnyLayout(HStackLayout(spacing: 2))

        return layout {
            ForEach(ThemePreference.allCases, id: \.self) { theme in
                segment(theme)
            }
        }
        .padding(3)
        .background(WematchTheme.surfaceInset, in: trackShape)
        // The pill slides between segments; with Reduce Motion it simply appears.
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Theme")
    }

    /// A capsule track around stacked rows would pinch its top and bottom segments, so
    /// the track squares off as the layout does.
    private var trackShape: AnyShape {
        isStacked
            ? AnyShape(RoundedRectangle(cornerRadius: WematchTheme.cornerRadiusLarge, style: .continuous))
            : AnyShape(Capsule())
    }

    private func segment(_ theme: ThemePreference) -> some View {
        let isSelected = theme == selection

        return Button {
            onSelect(theme)
        } label: {
            Text(theme.label)
                .font(isSelected ? WematchTypography.captionEmphasized : WematchTypography.caption)
                .foregroundStyle(isSelected ? WematchTheme.textOnColor : WematchTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(WematchTheme.actionGradient)
                            .matchedGeometryEffect(id: "selectedSegment", in: selectionIndicator)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(theme.accessibilityHint)
    }
}

// MARK: - Previews

/// One card per selectable state, so the selected pill can be checked against the track
/// in both themes at once — the measurement this component exists to satisfy.
private struct ThemePickerStates: View {
    var body: some View {
        ZStack {
            WematchTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: WematchTheme.paddingMedium) {
                ForEach(ThemePreference.allCases, id: \.self) { theme in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Theme")
                                .font(WematchTypography.body)
                                .foregroundStyle(WematchTheme.textPrimary)

                            ThemePicker(selection: theme) { _ in }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
    }
}

#Preview("Pastel Light") {
    ThemePickerStates()
        .environment(\.colorScheme, .light)
}

#Preview("Dark Cosmic") {
    ThemePickerStates()
        .environment(\.colorScheme, .dark)
}
