import Foundation
import AVFoundation
import Photos
import Combine

/// Captura nativa mediante AVCaptureMovieFileOutput, sin canvas, MediaRecorder ni WebKit.
/// En esta primera fase guarda la cámara y la voz originales. La música se añadirá
/// después de verificar 90 segundos de imagen continua en un iPhone real.
final class CameraEngine: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.tellestory.camera.session", qos: .userInitiated)
    private let movieOutput = AVCaptureMovieFileOutput()
    private var currentVideoInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var useFrontCamera = true
    private var timer: Timer?

    @Published private(set) var cameraReady = false
    @Published private(set) var recording = false
    @Published private(set) var busy = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var lastRecording: URL?
    @Published var message = "Activa la cámara para empezar."
    @Published var errorMessage: String?

    func start() {
        Task { @MainActor in
            let cameraAllowed = await request(.video)
            let micAllowed = await request(.audio)
            guard cameraAllowed && micAllowed else {
                message = "Permite cámara y micrófono desde Ajustes de iPhone → TelleStory."
                errorMessage = "Faltan permisos de cámara o micrófono."
                return
            }
            sessionQueue.async { [weak self] in
                self?.configureAndRun()
            }
        }
    }

    @MainActor
    private func request(_ type: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: type)
        default: return false
        }
    }

    private func configureAndRun() {
        if !isConfigured {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoRecording,
                                                               options: [.defaultToSpeaker])
                try AVAudioSession.sharedInstance().setActive(true)
                session.beginConfiguration()
                session.sessionPreset = .hd1280x720 // 720 × 1280 al grabar en vertical

                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                            for: .video, position: .front) else {
                    throw CameraError.noCamera
                }
                let videoInput = try AVCaptureDeviceInput(device: camera)
                guard session.canAddInput(videoInput) else { throw CameraError.configuration }
                session.addInput(videoInput)
                currentVideoInput = videoInput

                guard let microphone = AVCaptureDevice.default(for: .audio) else {
                    throw CameraError.noMicrophone
                }
                let microphoneInput = try AVCaptureDeviceInput(device: microphone)
                guard session.canAddInput(microphoneInput) else { throw CameraError.configuration }
                session.addInput(microphoneInput)

                guard session.canAddOutput(movieOutput) else { throw CameraError.configuration }
                session.addOutput(movieOutput)
                movieOutput.movieFragmentInterval = CMTime(seconds: 5, preferredTimescale: 600)
                applyPortraitOrientation()
                session.commitConfiguration()
                isConfigured = true
            } catch {
                if session.isRunning == false && !isConfigured {
                    // Solo hay beginConfiguration sin commit si se lanzó una excepción.
                    session.commitConfiguration()
                }
                onMain { [weak self] in
                    self?.errorMessage = "No se pudo iniciar la cámara: \(error.localizedDescription)"
                    self?.message = "Error al configurar la cámara."
                }
                return
            }
        }
        if !session.isRunning { session.startRunning() }
        onMain { [weak self] in
            self?.cameraReady = true
            self?.errorMessage = nil
            self?.message = "Cámara lista. Video original 9:16 con voz."
        }
    }

    private func applyPortraitOrientation() {
        // En AVCaptureMovieFileOutput, el giro se aplica en los metadatos del archivo
        // y evita procesar cada fotograma mediante canvas.
        if let movieConnection = movieOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if movieConnection.isVideoRotationAngleSupported(90) {
                    movieConnection.videoRotationAngle = 90
                }
            } else if movieConnection.isVideoOrientationSupported {
                movieConnection.videoOrientation = .portrait
            }
            if movieConnection.isVideoMirroringSupported {
                movieConnection.automaticallyAdjustsVideoMirroring = false
                movieConnection.isVideoMirrored = useFrontCamera
            }
        }
    }

    func toggleCamera() {
        guard !recording && !busy else { return }
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured else { return }
            let desiredPosition: AVCaptureDevice.Position = self.useFrontCamera ? .back : .front
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                           for: .video, position: desiredPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newCamera),
                  let oldInput = self.currentVideoInput else { return }
            self.session.beginConfiguration()
            self.session.removeInput(oldInput)
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentVideoInput = newInput
                self.useFrontCamera.toggle()
            } else {
                self.session.addInput(oldInput)
            }
            self.session.commitConfiguration()
            self.applyPortraitOrientation()
        }
    }

    func record() {
        guard cameraReady && !recording && !busy else { return }
        onMain { [weak self] in
            self?.busy = true
            self?.elapsed = 0
            self?.lastRecording = nil
            self?.message = "Iniciando grabación…"
        }
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning, !self.movieOutput.isRecording else {
                self?.onMain { [weak self] in
                    self?.busy = false
                    self?.message = "La cámara no está lista."
                }
                return
            }
            self.applyPortraitOrientation()
            let fileName = "TelleStory-\(UUID().uuidString).mov"
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            self.movieOutput.startRecording(to: destination, recordingDelegate: self)
        }
    }

    func stopRecording() {
        guard recording || busy else { return }
        sessionQueue.async { [weak self] in
            guard let self, self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
        }
        onMain { [weak self] in self?.message = "Finalizando video original…" }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        onMain { [weak self] in
            guard let self else { return }
            self.busy = false
            self.recording = true
            self.elapsed = 0
            self.message = "Grabando video original…"
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.elapsed = max(0, CMTimeGetSeconds(self.movieOutput.recordedDuration))
            }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        onMain { [weak self] in
            guard let self else { return }
            self.timer?.invalidate()
            self.timer = nil
            self.recording = false
            self.busy = false
            let bytes = (try? FileManager.default.attributesOfItem(atPath: outputFileURL.path))
                .flatMap { ($0[.size] as? NSNumber)?.int64Value } ?? 0
            if let error {
                self.errorMessage = "La cámara informó un fallo: \(error.localizedDescription)"
                self.message = "La grabación terminó con un error."
            } else if bytes < 25_000 {
                self.errorMessage = "El archivo está vacío o incompleto. Prueba otra toma."
                self.message = "Grabación incompleta."
            } else {
                self.lastRecording = outputFileURL
                self.errorMessage = nil
                self.message = "Video completo. Revísalo y guárdalo en Fotos."
            }
        }
    }

    func saveToPhotos() {
        guard let file = lastRecording else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] authorization in
            guard authorization == .authorized || authorization == .limited else {
                self?.onMain { [weak self] in self?.message = "Permite guardar en Fotos desde Ajustes." }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: file)
            }, completionHandler: { success, error in
                self?.onMain { [weak self] in
                    self?.message = success ? "¡Video guardado en Fotos!" :
                        "No se pudo guardar: \(error?.localizedDescription ?? "Error desconocido")"
                }
            })
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.movieOutput.isRecording && self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }

    private enum CameraError: LocalizedError {
        case noCamera, noMicrophone, configuration
        var errorDescription: String? {
            switch self {
            case .noCamera: return "No se encontró cámara."
            case .noMicrophone: return "No se encontró micrófono."
            case .configuration: return "No se pudo configurar audio y video."
            }
        }
    }
}
