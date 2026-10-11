import SwiftUI
import AVFoundation

final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.backgroundColor = .black
        view.videoLayer.videoGravity = .resizeAspectFill
        view.videoLayer.session = session
        return view
    }

    func updateUIView(_ view: CameraPreviewView, context: Context) {
        if view.videoLayer.session !== session { view.videoLayer.session = session }
    }
}
