import SwiftUI

/// Everything the child should never see. Three tabs, because parents arrive for three
/// different reasons: to hear last night again, to teach Santa something new, or to change
/// how the app behaves. Recordings lead — they are the reason anyone opens this.
struct VaultView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        ZStack {
            VStack(spacing: 0) {
                navBar

                ScrollView {
                    VStack(spacing: 20) {
                        switch state.vaultTab {
                        case .recordings: RecordingsTab()
                        case .personalize: PersonalizeTab()
                        case .settings: VaultSettingsTab()
                        }
                    }
                    .padding(.horizontal, Metrics.listGutter)
                    .padding(.top, Metrics.listGutter)
                    .padding(.bottom, Metrics.bottom)
                }
                .scrollIndicators(.hidden)
            }

            sheets
        }
        // Deleting an album is the one action here with no undo, so the
        // confirmation is the system's own alert rather than something we drew —
        // a parent should recognise it instantly.
        .alert("Delete all recordings?", isPresented: $state.isConfirmingRecordingWipe) {
            Button("Delete", role: .destructive, action: state.deleteAllRecordings)
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Every recorded call goes from this phone for good. Santa still knows your children — only the recordings are removed.")
        }
    }

    /// Keyed on the sheet itself so opening Ben straight after Maya rebuilds the
    /// editor rather than reusing it — the draft lives in `@State`, and a reused
    /// view would still be holding the previous child's answers.
    @ViewBuilder
    private var sheets: some View {
        switch state.vaultSheet {
        case .child(let id): ChildEditorSheet(childID: id).id(id)
        case .language: LanguageSheet()
        case .lockGrace: LockGraceSheet()
        case nil: EmptyView()
        }
    }

    private var navBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                BackLabelButton(title: "Home", action: state.leaveVault)

                Text("The Vault")
                    .font(Typeface.rounded(17, .semibold))
                    .foregroundStyle(Palette.snow)
                    .frame(maxWidth: .infinity)

                // Lock is the same action as Home — the vault re-locks on leave either way.
                NavTextButton(title: "Lock", action: state.leaveVault)
            }
            .frame(minHeight: 44)

            VaultTabPicker(
                selection: state.vaultTab,
                onSelect: { state.vaultTab = $0 }
            )
            .padding(.horizontal, Metrics.Space.s)
            .padding(.top, Metrics.Space.s)
        }
        .padding(.top, Metrics.navTop)
        .padding(.horizontal, Metrics.Space.s)
        .padding(.bottom, 10)
        .translucentNavBackground()
    }
}

/// The three-way segmented control under the nav bar.
private struct VaultTabPicker: View {
    let selection: AppState.VaultTab
    let onSelect: (AppState.VaultTab) -> Void

    var body: some View {
        HStack(spacing: 3) {
            ForEach(AppState.VaultTab.allCases) { tab in
                let isActive = tab == selection
                Button(action: { onSelect(tab) }) {
                    Text(tab.title)
                        .font(Typeface.rounded(14, .semibold))
                        .foregroundStyle(isActive ? Palette.onAmber : Palette.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(isActive ? Palette.firelight : .clear)
                                .shadow(color: isActive ? .black.opacity(0.28) : .clear, radius: 4, y: 2)
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.08))
        }
    }
}
