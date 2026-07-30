import AVFoundation
// `Conversation` publishes with `@Published`, so the `.values` bridge below is a
// Combine API. The target sets SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY,
// which makes this import required rather than incidental.
import Combine
import ElevenLabs
import Foundation
import Observation

/// Owns the live ElevenLabs session. Knows nothing about HTTP — it is handed a
/// token that `BackendClient` already fetched.
///
/// Audio never touches santa_backend: this class opens WebRTC straight to
/// ElevenLabs and hands over the child's details as dynamic variables, so the
/// name, age, interests and secret go device → ElevenLabs and nowhere else.
@Observable
@MainActor
final class SantaCallService {

    /// Triggers the real system microphone prompt. The pre-permission explainer
    /// screen stays as designed; this is what runs when the parent taps
    /// Continue on it.
    static func requestMicrophoneAccess() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// Named distinctly from `AppState.CallPhase` — these are different concepts
    /// and sharing a name across two types invites a silent mix-up.
    enum SessionPhase: Equatable {
        case idle
        case connecting
        case active
        case ended
        case failed(SantaCallError)
    }

    private(set) var phase: SessionPhase = .idle
    private(set) var isSantaSpeaking = false
    private(set) var elapsedSeconds = 0

    /// Fires when the session ends without us asking — the agent hung up, or the
    /// connection died. `disconnect()` does not fire it, since that caller
    /// already knows. Without this the in-call screen would sit there forever
    /// after Santa rings off.
    @ObservationIgnored var onSessionEnded: ((SessionPhase) -> Void)?

    @ObservationIgnored private var conversation: Conversation?
    @ObservationIgnored private var observers: [Task<Void, Never>] = []
    @ObservationIgnored private var ticker: Task<Void, Never>?

    /// Opens the session and returns once it is live or has failed. `phase` is
    /// the answer — the caller should not show the in-call screen unless it
    /// reads `.active`.
    func connect(token: CallToken, language: String, variables: [String: String]) async {
        await teardown()

        phase = .connecting
        elapsedSeconds = 0
        isSantaSpeaking = false

        do {
            let conversation = try await ElevenLabs.startConversation(
                conversationToken: token.token,
                config: ConversationConfig(
                    agentOverrides: agentOverrides(for: language),
                    dynamicVariables: variables
                )
            )
            self.conversation = conversation
            observe(conversation)
            startTicker()
            phase = .active
        } catch {
            phase = .failed(.dropped)
        }
    }

    func disconnect() async {
        await teardown()
        phase = .ended
    }

    // MARK: Session plumbing

    /// The agent speaks English, Spanish and German. Anything else the picker
    /// offers would be an override the agent cannot honour, so Santa stays in
    /// English rather than failing the call outright.
    private func agentOverrides(for code: String) -> AgentOverrides? {
        switch code {
        case "es": AgentOverrides(language: .spanish)
        case "de": AgentOverrides(language: .german)
        default: nil
        }
    }

    /// `Conversation` publishes with Combine rather than exposing async
    /// sequences, so each `@Published` value is bridged through `.values`.
    private func observe(_ conversation: Conversation) {
        observers.append(Task { [weak self] in
            for await state in conversation.$agentState.values {
                guard let self else { return }
                self.isSantaSpeaking = (state == .speaking)
            }
        })

        observers.append(Task { [weak self] in
            for await state in conversation.$state.values {
                guard let self else { return }
                switch state {
                case .ended:
                    self.finish(as: .ended)
                case .error:
                    self.finish(as: .failed(.dropped))
                default:
                    break
                }
            }
        })
    }

    /// The session stopped on its own. Stop the clock, then tell whoever is
    /// showing the in-call screen.
    private func finish(as ending: SessionPhase) {
        ticker?.cancel()
        ticker = nil
        isSantaSpeaking = false
        phase = ending
        onSessionEnded?(ending)
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.phase == .active else { continue }
                self.elapsedSeconds += 1
            }
        }
    }

    /// Cancels every observer before ending the session, so the `.ended` state
    /// the SDK emits on the way out cannot race the caller's own phase change.
    private func teardown() async {
        ticker?.cancel()
        ticker = nil
        observers.forEach { $0.cancel() }
        observers.removeAll()

        if let conversation {
            self.conversation = nil
            await conversation.endConversation()
        }
        isSantaSpeaking = false
    }
}
