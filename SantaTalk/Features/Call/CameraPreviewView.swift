import AVFoundation
import SwiftUI
import UIKit

/// The live camera, filling whatever frame it is given. Nothing but a preview
/// layer — the frames that get recorded come off the capture session directly,
/// never from this view.
struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if view.previewLayer.session !== session {
            view.previewLayer.session = session
        }
    }

    /// Backing the view with `AVCaptureVideoPreviewLayer` keeps the layer sized
    /// by UIKit rather than by a manual frame update every layout pass.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
