import SwiftUI

/// Priced after the value has landed. The App Store standard shape: full-bleed hero, the
/// benefits with a line each, three plans, one button. A real close button, and the exact
/// renewal date under the button rather than behind a link.
struct PaywallView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            header
            features
            purchasePanel
        }
        .background(Palette.nightDeep.ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        ZStack(alignment: .top) {
            HStack {
                Button(action: state.dismissPaywall) {
                    CloseGlyph()
                        .stroke(Palette.snow, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        .frame(width: 17, height: 17)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")

                Spacer()
            }
            .padding(.leading, 14)

            VStack(spacing: Metrics.Space.l) {
                HStack(spacing: Metrics.Space.s) {
                    HollyBranch()
                    Text("Loved by\nSanta")
                        .font(Typeface.rounded(25, .bold))
                        .tracking(-0.4)
                        .foregroundStyle(Palette.cream)
                        .lineHeight(1.15, size: 25)
                        .multilineTextAlignment(.center)
                    HollyBranch(mirrored: true)
                }

                HStack(spacing: 10) {
                    RatingStars()
                    Text("11K Ratings")
                        .font(Typeface.rounded(19, .semibold))
                        .foregroundStyle(Palette.cream)
                }
            }
            .padding(.top, Metrics.Space.xs)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
        .background {
            // The arch is clipped inside the header's own rect, then that rect is grown
            // upward so the gradient runs behind the status bar.
            Gradients.paywallHeader
                .clipShape(ArchBottom(archHeight: 46))
                .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            appIcon.offset(y: 52)
        }
        .zIndex(1)
    }

    private var appIcon: some View {
        ImageSlot(label: "App icon", imageName: "SantaPortrait", cornerRadius: Metrics.Space.xl)
            .frame(width: 104, height: 104)
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.Space.xl, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 3)
            }
            .shadow(color: .black.opacity(0.45), radius: 15, y: 12)
    }

    // MARK: Features

    private var features: some View {
        VStack(spacing: 0) {
            Text("Premium Features")
                .font(Typeface.rounded(21, .bold))
                .tracking(-0.2)
                .foregroundStyle(Palette.secondary)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: Metrics.Space.l) {
                FeatureRow(title: Catalog.premiumFeatures[0]) {
                    HandsetGlyph().fill(Palette.firelight).frame(width: 17, height: 17)
                }
                FeatureRow(title: Catalog.premiumFeatures[1]) {
                    ChatBubbleGlyph().fill(Palette.firelight).frame(width: 17, height: 17)
                }
                FeatureRow(title: Catalog.premiumFeatures[2]) {
                    MicrophoneSolidIcon(size: 17, capsuleColor: Palette.firelight,
                                        cradleColor: Palette.firelight)
                }
                FeatureRow(title: Catalog.premiumFeatures[3]) {
                    PeopleIcon()
                }
            }
            .padding(.top, 20)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 68)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: Plans and purchase

    private var purchasePanel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(SubscriptionPlan.allCases) { plan in
                    PlanTile(
                        plan: plan,
                        price: Format.money(state.pricing.price(for: plan)),
                        per: state.pricing.perLabel(for: plan),
                        isSelected: state.plan == plan,
                        action: { state.plan = plan }
                    )
                }
            }

            AmberButton(
                title: "Continue",
                height: 58,
                cornerRadius: 29,
                fontSize: 20,
                action: state.buy
            )

            Text(state.pricing.fineprint(for: state.plan))
                .font(Typeface.rounded(12, .regular))
                .foregroundStyle(Palette.faint)
                .lineHeight(1.4, size: 12)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Restore sits with Terms and Privacy, exactly where a parent looks for it.
            HStack(spacing: 0) {
                LegalLink(title: "Terms", action: {})
                legalDivider
                LegalLink(title: "Restore", action: state.restorePurchase)
                legalDivider
                LegalLink(title: "Privacy", action: {})
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, Metrics.bottom)
    }

    private var legalDivider: some View {
        Rectangle()
            .fill(Color(hex: 0xEDF2FF, opacity: 0.2))
            .frame(width: 1, height: 16)
    }
}

// MARK: - Pieces

/// The bottom edge curves away as a shallow ellipse, matching the comp's
/// `border-bottom-*-radius: 50% 46px`.
struct ArchBottom: Shape {
    let archHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - archHeight))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - archHeight),
            control: CGPoint(x: rect.midX, y: rect.maxY + archHeight)
        )
        path.closeSubpath()
        return path
    }
}

private struct FeatureRow<Icon: View>: View {
    let title: String
    @ViewBuilder let icon: Icon

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: 0xF5B14C, opacity: 0.14))
                .frame(width: 32, height: 32)
                .overlay { icon }

            Text(title)
                .font(Typeface.rounded(17, .regular))
                .foregroundStyle(Palette.snow)
        }
    }
}

/// Yearly is pre-selected with the per-week price shown; weekly exists so nobody feels
/// trapped into a year for one December.
private struct PlanTile: View {
    let plan: SubscriptionPlan
    let price: String
    let per: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(plan.ribbon)
                    .font(Typeface.rounded(11, .bold))
                    .tracking(0.2)
                    .foregroundStyle(isSelected ? Palette.onAmber : Palette.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 28)
                    .background {
                        if isSelected {
                            Gradients.amberChip
                        } else {
                            Color.white.opacity(0.09)
                        }
                    }

                VStack(spacing: 6) {
                    Text(plan.title)
                        .font(Typeface.rounded(17, .semibold))
                        .foregroundStyle(Palette.snow)
                    Text(price)
                        .font(Typeface.rounded(18, .bold))
                        .foregroundStyle(Palette.cream)
                    Text(per)
                        .font(Typeface.rounded(12, .regular))
                        .foregroundStyle(Palette.tertiary)
                }
                .padding(.horizontal, 6)
                .padding(.top, Metrics.Space.m)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isSelected ? Color(hex: 0xF5B14C, opacity: 0.10) : Palette.glassSunk)
            }
            .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous)
                    .stroke(isSelected ? Palette.firelight : Palette.stroke, lineWidth: 2)
            }
            .shadow(color: isSelected ? Palette.firelight.opacity(0.2) : .clear, radius: 11, y: 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(plan.title), \(price)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct LegalLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typeface.rounded(14, .regular))
                .foregroundStyle(Palette.tertiary)
                .padding(.horizontal, 14)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Two heads and two shoulders — the "up to 4 children" mark.
private struct PeopleIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.firelight)
                .frame(width: 5.6, height: 5.6)
                .offset(x: -2.6, y: -2.9)
            Circle()
                .fill(Palette.firelight.opacity(0.7))
                .frame(width: 4.4, height: 4.4)
                .offset(x: 3.6, y: -2)
            PeopleGlyph()
                .stroke(Palette.firelight, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        .frame(width: 17, height: 17)
    }
}
