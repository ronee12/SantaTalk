import SwiftUI

/// Everything Santa knows about one child, on one sheet.
///
/// Add and edit are the same form because they ask for the same four things —
/// the ones onboarding collects. A parent who adds a second child should not be
/// walked through eight steps again, and a parent correcting a name should not
/// have to guess which screen it lives on.
struct ChildEditorSheet: View {
    @Environment(AppState.self) private var state

    /// Nil adds, an id edits.
    let childID: UUID?

    @State private var name: String = ""
    @State private var age: Int = 6
    @State private var interests: [String] = []
    @State private var secret: String = ""
    @State private var customInterest: String = ""
    @State private var isConfirmingDelete = false
    @State private var hasLoaded = false

    private var existing: ChildProfile? {
        childID.flatMap(state.child(withID:))
    }

    private var isEditing: Bool { existing != nil }
    private var canSave: Bool { !name.trimmed.isEmpty }

    var body: some View {
        BottomSheetContainer(
            maxHeightFraction: 0.92,
            background: Palette.sheet.opacity(0.98),
            onDismiss: { state.vaultSheet = nil }
        ) {
            SheetHeader(title: isEditing ? "About \(existing?.name ?? "")" : "Add a child") {
                state.vaultSheet = nil
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.Space.xl) {
                    nameField
                    ageField
                    interestsField
                    secretField

                    if isEditing { deleteRow }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, Metrics.Space.s)
                .padding(.bottom, Metrics.Space.xl)
            }
            .scrollIndicators(.hidden)

            AmberButton(
                title: isEditing ? "Save" : "Add \(name.trimmed.isEmpty ? "child" : name.trimmed)",
                height: 54,
                cornerRadius: Metrics.Radius.tile,
                fontSize: 17,
                isEnabled: canSave,
                action: save
            )
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, Metrics.sheetBottom)
        }
        .onAppear(perform: load)
        .alert("Remove \(existing?.name ?? "this child")?", isPresented: $isConfirmingDelete) {
            Button("Remove", role: .destructive) {
                if let existing { state.deleteChild(existing) }
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Santa forgets everything he knows about them. Calls you have already recorded are kept — clear those from Settings.")
        }
    }

    // MARK: Fields

    private var nameField: some View {
        FieldBlock(caption: "NAME", hint: "The name Santa says out loud.") {
            GlassTextField(
                placeholder: "Their first name",
                text: $name,
                height: 52,
                fontSize: 17,
                accessibilityTitle: "Child's name"
            )
        }
    }

    private var ageField: some View {
        FieldBlock(
            caption: "AGE",
            hint: "Santa changes how he talks — shorter sentences for the little ones."
        ) {
            FlowLayout(spacing: 10, lineSpacing: 10) {
                ForEach(Catalog.ages, id: \.self) { option in
                    AgeChip(age: option, isSelected: age == option) { age = option }
                }
            }
        }
    }

    private var interestsField: some View {
        FieldBlock(
            caption: "WHAT THEY ARE INTO",
            hint: "Santa brings these up himself, which is the moment that lands."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                FlowLayout(spacing: 10, lineSpacing: 10) {
                    ForEach(everyInterest, id: \.self) { interest in
                        InterestPill(
                            label: interest,
                            isSelected: interests.contains(interest),
                            action: { toggle(interest) }
                        )
                    }
                }

                HStack(spacing: Metrics.Space.s) {
                    GlassTextField(
                        placeholder: "Something else",
                        text: $customInterest,
                        height: 46,
                        fontSize: 15,
                        accessibilityTitle: "Add another interest"
                    )

                    Button(action: addCustomInterest) {
                        Text("Add")
                            .font(Typeface.rounded(15, .semibold))
                            .foregroundStyle(customInterest.trimmed.isEmpty
                                             ? Palette.faint : Palette.firelight)
                            .padding(.horizontal, Metrics.Space.m)
                            .frame(height: 46)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(customInterest.trimmed.isEmpty)
                }
            }
        }
    }

    private var secretField: some View {
        FieldBlock(
            caption: "ONE THING ONLY YOU WOULD KNOW",
            hint: "This is what makes the call land. It never leaves this phone."
        ) {
            GlassTextEditor(
                placeholder: "Lost her first tooth",
                text: $secret,
                minHeight: 80,
                accessibilityTitle: "One thing only you would know"
            )
        }
    }

    private var deleteRow: some View {
        VStack(alignment: .leading, spacing: Metrics.Space.s) {
            Button(action: { isConfirmingDelete = true }) {
                Text("Remove this child")
                    .font(Typeface.rounded(16, .regular))
                    .foregroundStyle(state.canDeleteChildren ? Palette.destructive : Palette.faint)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background {
                        RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
                            .fill(Palette.glass)
                    }
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(!state.canDeleteChildren)

            if !state.canDeleteChildren {
                Text("Santa needs at least one child to call.")
                    .font(Typeface.rounded(13, .regular))
                    .foregroundStyle(Palette.faint)
                    .padding(.horizontal, Metrics.Space.xs)
            }
        }
    }

    // MARK: Behaviour

    /// The sheet is the only owner of its draft, so editing Ben never disturbs
    /// the child the dashboard is currently set up to call. `hasLoaded` guards
    /// against a re-appear wiping what the parent has typed.
    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true

        guard let existing else { return }
        name = existing.name
        age = existing.age
        interests = existing.interests
        secret = existing.secret
    }

    /// The catalogue plus anything already saved that is not in it, so a custom
    /// interest typed last month still shows as selected rather than vanishing.
    private var everyInterest: [String] {
        Catalog.interests + interests.filter { !Catalog.interests.contains($0) }
    }

    private func toggle(_ interest: String) {
        if let index = interests.firstIndex(of: interest) {
            interests.remove(at: index)
        } else {
            interests.append(interest)
        }
    }

    private func addCustomInterest() {
        let trimmed = customInterest.trimmed
        guard !trimmed.isEmpty, !interests.contains(trimmed) else { return }
        interests.append(trimmed)
        customInterest = ""
    }

    private func save() {
        state.saveChild(
            id: childID,
            name: name,
            age: age,
            interests: interests,
            secret: secret.trimmed
        )
    }
}

// MARK: - Pieces

/// A caption, a control, and the one line saying why the app is asking.
private struct FieldBlock<Content: View>: View {
    let caption: String
    let hint: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Space.s) {
            Text(caption)
                .font(Typeface.rounded(12, .regular))
                .tracking(0.6)
                .foregroundStyle(Palette.tertiary)

            content

            Text(hint)
                .font(Typeface.rounded(13, .regular))
                .foregroundStyle(Palette.faint)
                .lineHeight(1.45, size: 13)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AgeChip: View {
    let age: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(age)")
                .font(Typeface.rounded(17, .semibold))
                .foregroundStyle(isSelected ? Palette.onAmber : Palette.chevron)
                .frame(width: 48, height: 48)
                .background {
                    RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
                        .fill(isSelected
                              ? AnyShapeStyle(Gradients.amberChip)
                              : AnyShapeStyle(Palette.glassRaised))
                        .overlay {
                            RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
                                .stroke(isSelected ? Palette.firelightSoft : Palette.strokeStrong,
                                        lineWidth: 1)
                        }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .accessibilityLabel("\(age) years old")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The onboarding interest chip at vault scale — state is never colour-only, so
/// it carries a `+` or a `✓` too.
private struct InterestPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(isSelected ? "✓" : "+")
                    .font(Typeface.rounded(13, .bold))
                    .foregroundStyle(isSelected ? Color(hex: 0x1B2338) : Color(hex: 0x8A6420))
                    .frame(width: 10)

                Text(label)
                    .font(Typeface.rounded(15, .medium))
                    .foregroundStyle(isSelected ? Palette.onAmber : Palette.snow)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background {
                Capsule()
                    .fill(isSelected
                          ? AnyShapeStyle(Gradients.amberChip)
                          : AnyShapeStyle(Palette.glassRaised))
                    .overlay {
                        Capsule().stroke(isSelected ? Palette.firelightSoft : Palette.strokeStrong,
                                         lineWidth: 1)
                    }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
