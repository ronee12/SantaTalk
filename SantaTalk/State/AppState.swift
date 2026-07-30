import SwiftUI

/// Drives navigation and screen content for the whole prototype.
///
/// This is UI state only — there is no networking, no persistence and no real call pipeline.
/// Everything a screen needs to render is either stored here or derived here, so the views
/// stay declarative.
@Observable
final class AppState {

    // MARK: Navigation

    enum Screen {
        case onboarding, home, chat, gate, vault, player, safety, paywall, purchased
    }

    /// Where the home screen is in the call sequence.
    enum CallPhase: Equatable {
        case idle, countdown, scheduled, ringing, connecting, inCall
        case failed(SantaCallError)
    }

    enum HomeSheet: Identifiable {
        case when, topic, notification, picker
        var id: Self { self }
    }

    enum VaultTab: String, CaseIterable, Identifiable {
        case recordings, personalize, settings
        var id: String { rawValue }

        var title: String {
            switch self {
            case .recordings: "Recordings"
            case .personalize: "Personalize"
            case .settings: "Settings"
            }
        }
    }

    var screen: Screen = .onboarding
    /// Onboarding step, 0 through 7.
    var step: Int = 0
    var phase: CallPhase = .idle
    var sheet: HomeSheet?

    // MARK: What Santa knows

    var childName: String = "Maya"
    var age: Int = 6
    var interests: [String] = ["Dinosaurs", "Drawing", "Dogs"]
    var secret: String = ""
    var microphone: PermissionState = .idle
    var camera: PermissionState = .idle
    var language: Language = Catalog.languages[0]

    // MARK: The call the parent is setting up

    var timingSeconds: Int = 3
    var schedule: String?
    var topic: String?
    var customTopic: String = ""
    var notifications: PermissionState = .idle
    var countdown: Int = 3
    /// Bumping this restarts the connect confetti.
    var burstToken: Int = 0

    // MARK: Any-date-and-time picker

    var pickerDay: Int = 0
    var pickerHour: Int = 7
    var pickerMinute: Int = 0
    var pickerMeridiem: String = "PM"

    // MARK: Grown-ups-only gate

    var gateNumbers: [Int] = []
    var gatePicked: [Int] = []
    var gateFailed: Bool = false

    // MARK: Vault

    var vaultTab: VaultTab = .recordings
    var expandedRecordingID: String?
    var isRecordingEnabled: Bool = true { didSet { persistSettings() } }
    var keepsReactionVideo: Bool = true { didSet { persistSettings() } }
    var remindsBeforeCall: Bool = true { didSet { persistSettings() } }
    var ringtoneID: String = "sleigh" { didSet { persistSettings() } }
    var activeChildIndex: Int = 0

    // MARK: Player

    var playerIndex: Int = 0
    var isPlaying: Bool = false
    var playPosition: Int = 0

    // MARK: Purchase

    var isPro: Bool = false { didSet { persistSettings() } }
    var plan: SubscriptionPlan = .year
    let pricing = Pricing()

    // MARK: Content

    var children: [Child] = SampleData.children
    var recordings: [Recording] = SampleData.recordings
    var schedules: [ScheduledCall] = SampleData.schedules
    var chat: [ChatMessage] = SampleData.chat
    var draft: String = ""

    // MARK: The live call

    /// Owns the ElevenLabs session, the speaking indicator and the call timer.
    let callService = SantaCallService()

    @ObservationIgnored lazy var backend: BackendClientProtocol = BackendClient(
        baseURL: BackendConfig.baseURL,
        devKey: BackendConfig.devKey
    )

    // MARK: Timers

    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var connectTask: Task<Void, Never>?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?

    // MARK: Local storage

    /// Nil in previews and tests, where nothing should be written to disk.
    @ObservationIgnored private let store: ProfileStore?
    /// Suppresses the `didSet` writes while `hydrate()` is assigning.
    @ObservationIgnored private var isHydrating = false

    init(store: ProfileStore? = nil) {
        self.store = store

        if let match = Catalog.language(forLocaleIdentifier: Locale.current.identifier) {
            language = match
        }

        hydrate()

        // Santa hanging up, or the line dying, has to move the screen on — the
        // child has no other way out of the in-call view.
        callService.onSessionEnded = { [weak self] ending in
            guard let self, self.phase == .inCall else { return }
            if case .failed(let error) = ending {
                withAnimation(.easeOut(duration: 0.32)) { self.phase = .failed(error) }
            } else {
                self.endCall()
            }
        }
    }
}

// MARK: - Local storage

extension AppState {

    /// Reads the device back into memory at launch. A *completed* profile opens
    /// the app on the dashboard, instead of asking again for a name the parent
    /// has already given.
    private func hydrate() {
        isHydrating = true
        defer { isHydrating = false }

        // iOS remembers the microphone grant across launches and reinstalls, so
        // ask the system rather than trusting anything we stored. Without this
        // the knowledge meter claims the microphone is off when it is not.
        microphone = SantaCallService.microphoneState
        camera = CameraCapture.permissionState

        guard let store else { return }

        let settings = store.settings()
        isPro = settings.isPro
        ringtoneID = settings.ringtoneID
        isRecordingEnabled = settings.isRecordingEnabled
        keepsReactionVideo = settings.keepsReactionVideo
        remindsBeforeCall = settings.remindsBeforeCall

        guard let profile = store.profile() else { return }
        childName = profile.name
        age = profile.age
        interests = profile.interests
        secret = profile.secret
        if let match = Catalog.languages.first(where: { $0.id == profile.languageID }) {
            language = match
        }

        // A half-finished profile restores its answers but still owes the
        // remaining steps, so onboarding resumes rather than being skipped.
        if profile.isSetupComplete { screen = .home }
    }

    /// Writes the onboarding answers. Called as the parent moves through the
    /// steps, so a force-quit halfway does not lose what they have typed.
    func persistProfile(markingComplete: Bool = false) {
        guard !isHydrating, let store else { return }

        let profile = store.profileForWriting()
        profile.name = childName
        profile.age = age
        profile.interests = interests
        profile.secret = secret
        profile.languageID = language.id
        if markingComplete { profile.isSetupComplete = true }
        profile.updatedAt = .now
        store.commit()
    }

    private func persistSettings() {
        guard !isHydrating, let store else { return }

        let settings = store.settings()
        settings.isPro = isPro
        settings.ringtoneID = ringtoneID
        settings.isRecordingEnabled = isRecordingEnabled
        settings.keepsReactionVideo = keepsReactionVideo
        settings.remindsBeforeCall = remindsBeforeCall
        store.commit()
    }
}

// MARK: - Derived scene state

extension AppState {

    /// The night scene runs only behind the screens a child sees.
    var showsNightScene: Bool {
        switch screen {
        case .onboarding, .home, .chat: true
        default: false
        }
    }

    /// The sleigh flies further across the sky with every answered onboarding step.
    var sleighProgress: CGFloat {
        screen == .onboarding ? (-0.18 + CGFloat(step) * 0.17) : 0.68
    }
}

// MARK: - Derived onboarding state

extension AppState {

    /// Name 20, age 15, up to three interests at 10 each, the secret 25 — out of 90.
    var knowledgeScore: Int {
        (childName.trimmed.isEmpty ? 0 : 20)
            + 15
            + min(3, interests.count) * 10
            + (secret.trimmed.isEmpty ? 0 : 25)
    }

    var knowledgePercent: Int {
        Int((Double(knowledgeScore) / 90 * 100).rounded())
    }

    /// The meter reads the active child in the vault and the setup answers during onboarding.
    func meterPercent(inVault: Bool) -> Int {
        inVault ? (activeChild?.knowledge ?? knowledgePercent) : knowledgePercent
    }

    func meterLabel(inVault: Bool) -> String {
        let name = inVault ? (activeChild?.name ?? childName) : childName
        let percent = meterPercent(inVault: inVault)
        if percent >= 80 { return "Santa knows \(name) really well" }
        if percent >= 55 { return "Santa knows \(name) well" }
        return "Santa is still learning about \(name)"
    }

    struct MeterRow: Identifiable {
        let id = UUID()
        let text: String
        let isDone: Bool

        var mark: String { isDone ? "✓" : "○" }
        var color: Color { isDone ? Palette.snow : Palette.secondary }
    }

    /// The meter names what is missing — the only nudge the parent zone gets.
    var meterRows: [MeterRow] {
        [
            MeterRow(text: "Her name and age", isDone: !childName.trimmed.isEmpty),
            MeterRow(
                text: interests.isEmpty
                    ? "Nothing she is into yet"
                    : interests.prefix(3).joined(separator: ", "),
                isDone: !interests.isEmpty
            ),
            MeterRow(
                text: secret.trimmed.isEmpty
                    ? "One thing only you would know — still empty"
                    : "“\(secret.trimmed)”",
                isDone: !secret.trimmed.isEmpty
            ),
            MeterRow(
                text: microphone == .granted ? "Microphone allowed" : "Microphone not allowed yet",
                isDone: microphone == .granted
            )
        ]
    }

    /// Encouragement, not validation — being blocked here would be the wrong lesson.
    var interestCountLabel: String {
        switch interests.count {
        case 0: "Nothing picked — Santa will keep it general"
        case 1: "1 thing picked"
        default: "\(interests.count) things picked"
        }
    }

    func isInterestSelected(_ interest: String) -> Bool {
        interests.contains(interest)
    }
}

// MARK: - Derived home state

extension AppState {

    var activeChild: Child? {
        children.indices.contains(activeChildIndex) ? children[activeChildIndex] : nil
    }

    var timing: CallTiming {
        Catalog.timings.first { $0.seconds == timingSeconds } ?? Catalog.timings[0]
    }

    /// What the When row reads.
    var whenValue: String { schedule ?? timing.label }

    var topicValue: String { topic ?? "Pick a topic" }

    /// A schedule or anything a minute out is booked rather than dialled.
    var isScheduling: Bool { schedule != nil || timingSeconds >= 60 }

    /// The label mirrors the setting, so the red button says exactly what it will do.
    var callToActionLabel: String {
        if schedule != nil { return "Schedule the call" }
        return isScheduling
            ? "Schedule the call \(timing.label.lowercased())"
            : "Start call \(timing.label.lowercased())"
    }

    var callToActionHint: String {
        guard isScheduling else { return "Keep the app open until the phone rings." }
        return notifications == .denied
            ? "Notifications are off, so keep an eye on the clock — the call needs the app open."
            : "We remind you five minutes before, so the phone is in the right hands."
    }

    var notificationWhen: String { schedule ?? timing.label.lowercased() }

    /// Shown under Santa's name while the phone rings, so a parent glancing over knows
    /// what he is about to bring up.
    var ringingTopic: String {
        guard let topic else { return "A hello from the North Pole" }
        return "About " + topic.prefix(1).lowercased() + topic.dropFirst()
    }

    var callTimerLabel: String {
        let seconds = callService.elapsedSeconds
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    var pickerSummary: String {
        let days = Format.dayLabels()
        let day = days.indices.contains(pickerDay) ? days[pickerDay] : days[0]
        return "\(day), \(pickerHour):\(String(format: "%02d", pickerMinute)) \(pickerMeridiem)"
    }
}

// MARK: - Derived vault state

extension AppState {

    var recordingsForActiveChild: [Recording] {
        guard let name = activeChild?.name else { return [] }
        return recordings.filter { $0.childName == name }
    }

    /// `2 CALLS WITH MAYA · 4:24 TOTAL`
    var recordingCountLabel: String {
        let list = recordingsForActiveChild
        let name = (activeChild?.name ?? "").uppercased()
        let noun = list.count == 1 ? " CALL WITH " : " CALLS WITH "
        let total = Format.duration(list.reduce(0) { $0 + $1.seconds })
        return "\(list.count)\(noun)\(name) · \(total) TOTAL"
    }

    var currentRecording: Recording? {
        recordings.indices.contains(playerIndex) ? recordings[playerIndex] : nil
    }

    var playbackFraction: Double {
        guard let seconds = currentRecording?.seconds, seconds > 0 else { return 0 }
        return min(1, Double(playPosition) / Double(seconds))
    }

    var playbackRemaining: String {
        let total = currentRecording?.seconds ?? 0
        return "-" + Format.duration(max(0, total - playPosition))
    }

    var gateHint: String {
        if gateFailed { return "Not quite — start with the smallest one." }
        return gatePicked.isEmpty ? "" : "Keep going."
    }
}

// MARK: - Onboarding actions

extension AppState {

    func nextStep() {
        persistProfile()
        withAnimation(.easeOut(duration: 0.42)) { step = min(7, step + 1) }
    }

    func previousStep() {
        withAnimation(.easeOut(duration: 0.42)) { step = max(0, step - 1) }
    }

    func go(toStep target: Int) {
        withAnimation(.easeOut(duration: 0.42)) {
            screen = .onboarding
            step = target
        }
    }

    func toggleInterest(_ interest: String) {
        if let index = interests.firstIndex(of: interest) {
            interests.remove(at: index)
        } else {
            interests.append(interest)
        }
    }

    /// A pre-permission screen has stated the reason; hand over to the system now.
    ///
    /// The explainer screen is ours, but the alerts themselves must be the
    /// genuine system ones — a custom-drawn permission dialog reads as a
    /// phishing attempt.
    ///
    /// Both alerts are raised here, back to back, because this is the last
    /// moment the parent is holding the phone. Asking for the camera mid-call
    /// would put a system alert in front of a four-year-old.
    func askForMicrophone() {
        microphone = .asking
        Task { @MainActor in
            let granted = await SantaCallService.requestMicrophoneAccess()
            microphone = granted ? .granted : .denied

            camera = .asking
            let sawCamera = await CameraCapture.requestAccess()
            camera = sawCamera ? .granted : .denied

            try? await Task.sleep(for: .milliseconds(260))
            go(toStep: 7)
        }
    }

    /// The physical moment the phone changes hands is the transition between the two zones.
    ///
    /// Also the moment setup is complete, so this is the write that makes the
    /// next launch open on the dashboard.
    func handOverToChild() {
        persistProfile(markingComplete: true)
        withAnimation(.easeOut(duration: 0.42)) {
            screen = .home
            phase = .idle
        }
    }
}

// MARK: - What Santa is told

extension AppState {

    /// Everything Santa is told about the child. Sent device → ElevenLabs at
    /// session start; it never passes through santa_backend.
    var santaDynamicVariables: [String: String] {
        [
            "child_name": childName,
            "child_age": String(age),
            "child_interests": interests.joined(separator: ", "),
            "child_secret": secret.trimmed,
            "call_topic": topic ?? ""
        ]
    }

    /// The picker offers 32 languages; the agent is configured for three. This
    /// reports the language Santa will actually speak, so the backend records
    /// what happened rather than what was asked for.
    var santaLanguageCode: String {
        switch language.english {
        case "Spanish": "es"
        case "German": "de"
        default: "en"
        }
    }
}

// MARK: - Call actions

extension AppState {

    func armCall() {
        if isScheduling && notifications == .idle {
            sheet = .notification
            return
        }
        if isScheduling {
            saveSchedule()
            withAnimation(.easeOut(duration: 0.42)) { phase = .scheduled }
            return
        }
        startCountdown()
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdown = timingSeconds
        withAnimation(.easeOut(duration: 0.42)) { phase = .countdown }

        countdownTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if countdown <= 1 {
                    countdown = 0
                    withAnimation(.easeOut(duration: 0.32)) { phase = .ringing }
                    return
                }
                countdown -= 1
            }
        }
    }

    func cancelCall() {
        countdownTask?.cancel()
        withAnimation(.easeOut(duration: 0.32)) { phase = .idle }
    }

    func declineCall() {
        withAnimation(.easeOut(duration: 0.32)) { phase = .idle }
    }

    /// Fetches a token, opens the session, and only then shows the in-call
    /// screen. The connecting screen covers the wait, so the tap has an
    /// immediate answer even though the line takes a moment to open.
    ///
    /// One burst on connect, then stillness — and the burst fires on a real
    /// connection, never optimistically.
    func acceptCall() {
        connectTask?.cancel()
        withAnimation(.easeOut(duration: 0.28)) { phase = .connecting }

        connectTask = Task { @MainActor in
            do {
                let token = try await backend.requestCallToken(
                    deviceId: DeviceIdentity.current(),
                    language: santaLanguageCode
                )
                try Task.checkCancellation()

                await callService.connect(
                    token: token,
                    language: santaLanguageCode,
                    variables: santaDynamicVariables
                )

                // Cancelled while the session was opening. The SDK call cannot be
                // interrupted mid-flight, so the session is closed on arrival.
                guard !Task.isCancelled else {
                    await callService.disconnect()
                    return
                }

                guard callService.phase == .active else {
                    withAnimation(.easeOut(duration: 0.32)) { phase = .failed(.dropped) }
                    return
                }

                burstToken += 1
                withAnimation(.easeOut(duration: 0.32)) { phase = .inCall }
            } catch is CancellationError {
                await callService.disconnect()
            } catch let error as SantaCallError {
                withAnimation(.easeOut(duration: 0.32)) { phase = .failed(error) }
            } catch {
                withAnimation(.easeOut(duration: 0.32)) { phase = .failed(.dropped) }
            }
        }
    }

    /// Backing out while the line is still opening. Cancelling here must also
    /// close the session, or a call the child walked away from stays live and
    /// keeps costing money.
    func cancelConnecting() {
        connectTask?.cancel()
        connectTask = nil
        Task { @MainActor in await callService.disconnect() }
        withAnimation(.easeOut(duration: 0.32)) { phase = .idle }
    }

    /// The paywall opens seconds after the call ends — never before the first call.
    func endCall() {
        Task { @MainActor in
            await callService.disconnect()
            withAnimation(.easeOut(duration: 0.38)) {
                phase = .idle
                screen = isPro ? .home : .paywall
            }
        }
    }

    func allowNotifications() {
        notifications = .granted
        confirmSchedule()
    }

    func skipNotifications() {
        notifications = .denied
        confirmSchedule()
    }

    private func confirmSchedule() {
        sheet = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(240))
            saveSchedule()
            withAnimation(.easeOut(duration: 0.42)) { phase = .scheduled }
        }
    }

    func saveSchedule() {
        let name = activeChild?.name ?? childName
        let savedTopic = topic ?? "No topic yet"
        schedules.removeAll { $0.childName == name }
        schedules.append(
            ScheduledCall(
                id: "sc\(Date().timeIntervalSince1970)",
                childName: name,
                when: schedule ?? timing.label,
                topic: savedTopic
            )
        )
    }

    func confirmPickedDateTime() {
        schedule = pickerSummary
        sheet = nil
    }

    func addCustomTopic() {
        let trimmed = customTopic.trimmed
        guard !trimmed.isEmpty else { return }
        topic = trimmed
        customTopic = ""
        sheet = nil
    }

    func selectChild(at index: Int) {
        guard children.indices.contains(index) else { return }
        activeChildIndex = index
        childName = children[index].name
    }
}

// MARK: - Chat actions

extension AppState {

    func openChat() {
        withAnimation(.easeOut(duration: 0.42)) { screen = .chat }
    }

    func closeChat() {
        withAnimation(.easeOut(duration: 0.42)) { screen = .home }
    }

    /// He always answers, never leaves her waiting.
    func sendChatMessage() {
        let trimmed = draft.trimmed
        guard !trimmed.isEmpty else { return }
        draft = ""
        chat.append(ChatMessage(isFromSanta: false, text: trimmed))
        chat.append(ChatMessage(
            isFromSanta: true,
            text: "Noted in the big book. I will say it out loud when I call."
        ))
    }
}

// MARK: - Vault actions

extension AppState {

    func openVault() {
        resetGate()
        withAnimation(.easeOut(duration: 0.32)) { screen = .gate }
    }

    func openScheduledCalls() {
        vaultTab = .settings
        openVault()
    }

    /// Re-locks on leave; Lock in the nav bar is the same action as Home.
    func leaveVault() {
        gatePicked = []
        gateFailed = false
        withAnimation(.easeOut(duration: 0.42)) {
            screen = .home
            phase = .idle
        }
    }

    private func resetGate() {
        gateNumbers = Self.makeGateNumbers()
        gatePicked = []
        gateFailed = false
    }

    /// Four two-digit numbers, spaced far enough apart to be unambiguous.
    private static func makeGateNumbers() -> [Int] {
        var numbers: [Int] = []
        while numbers.count < 4 {
            let candidate = Int.random(in: 11...98)
            if !numbers.contains(where: { abs($0 - candidate) < 6 }) {
                numbers.append(candidate)
            }
        }
        return numbers
    }

    /// A wrong tap reshuffles rather than locking out — no punishment, no attempt counter.
    func tapGate(_ number: Int) {
        guard !gatePicked.contains(number) else { return }
        let ascending = gateNumbers.sorted()

        guard number == ascending[gatePicked.count] else {
            withAnimation(.easeOut(duration: 0.16)) {
                gatePicked = []
                gateFailed = true
                gateNumbers = Self.makeGateNumbers()
            }
            return
        }

        withAnimation(.easeOut(duration: 0.16)) {
            gatePicked.append(number)
            gateFailed = false
        }

        if gatePicked.count == 4 {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(320))
                withAnimation(.easeOut(duration: 0.42)) { screen = .vault }
            }
        }
    }

    func toggleSummary(for recording: Recording) {
        withAnimation(.easeOut(duration: 0.2)) {
            expandedRecordingID = expandedRecordingID == recording.id ? nil : recording.id
        }
    }

    func openSafetyPage() {
        withAnimation(.easeOut(duration: 0.38)) { screen = .safety }
    }

    func leaveSafetyPage() {
        withAnimation(.easeOut(duration: 0.38)) { screen = .vault }
    }

    func addChild() {
        children.append(
            Child(name: "New child", gender: "Girl", age: 5, tint: Palette.tintNew,
                  badge: "", knowledge: 0, saysAs: "Tap to record how you say it", wishes: [])
        )
    }

    func cancelSchedule(_ schedule: ScheduledCall) {
        schedules.removeAll { $0.id == schedule.id }
    }

    func changeSchedule() {
        withAnimation(.easeOut(duration: 0.42)) {
            screen = .home
            phase = .idle
        }
    }
}

// MARK: - Player actions

extension AppState {

    func openPlayer(for recording: Recording) {
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        playbackTask?.cancel()
        playerIndex = index
        playPosition = 0
        isPlaying = false
        withAnimation(.easeOut(duration: 0.38)) { screen = .player }
    }

    func closePlayer() {
        playbackTask?.cancel()
        isPlaying = false
        withAnimation(.easeOut(duration: 0.38)) { screen = .vault }
    }

    func togglePlayback() {
        playbackTask?.cancel()
        isPlaying.toggle()
        guard isPlaying else { return }

        playbackTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let recording = currentRecording else { return }
                if playPosition >= recording.seconds {
                    playPosition = recording.seconds
                    isPlaying = false
                    return
                }
                playPosition += 1
            }
        }
    }

    func skipBackFifteen() {
        playPosition = max(0, playPosition - 15)
    }

    func seek(toFraction fraction: Double) {
        guard let seconds = currentRecording?.seconds else { return }
        playPosition = Int((min(1, max(0, fraction)) * Double(seconds)).rounded())
    }

    func deleteRecording(id: String) {
        playbackTask?.cancel()
        recordings.removeAll { $0.id == id }
        isPlaying = false
        playPosition = 0
        playerIndex = 0
        expandedRecordingID = nil
        if screen == .player {
            withAnimation(.easeOut(duration: 0.38)) { screen = .vault }
        }
    }

    func deleteCurrentRecording() {
        guard let recording = currentRecording else { return }
        deleteRecording(id: recording.id)
    }
}

// MARK: - Purchase actions

extension AppState {

    func openPaywall() {
        withAnimation(.easeOut(duration: 0.38)) { screen = isPro ? .purchased : .paywall }
    }

    func dismissPaywall() {
        withAnimation(.easeOut(duration: 0.38)) {
            screen = .home
            phase = .idle
        }
    }

    func buy() {
        isPro = true
        withAnimation(.easeOut(duration: 0.38)) { screen = .purchased }
    }

    func restorePurchase() {
        isPro = true
        withAnimation(.easeOut(duration: 0.38)) { screen = .purchased }
    }

    func returnToDashboard() {
        withAnimation(.easeOut(duration: 0.42)) {
            screen = .home
            phase = .idle
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
