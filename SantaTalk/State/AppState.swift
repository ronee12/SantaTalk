import AVFoundation
import LiveKit
import SantaScheduling
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

    /// The sheets the vault raises over itself. `child(nil)` adds, `child(id)`
    /// edits — one sheet, because add and edit ask for exactly the same things.
    enum VaultSheet: Identifiable, Hashable {
        case child(UUID?)
        case language
        case lockGrace

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
    /// The notification delegate has to know whether a call is live, and it has
    /// no route to this object — so every change is mirrored where it can reach.
    var phase: CallPhase = .idle { didSet { syncCallInProgressFlag() } }
    var sheet: HomeSheet?

    // MARK: What Santa knows

    var childName: String = "Maya"
    var age: Int = 6
    var interests: [String] = ["Dinosaurs", "Drawing", "Dogs"]
    var secret: String = ""
    var microphone: PermissionState = .idle
    var camera: PermissionState = .idle
    var language: Language = Catalog.languages[0] { didSet { persistSettings() } }

    // MARK: The call the parent is setting up

    var timingSeconds: Int = 3
    /// The instant the parent picked, when they picked one rather than a
    /// countdown. A date, not a label — the label is derived from it.
    var scheduledAt: Date?
    var topic: String?
    var customTopic: String = ""
    var notifications: PermissionState = .idle
    var countdown: Int = 3
    /// Bumping this restarts the connect confetti.
    var burstToken: Int = 0

    /// The already-booked call standing in the way of the one being made.
    /// Non-nil raises the clash alert.
    var conflictingCall: ScheduledCall?
    /// A call whose moment came and went. Shown once on the dashboard, then
    /// dismissed.
    var missedCall: ScheduledCall?
    /// A call that came due while another was live. It rings the moment the
    /// current one ends, rather than interrupting it.
    @ObservationIgnored private var queuedCallID: UUID?

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
    var vaultSheet: VaultSheet?
    var expandedRecordingID: UUID?
    var isRecordingEnabled: Bool = true { didSet { persistSettings() } }
    var keepsReactionVideo: Bool = true { didSet { persistSettings() } }
    var lockGraceSeconds: Int = 120 { didSet { persistSettings() } }
    /// Which child the dashboard is set up to call.
    var activeChildID: UUID? { didSet { persistSettings() } }
    /// Raised by "Delete all recordings", so the confirmation is the system's
    /// own alert rather than something we drew.
    var isConfirmingRecordingWipe: Bool = false

    /// When the parent last left the vault. In memory only, deliberately: a cold
    /// launch has no value here, so the gate always asks again after the app has
    /// been closed however short the grace period is.
    @ObservationIgnored private var lastUnlockedAt: Date?

    // MARK: Player

    /// Which recording the player screen is on. An id rather than an index, so
    /// deleting a row cannot leave the player pointing at a different call.
    var playingRecordingID: UUID?
    @ObservationIgnored let recordingPlayer = RecordingPlayer()

    // MARK: Purchase

    var isPro: Bool = false { didSet { persistSettings() } }
    var plan: SubscriptionPlan = .year
    let pricing = Pricing()

    // MARK: Content

    var children: [ChildProfile] = []
    var recordings: [CallRecording] = []
    var schedules: [ScheduledCall] = []
    var chat: [ChatMessage] = SampleData.chat
    var draft: String = ""

    // MARK: The live call

    /// Owns the ElevenLabs session, the speaking indicator and the call timer.
    let callService = SantaCallService()

    /// Video only, and started only for the duration of a call.
    @ObservationIgnored let cameraCapture = CameraCapture()

    /// Rings while the phone rings, silenced the moment the call is answered.
    @ObservationIgnored let ringtone = RingtonePlayer()

    /// Books the notifications and runs the in-app timer for scheduled calls.
    @ObservationIgnored let scheduler = CallScheduler()

    /// Shares the camera with the preview: the preview runs whenever the camera
    /// is allowed, the recorder only when the parent has recording switched on.
    @ObservationIgnored lazy var recorder = CallRecorder(camera: cameraCapture)

    @ObservationIgnored lazy var backend: BackendClientProtocol = BackendClient(
        baseURL: BackendConfig.baseURL,
        devKey: BackendConfig.devKey
    )

    // MARK: Timers

    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var connectTask: Task<Void, Never>?
    /// Bumped at the top of every `acceptCall()`. Captured locally by the
    /// connect `Task` so its cancellation-teardown branches can tell whether
    /// they still own `callService`/`cameraCapture` — a stale task, cancelled
    /// because a second `acceptCall()` started, must not disconnect or stop
    /// the camera out from under the newer attempt.
    @ObservationIgnored private var connectGeneration = 0

    // MARK: Local storage

    /// Nil in previews and tests, where nothing should be written to disk.
    @ObservationIgnored private let store: ProfileStore?
    /// Nil in previews and tests, where nothing should be written to disk.
    @ObservationIgnored private let recordingStore: RecordingStore?
    /// Nil in previews and tests, where nothing should be written to disk.
    @ObservationIgnored private let scheduleStore: ScheduleStore?
    /// Suppresses the `didSet` writes while `hydrate()` is assigning.
    @ObservationIgnored private var isHydrating = false

    init(
        store: ProfileStore? = nil,
        recordings recordingStore: RecordingStore? = nil,
        schedules scheduleStore: ScheduleStore? = nil
    ) {
        self.store = store
        self.recordingStore = recordingStore
        self.scheduleStore = scheduleStore

        hydrate()

        // Either path to a due call lands here. Idempotent, so the notification
        // and the timer racing each other is harmless.
        scheduler.onDue = { [weak self] id in
            self?.start(scheduleID: id)
        }

        CallLaunchInbox.shared.onArrival = { [weak self] payload in
            self?.start(scheduleID: payload.scheduleID)
        }

        // Santa hanging up, or the line dying, has to move the screen on — the
        // child has no other way out of the in-call view. Either way the
        // recording so far is worth keeping.
        callService.onSessionEnded = { [weak self] ending in
            guard let self, self.phase == .inCall else { return }
            if case .failed(let error) = ending {
                Task { @MainActor in
                    self.cameraCapture.stopRunning()
                    await self.saveRecordingIfAny()
                    withAnimation(.easeOut(duration: 0.32)) { self.phase = .failed(error) }
                }
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
        recordings = recordingStore?.all() ?? []

        // The phone's own language is the opening guess, so most parents just tap
        // Continue. A stored choice below overrides it.
        if let match = Catalog.language(forLocaleIdentifier: Locale.current.identifier) {
            language = match
        }

        guard let store else { return }

        let settings = store.settings()
        isPro = settings.isPro
        isRecordingEnabled = settings.isRecordingEnabled
        keepsReactionVideo = settings.keepsReactionVideo
        lockGraceSeconds = settings.lockGraceSeconds

        children = store.children()

        guard let profile = store.profile() else { return }

        // Santa's language used to live on the child. Seed the app-wide setting
        // from the first child once, so an install made before the move keeps
        // the language the parent chose instead of falling back to the locale.
        if settings.languageID.isEmpty {
            settings.languageID = profile.languageID
            store.commit()
        }
        if let match = Catalog.languages.first(where: { $0.id == settings.languageID }) {
            language = match
        }

        // A named child that no longer exists — deleted on a previous run —
        // must not leave the dashboard pointing at nobody.
        activeChildID = settings.activeChildID.flatMap { id in
            children.contains { $0.id == id } ? id : nil
        } ?? profile.id

        loadActiveChildIntoDraft()

        // A half-finished profile restores its answers but still owes the
        // remaining steps, so onboarding resumes rather than being skipped.
        if profile.isSetupComplete { screen = .home }
    }

    /// Brings the schedule list up to date with the clock, and puts the
    /// notification centre back in step with it.
    ///
    /// Run at launch and every time the app returns to the front, because a
    /// notification fires whether or not anyone is watching — the app can come
    /// back to calls that were due two hours ago.
    func refreshSchedules() {
        guard let scheduleStore else { return }

        scheduleStore.purgeStaleMissed()
        let expired = scheduleStore.sweepExpired()
        schedules = scheduleStore.all()

        // The most recent one is the one worth mentioning. Older ones are
        // already on the list in the vault.
        if missedCall == nil, let latest = expired.max(by: { $0.fireAt < $1.fireAt }) {
            missedCall = latest
        }

        scheduler.clearFiredMarks()
        scheduler.restartTimer(for: schedules)

        let pending = schedules
        Task { @MainActor in
            notifications = await scheduler.authorizationState()
            guard notifications == .granted else { return }
            await scheduler.rearmAll(pending)
        }
    }

    /// A live call must not be interrupted by a banner for another child's
    /// booking, and the notification delegate has no route to `AppState` — so
    /// the fact is mirrored where it can reach it.
    func syncCallInProgressFlag() {
        CallLaunchInbox.shared.isCallInProgress = isCallUnderway
    }

    var isCallUnderway: Bool {
        switch phase {
        case .countdown, .ringing, .connecting, .inCall: true
        default: false
        }
    }

    /// Drains a notification tapped before the app was ready to act on it.
    func consumePendingLaunch() {
        guard let payload = CallLaunchInbox.shared.drain() else { return }
        start(scheduleID: payload.scheduleID)
    }

    /// Mirrors the active child into the loose fields onboarding and the
    /// knowledge meter read. Those two predate multiple children and are written
    /// step by step as the parent answers, so they stay the working copy and the
    /// child row stays the record.
    private func loadActiveChildIntoDraft() {
        guard let child = activeChild else { return }
        let wasHydrating = isHydrating
        isHydrating = true
        defer { isHydrating = wasHydrating }

        childName = child.name
        age = child.age
        interests = child.interests
        secret = child.secret
    }

    /// Writes the onboarding answers onto the active child. Called as the parent
    /// moves through the steps, so a force-quit halfway does not lose what they
    /// have typed.
    func persistProfile(markingComplete: Bool = false) {
        guard !isHydrating, let store else { return }

        // Onboarding runs before any child exists, so the first save creates the
        // row it is filling in.
        let profile = activeChild ?? store.profileForWriting()
        profile.name = childName
        profile.age = age
        profile.interests = interests
        profile.secret = secret
        if markingComplete { profile.isSetupComplete = true }
        profile.updatedAt = .now
        store.commit()

        children = store.children()
        if activeChildID == nil { activeChildID = profile.id }
    }

    private func persistSettings() {
        guard !isHydrating, let store else { return }

        let settings = store.settings()
        settings.isPro = isPro
        settings.isRecordingEnabled = isRecordingEnabled
        settings.keepsReactionVideo = keepsReactionVideo
        settings.languageID = language.id
        settings.activeChildID = activeChildID
        settings.lockGraceSeconds = lockGraceSeconds
        store.commit()
    }

    /// Re-reads the library after a save or a delete. The list is small enough
    /// that a refetch is simpler — and always correct — compared with patching
    /// the array in place.
    func reloadRecordings() {
        recordings = recordingStore?.all() ?? []
    }

    func recordingURL(for recording: CallRecording) -> URL? {
        recordingStore?.url(for: recording)
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
        inVault ? (activeChild?.knowledgePercent ?? knowledgePercent) : knowledgePercent
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

    var activeChild: ChildProfile? {
        guard let activeChildID else { return children.first }
        return children.first { $0.id == activeChildID } ?? children.first
    }

    var timing: CallTiming {
        Catalog.timings.first { $0.seconds == timingSeconds } ?? Catalog.timings[0]
    }

    /// What the When row reads.
    var whenValue: String {
        guard let scheduledAt else { return timing.label }
        return ScheduleFormat.label(for: scheduledAt)
    }

    var topicValue: String { topic ?? "Pick a topic" }

    /// A schedule or anything a minute out is booked rather than dialled.
    var isScheduling: Bool { scheduledAt != nil || timingSeconds >= 60 }

    /// The instant this call would ring, whichever way it was chosen.
    var plannedFireDate: Date {
        scheduledAt ?? Date.now.addingTimeInterval(Double(timingSeconds))
    }

    /// The presets still ahead of us. One whose time has passed is dropped
    /// rather than shown greyed out — a booking that would be born missed is not
    /// a choice worth offering.
    var availablePresets: [PresetSchedule] {
        let now = Date.now
        return Catalog.presetSchedules.filter { !ScheduleClock.hasPassed($0, now: now) }
    }

    /// The label mirrors the setting, so the red button says exactly what it will do.
    var callToActionLabel: String {
        if scheduledAt != nil { return "Schedule the call" }
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

    var notificationWhen: String {
        guard let scheduledAt else { return timing.label.lowercased() }
        return ScheduleFormat.label(for: scheduledAt)
    }

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

    /// The instant the four picker columns currently describe.
    var pickedDate: Date? {
        ScheduleClock.date(
            dayOffset: pickerDay,
            hour12: pickerHour,
            minute: pickerMinute,
            isPM: pickerMeridiem == "PM",
            now: .now
        )
    }

    var pickerSummary: String {
        let days = Format.dayLabels()
        let day = days.indices.contains(pickerDay) ? days[pickerDay] : days[0]
        return "\(day), \(pickerHour):\(String(format: "%02d", pickerMinute)) \(pickerMeridiem)"
    }

    /// A time already behind us cannot be booked. The picker's Today column makes
    /// that a single tap away, so the button says why rather than going dead.
    var isPickedDateBookable: Bool {
        guard let pickedDate else { return false }
        return pickedDate > Date.now
    }

    var pickerConfirmLabel: String {
        isPickedDateBookable ? "Santa calls" : "That time has passed"
    }

    /// What the parent asked for on the dashboard. Stored as the same preference
    /// the vault's "Keep the reaction video" row writes, so the two rows are one
    /// setting seen from two places rather than two that can disagree.
    var wantsVideoCall: Bool { keepsReactionVideo }

    /// Whether this call actually has video — decided before it starts and fixed
    /// for its duration. A call is wholly audio or wholly video; there is no
    /// mid-call toggle for a child to find.
    ///
    /// Asking for video the camera was never allowed to provide gives an audio
    /// call, not a broken one.
    var isVideoCall: Bool {
        wantsVideoCall && camera == .granted
    }

    /// Says what the call will be, and — when the answer differs from what was
    /// asked for — why.
    var callModeDetail: String {
        guard wantsVideoCall else { return "Just Santa's voice. Nothing is filmed." }
        switch camera {
        case .granted: return "\(childName)'s face is saved with the call, on this phone"
        case .denied: return "Camera access is off in Settings, so this call will be audio"
        default: return "We'll ask for the camera when the call starts"
        }
    }

    var showsCameraPreview: Bool {
        isVideoCall && cameraCapture.isRunning
    }

    var cameraSession: AVCaptureSession? {
        showsCameraPreview ? cameraCapture.session : nil
    }
}

// MARK: - Derived vault state

extension AppState {

    /// `2 CALLS WITH MAYA · 4:24 TOTAL`
    var recordingCountLabel: String {
        let noun = recordings.count == 1 ? " CALL WITH " : " CALLS WITH "
        let total = Format.duration(recordings.reduce(0) { $0 + $1.durationSeconds })
        return "\(recordings.count)\(noun)\(childName.uppercased()) · \(total) TOTAL"
    }

    var currentRecording: CallRecording? {
        recordings.first { $0.id == playingRecordingID }
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
        guard isScheduling else {
            startCountdown()
            return
        }

        // Checked before anything is written or any permission is asked for. A
        // parent who is about to be told "Ben already has a call then" should not
        // first have to answer a notifications prompt.
        if let clash = ScheduleConflict.first(
            against: plannedFireDate,
            among: schedules.filter(\.isPending).map(\.slot)
        ), let call = scheduleStore?.call(id: clash.id) {
            conflictingCall = call
            return
        }

        if notifications == .idle {
            sheet = .notification
            return
        }

        commitSchedule()
    }

    // MARK: The clash alert

    /// Replace: the call in the way is cancelled, and the new one takes its slot.
    func replaceConflictingCall() {
        guard let conflictingCall else { return }
        cancelSchedule(conflictingCall)
        self.conflictingCall = nil

        if notifications == .idle {
            sheet = .notification
            return
        }
        commitSchedule()
    }

    /// Pick another time: back to the When sheet with the booking intact.
    func rescheduleAfterConflict() {
        conflictingCall = nil
        sheet = .when
    }

    func dismissConflict() {
        conflictingCall = nil
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
        phase = .idle
        guard !startQueuedCallIfAny() else { return }
        withAnimation(.easeOut(duration: 0.32)) { phase = .idle }
    }

    /// Not now. A call waiting behind this one still gets its turn — the parent
    /// declined Maya's call, not Ben's.
    func declineCall() {
        ringtone.stop()
        phase = .idle
        guard !startQueuedCallIfAny() else { return }
        withAnimation(.easeOut(duration: 0.32)) { phase = .idle }
    }

    /// Fetches a token, opens the session, and only then shows the in-call
    /// screen. The connecting screen covers the wait, so the tap has an
    /// immediate answer even though the line takes a moment to open.
    ///
    /// One burst on connect, then stillness — and the burst fires on a real
    /// connection, never optimistically.
    func acceptCall() {
        // Before anything else. LiveKit reconfigures the audio session on its way
        // up, and a ringtone still holding `.playback` would either play over
        // Santa's first words or leave the session in a category that cannot
        // record. Relying on the ringing screen's `onDisappear` alone races that.
        ringtone.stop()

        connectTask?.cancel()
        connectGeneration += 1
        let generation = connectGeneration
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
                // interrupted mid-flight, so the session is closed on arrival —
                // unless a newer `acceptCall()` has since taken over, in which
                // case this stale attempt does not own the session anymore and
                // must leave it alone.
                guard !Task.isCancelled else {
                    if generation == connectGeneration {
                        await callService.disconnect()
                    }
                    return
                }

                guard callService.phase == .active else {
                    withAnimation(.easeOut(duration: 0.32)) { phase = .failed(.dropped) }
                    return
                }

                if isVideoCall {
                    _ = await cameraCapture.startRunning()
                }

                // Cancelled (Cancel tapped on the connecting screen) while the
                // camera was starting up — `startRunning()` awaits, and a
                // cancelled `Task` does not interrupt that await, so this has
                // to be re-checked rather than assumed still true. Same
                // staleness guard as above: a newer attempt may already own
                // the camera and session by the time this fires.
                guard !Task.isCancelled else {
                    if generation == connectGeneration {
                        cameraCapture.stopRunning()
                        await callService.disconnect()
                    }
                    return
                }

                // The LiveKit session can also drop during that same await —
                // not a cancellation, a real disconnect. `phase` is still
                // `.connecting` here, so `onSessionEnded`'s guard on
                // `.inCall` never sees it. Re-check the same way the earlier
                // `guard callService.phase == .active` does, so the drop is
                // not swallowed and the child is told the call failed rather
                // than being carried into `.inCall` on a dead session.
                guard callService.phase == .active else {
                    cameraCapture.stopRunning()
                    await callService.disconnect()
                    withAnimation(.easeOut(duration: 0.32)) { phase = .failed(.dropped) }
                    return
                }

                // Last, once every way of not reaching the call has been ruled
                // out. Starting the recorder before these guards would leave it
                // running against a call that was cancelled or dropped while the
                // camera was coming up, with nothing left to stop it.
                beginRecording()

                burstToken += 1
                withAnimation(.easeOut(duration: 0.32)) { phase = .inCall }
            } catch is CancellationError {
                if generation == connectGeneration {
                    await callService.disconnect()
                }
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
        Task { @MainActor in
            cameraCapture.stopRunning()
            recorder.cancel()
            callService.onAgentTrackReady = nil
            await callService.disconnect()
        }
        phase = .idle
        guard !startQueuedCallIfAny() else { return }
        withAnimation(.easeOut(duration: 0.32)) { phase = .idle }
    }

    /// Starts the recorder and attaches both sides of the conversation.
    ///
    /// Santa's track subscribes after the session goes live, so it arrives by
    /// callback rather than being read here.
    private func beginRecording() {
        guard isRecordingEnabled else { return }

        recorder.start(keepVideo: keepsReactionVideo)
        guard recorder.isRecording else { return }

        if let track = callService.localAudioTrack {
            recorder.attach(child: track)
        }

        // Santa's track may already be here. The poll that watches for it starts
        // when the session opens, which is a camera-startup earlier than this —
        // so by now it has often already fired, found the track, and returned.
        // Asking directly first is what stops that ordering from producing a
        // recording of the child talking to nobody.
        if let track = callService.agentAudioTrack {
            recorder.attach(santa: track)
        } else {
            callService.onAgentTrackReady = { [weak self] track in
                self?.recorder.attach(santa: track)
            }
        }
    }

    /// Closes the recording and files it. Called on every path out of a live
    /// call, including the ones the child did not choose.
    private func saveRecordingIfAny() async {
        callService.onAgentTrackReady = nil
        guard let file = await recorder.finish(), let recordingStore else { return }

        let saved = recordingStore.save(
            movingFrom: file.url,
            childName: childName,
            title: topic ?? "A call with Santa",
            startedAt: Date().addingTimeInterval(-Double(file.durationSeconds)),
            durationSeconds: file.durationSeconds,
            hasVideo: file.hasVideo
        )
        if saved != nil { reloadRecordings() }
    }

    /// The paywall opens seconds after the call ends — never before the first call.
    ///
    /// Unless another child's call came due while this one was live, in which
    /// case the phone rings for them instead. A booking the parent made is worth
    /// more than a price they did not ask to see.
    func endCall() {
        Task { @MainActor in
            cameraCapture.stopRunning()
            await saveRecordingIfAny()
            await callService.disconnect()

            phase = .idle
            guard !startQueuedCallIfAny() else { return }

            withAnimation(.easeOut(duration: 0.38)) {
                screen = isPro ? .home : .paywall
            }
        }
    }

    /// Our explainer has stated the case; hand over to the real system prompt.
    func allowNotifications() {
        sheet = nil
        Task { @MainActor in
            let granted = await scheduler.requestAuthorization()
            notifications = granted ? .granted : .denied
            commitSchedule()
        }
    }

    /// Declining does not cost the parent their booking. The call is still saved
    /// and the in-app timer still runs — it just needs the app open, which is
    /// what `callToActionHint` has always said in this case.
    func skipNotifications() {
        notifications = .denied
        sheet = nil
        commitSchedule()
    }

    /// Writes the booking, books its notifications, and shows the receipt.
    private func commitSchedule() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(240))
            await saveSchedule()
            withAnimation(.easeOut(duration: 0.42)) { phase = .scheduled }
        }
    }

    @discardableResult
    func saveSchedule() async -> ScheduledCall? {
        guard let scheduleStore, let child = activeChild else { return nil }

        let call = scheduleStore.add(
            childID: child.id,
            childName: child.name,
            fireAt: plannedFireDate,
            topic: topic ?? "",
            wantsVideo: wantsVideoCall,
            languageID: language.id
        )

        schedules = scheduleStore.all()
        scheduler.restartTimer(for: schedules)
        if notifications == .granted {
            await scheduler.arm(call)
        }
        return call
    }

    func confirmPickedDateTime() {
        guard isPickedDateBookable, let pickedDate else { return }
        scheduledAt = pickedDate
        timingSeconds = 3
        sheet = nil
    }

    /// Choosing a preset resolves it to an instant there and then, so the
    /// booking cannot drift if the parent leaves the sheet open.
    func selectPreset(_ preset: PresetSchedule) {
        guard let date = ScheduleClock.date(for: preset, now: .now) else { return }
        scheduledAt = date
        sheet = nil
    }

    func selectTiming(_ timing: CallTiming) {
        timingSeconds = timing.seconds
        scheduledAt = nil
        sheet = nil
    }

    func addCustomTopic() {
        let trimmed = customTopic.trimmed
        guard !trimmed.isEmpty else { return }
        topic = trimmed
        customTopic = ""
        sheet = nil
    }

    /// Switches which child the dashboard is set up to call, and brings that
    /// child's answers with it so the topic sheet and the meter follow.
    func selectChild(id: UUID) {
        guard children.contains(where: { $0.id == id }) else { return }
        activeChildID = id
        loadActiveChildIntoDraft()
    }

    /// Switching the dashboard to a video call asks for the camera there and
    /// then, if it has never been asked for — so the answer is known before the
    /// phone rings, rather than a system alert landing in front of the child
    /// mid-call.
    func toggleCallMode() {
        keepsReactionVideo.toggle()
        guard keepsReactionVideo, camera == .idle else { return }

        camera = .asking
        Task { @MainActor in
            camera = await CameraCapture.requestAccess() ? .granted : .denied
        }
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

    /// A parent who has just been through the gate is not asked again inside the
    /// grace period they chose — stepping out to the dashboard and back should
    /// not cost four taps.
    private var isWithinLockGrace: Bool {
        guard lockGraceSeconds > 0, let lastUnlockedAt else { return false }
        return Date.now.timeIntervalSince(lastUnlockedAt) < Double(lockGraceSeconds)
    }

    func openVault() {
        guard !isWithinLockGrace else {
            withAnimation(.easeOut(duration: 0.32)) { screen = .vault }
            return
        }
        resetGate()
        withAnimation(.easeOut(duration: 0.32)) { screen = .gate }
    }

    func openScheduledCalls() {
        vaultTab = .settings
        openVault()
    }

    /// Re-locks on leave; Lock in the nav bar is the same action as Home.
    ///
    /// The leave is what starts the grace clock, not the unlock — otherwise a
    /// long session in the vault would burn the whole window before the parent
    /// had even left.
    func leaveVault() {
        gatePicked = []
        gateFailed = false
        vaultSheet = nil
        lastUnlockedAt = .now
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

    func toggleSummary(for recording: CallRecording) {
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

    // MARK: Children

    func openChildEditor(for child: ChildProfile?) {
        vaultSheet = .child(child?.id)
    }

    func child(withID id: UUID) -> ChildProfile? {
        children.first { $0.id == id }
    }

    /// The last child cannot be removed. Santa has to have someone to call, and
    /// an empty dashboard offers no way back except starting over.
    var canDeleteChildren: Bool { children.count > 1 }

    /// Saves the editor sheet. A nil id adds, an id edits.
    func saveChild(id: UUID?, name: String, age: Int, interests: [String], secret: String) {
        guard let store else { return }
        let trimmedName = name.trimmed
        guard !trimmedName.isEmpty else { return }

        if let id, let existing = child(withID: id) {
            existing.name = trimmedName
            existing.age = age
            existing.interests = interests
            existing.secret = secret
            existing.updatedAt = .now
            store.commit()
        } else {
            let created = store.add(
                name: trimmedName,
                age: age,
                interests: interests,
                secret: secret
            )
            activeChildID = created.id
        }

        children = store.children()
        loadActiveChildIntoDraft()
        vaultSheet = nil
    }

    /// Removes a child and everything the dashboard held about them.
    ///
    /// Their recordings stay. They are keepsakes of calls that did happen, and
    /// "Delete all recordings" is the deliberate way to clear those — losing an
    /// album as a side effect of tidying a list is not a trade a parent asked
    /// for.
    func deleteChild(_ child: ChildProfile) {
        guard let store, canDeleteChildren else { return }

        let wasActive = child.id == activeChildID

        // Their booked calls go with them, or the vault lists a call for a child
        // the app no longer knows.
        schedules.removeAll { $0.childName == child.name }

        store.delete(child)
        children = store.children()

        if wasActive {
            activeChildID = children.first?.id
            loadActiveChildIntoDraft()
        }
        vaultSheet = nil
    }

    // MARK: Language

    func selectLanguage(_ language: Language) {
        self.language = language
        vaultSheet = nil
    }

    // MARK: Lock

    var lockGraceLabel: String { LockGrace.label(forSeconds: lockGraceSeconds) }

    func selectLockGrace(_ grace: LockGrace) {
        lockGraceSeconds = grace.seconds
        vaultSheet = nil
    }

    // MARK: Recordings

    /// Wipes the library after the system alert is confirmed.
    ///
    /// `deleteAll` reports how many files refused to go; their rows are still
    /// there afterwards, so simply reloading shows the parent exactly what
    /// survived rather than claiming a clean sweep that did not happen.
    func deleteAllRecordings() {
        isConfirmingRecordingWipe = false
        guard let recordingStore else { return }

        if screen == .player { closePlayer() }
        recordingPlayer.stop()
        _ = recordingStore.deleteAll()

        expandedRecordingID = nil
        playingRecordingID = nil
        reloadRecordings()
    }

    func cancelSchedule(_ schedule: ScheduledCall) {
        guard let scheduleStore else { return }

        scheduler.disarm(callID: schedule.id)
        if queuedCallID == schedule.id { queuedCallID = nil }
        if missedCall?.id == schedule.id { missedCall = nil }

        scheduleStore.delete(schedule)
        schedules = scheduleStore.all()
        scheduler.restartTimer(for: schedules)
    }

    /// The vault list: still-owed calls first, then the ones nobody answered.
    var vaultSchedules: [ScheduledCall] {
        schedules.sorted { first, second in
            first.isPending == second.isPending
                ? first.fireAt < second.fireAt
                : first.isPending
        }
    }

    /// Change: the booking is loaded back onto the dashboard and removed, so
    /// saving again is a fresh booking rather than a second one.
    func changeSchedule(_ schedule: ScheduledCall) {
        // A missed call's time is behind us. Carrying it onto the dashboard
        // would put a past instant in the When row and fail the moment the
        // parent tried to book it, so rebooking starts from the countdown
        // default and they pick a new time.
        if schedule.fireAt > .now {
            scheduledAt = schedule.fireAt
        } else {
            scheduledAt = nil
            timingSeconds = 3
        }
        topic = schedule.topic.isEmpty ? nil : schedule.topic
        if let child = children.first(where: { $0.id == schedule.childID }) {
            selectChild(id: child.id)
        }
        cancelSchedule(schedule)

        withAnimation(.easeOut(duration: 0.42)) {
            screen = .home
            phase = .idle
        }
    }

    /// The call the receipt screen is describing — the most recently booked one.
    var justBookedCall: ScheduledCall? {
        schedules.filter(\.isPending).max { $0.createdAt < $1.createdAt }
    }

    /// Reads off the saved booking rather than the dashboard, so the receipt
    /// shows what was actually written.
    var confirmedWhenLabel: String {
        justBookedCall?.whenLabel ?? whenValue
    }

    var scheduleReminderLine: String {
        notifications == .granted
            ? "We will remind you five minutes before, so the phone is in the right hands."
            : "Notifications are off, so keep the app open — that is the only way the phone can ring."
    }

    /// "Change it" on the receipt screen. The booking is undone and loaded back
    /// onto the dashboard, rather than left behind as a second call.
    func changeJustBookedCall() {
        guard let call = justBookedCall else {
            withAnimation(.easeOut(duration: 0.32)) { phase = .idle }
            return
        }
        changeSchedule(call)
    }

    func dismissMissedCall() {
        missedCall = nil
    }

    /// Rebook a call nobody answered, with everything it was booked with.
    func retryMissedCall() {
        guard let missedCall else { return }
        scheduledAt = nil
        timingSeconds = 3
        topic = missedCall.topic.isEmpty ? nil : missedCall.topic
        if let child = children.first(where: { $0.id == missedCall.childID }) {
            selectChild(id: child.id)
        }
        cancelSchedule(missedCall)
        self.missedCall = nil
    }
}

// MARK: - Starting a scheduled call

extension AppState {

    /// The single way a booked call becomes a ringing phone.
    ///
    /// Idempotent: the notification and the foreground timer both lead here, and
    /// so does a tap on a link, so this may be called several times for one
    /// call. Everything past the first is a no-op.
    func start(scheduleID: UUID) {
        guard let scheduleStore, let call = scheduleStore.call(id: scheduleID), call.isPending else {
            return
        }

        // A live call is never interrupted — not by a banner, not by an alert,
        // not by being replaced. The arriving call waits its turn and rings the
        // moment this one is over.
        guard !isCallUnderway else {
            queuedCallID = scheduleID
            return
        }

        switch ScheduleWindow.standing(fireAt: call.fireAt, now: .now) {
        case .waiting:
            // Arrived early — a link tapped before its time. Leave it booked.
            return

        case .missed:
            scheduleStore.markMissed(call)
            schedules = scheduleStore.all()
            missedCall = call
            withAnimation(.easeOut(duration: 0.38)) {
                screen = .home
                phase = .idle
            }

        case .due:
            ring(call)
        }
    }

    /// Sets the dashboard up exactly as the call was booked, then rings.
    ///
    /// The booking's own topic, language and video choice are used rather than
    /// whatever the dashboard happens to be showing — otherwise Ben's audio call
    /// would inherit Maya's video toggle.
    private func ring(_ call: ScheduledCall) {
        if let child = children.first(where: { $0.id == call.childID }) {
            selectChild(id: child.id)
        }
        topic = call.topic.isEmpty ? nil : call.topic
        if let match = Catalog.languages.first(where: { $0.id == call.languageID }) {
            language = match
        }
        keepsReactionVideo = call.wantsVideo

        // The row has done its job. Deleting rather than marking keeps the vault
        // list to calls still owed, and the recording becomes the record.
        scheduler.disarm(callID: call.id)
        scheduleStore?.delete(call)
        schedules = scheduleStore?.all() ?? []
        scheduler.restartTimer(for: schedules)

        missedCall = nil
        sheet = nil
        withAnimation(.easeOut(duration: 0.38)) {
            screen = .home
            phase = .ringing
        }
    }

    /// Hands the phone to whichever call was waiting, if it is still worth
    /// ringing. Returns whether it took over.
    private func startQueuedCallIfAny() -> Bool {
        guard let id = queuedCallID else { return false }
        queuedCallID = nil

        guard let scheduleStore, let call = scheduleStore.call(id: id), call.isPending else {
            return false
        }

        switch ScheduleWindow.standing(fireAt: call.fireAt, now: .now) {
        case .due:
            ring(call)
            return true
        case .missed:
            scheduleStore.markMissed(call)
            schedules = scheduleStore.all()
            missedCall = call
            return false
        case .waiting:
            return false
        }
    }
}

// MARK: - Player actions

extension AppState {

    /// The view reads these rather than the player directly, so the player
    /// screen's markup is unchanged from the prototype.
    var isPlaying: Bool { recordingPlayer.isPlaying }
    var playPosition: Int { Int(recordingPlayer.position) }

    var playbackFraction: Double {
        guard recordingPlayer.duration > 0 else { return 0 }
        return min(1, recordingPlayer.position / recordingPlayer.duration)
    }

    var playbackRemaining: String {
        let total = currentRecording?.durationSeconds ?? 0
        return "-" + Format.duration(max(0, total - playPosition))
    }

    func openPlayer(for recording: CallRecording) {
        playingRecordingID = recording.id
        if let url = recordingURL(for: recording) {
            recordingPlayer.load(url: url, duration: recording.durationSeconds)
        }
        withAnimation(.easeOut(duration: 0.38)) { screen = .player }
    }

    func closePlayer() {
        recordingPlayer.stop()
        playingRecordingID = nil
        withAnimation(.easeOut(duration: 0.38)) { screen = .vault }
    }

    func togglePlayback() { recordingPlayer.togglePlayback() }

    func skipBackFifteen() { recordingPlayer.skipBackFifteen() }

    func seek(toFraction fraction: Double) { recordingPlayer.seek(toFraction: fraction) }

    func deleteRecording(_ recording: CallRecording) {
        let isOpen = playingRecordingID == recording.id

        do {
            try recordingStore?.delete(recording)
        } catch {
            // `RecordingStore.delete` only throws when the file itself failed to
            // remove (permissions, disk error, ...); the row is deliberately left
            // in place so the megabytes on disk are not silently orphaned. There
            // is no error surface on this screen yet, so the only honest thing to
            // do here is nothing visible: leave the list, the expanded row and the
            // player exactly as they were, so the recording stays visible and the
            // parent can try the delete again rather than watching it vanish from
            // the UI while the bytes remain on disk.
            return
        }

        if isOpen { recordingPlayer.stop() }

        reloadRecordings()
        expandedRecordingID = nil
        if playingRecordingID == recording.id {
            playingRecordingID = nil
        }
        if screen == .player {
            withAnimation(.easeOut(duration: 0.38)) { screen = .vault }
        }
    }

    func deleteCurrentRecording() {
        guard let recording = currentRecording else { return }
        deleteRecording(recording)
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
