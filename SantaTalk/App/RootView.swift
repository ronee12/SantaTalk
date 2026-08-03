import SwiftUI

/// Owns the app state and decides which screen is on top of which backdrop.
///
/// The night scene runs only behind the screens a child sees; every parent screen sits on a
/// still gradient so nothing competes with a recording, a wish list or a price.
struct RootView: View {
    @State private var state: AppState
    @Environment(\.scenePhase) private var scenePhase

    init(profiles: ProfileStore, recordings: RecordingStore, schedules: ScheduleStore) {
        _state = State(
            initialValue: AppState(store: profiles, recordings: recordings, schedules: schedules)
        )
    }

    var body: some View {
        ZStack {
            if state.showsNightScene {
                NightSceneView(sleighProgress: state.sleighProgress)
            } else {
                ParentBackdrop()
            }

            screen
        }
        .environment(state)
        .preferredColorScheme(.dark)
        // Presented over whichever screen asked for it — the recordings list or
        // the player — so it returns to the right one on the way out.
        .fullScreenCover(
            item: Binding(get: { state.sharingRecording }, set: { if $0 == nil { state.closeShare() } })
        ) { recording in
            TrimShareView(recording: recording)
                .environment(state)
                .preferredColorScheme(.dark)
        }
        // An external santatalk:// link. A tapped notification reaches the same
        // place through `CallLaunchInbox`, so both ways in share one path.
        .onOpenURL { CallLaunchInbox.shared.deliver(url: $0) }
        .task {
            state.refreshSchedules()
            state.consumePendingLaunch()
            // Ahead of the first call rather than at the paywall: `endCall()`
            // reads `isPro` to decide whether a price is shown at all, and a
            // parent who has already paid must never see one.
            await state.refreshSubscription()
        }
        // Local notifications fire whether or not anyone is watching, so coming
        // back to the front means catching up: sweep what expired, re-arm what
        // is left, and pick up a tap that landed before this view existed.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            state.refreshSchedules()
            state.consumePendingLaunch()
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch state.screen {
        case .onboarding: OnboardingFlowView()
        case .home: callSequence
        case .chat: ChatView()
        case .gate: ParentGateView()
        case .vault: VaultView()
        case .player: PlayerView()
        case .safety: SafetyView()
        case .paywall: PaywallView()
        case .purchased: PurchaseConfirmedView()
        }
    }

    /// The dashboard and the four states it moves through once a call is armed.
    @ViewBuilder
    private var callSequence: some View {
        switch state.phase {
        case .idle: HomeView()
        case .countdown: CountdownView()
        case .scheduled: ScheduledView()
        case .ringing: RingingView()
        case .connecting: ConnectingView()
        case .inCall: InCallView()
        case .failed(let error): CallFailedView(error: error)
        }
    }
}
