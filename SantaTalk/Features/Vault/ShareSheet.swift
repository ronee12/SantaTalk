import SwiftUI
import UIKit

/// The system share sheet, presented once a video exists.
///
/// `ShareLink` would be simpler, but it needs its item before the button is
/// tapped and this one is not made until the export finishes.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
