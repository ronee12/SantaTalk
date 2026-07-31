import SwiftUI

/// Owns the app state and decides which screen is on top of which backdrop.
///
/// The night scene runs only behind the screens a child sees; every parent screen sits on a
/// still gradient so nothing competes with a recording, a wish list or a price.
struct RootView: View {
    @State private var state: AppState

    init(profiles: ProfileStore, recordings: RecordingStore) {
        _state = State(initialValue: AppState(store: profiles, recordings: recordings))
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
