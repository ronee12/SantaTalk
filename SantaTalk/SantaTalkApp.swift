//
//  SantaTalkApp.swift
//  SantaTalk
//
//  Created by Mehedi Hasan Ronee on 29/7/26.
//

import SwiftData
import SwiftUI

@main
struct SantaTalkApp: App {

    /// Three models, all local, all gone when the app is deleted. Nothing here
    /// syncs to iCloud and nothing here is uploaded.
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: ChildProfile.self, AppSettings.self, CallRecording.self
            )
        } catch {
            // An unopenable store is not something a parent can act on, and it is
            // not worth a crash on the day of the call. Fall back to memory: the
            // app still works, the profile just will not survive this launch.
            container = try! ModelContainer(
                for: ChildProfile.self, AppSettings.self, CallRecording.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                profiles: ProfileStore(context: container.mainContext),
                recordings: RecordingStore(context: container.mainContext)
            )
        }
        .modelContainer(container)
    }
}
