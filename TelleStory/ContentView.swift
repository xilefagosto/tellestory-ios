import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var camera = CameraEngine()
    @AppStorage("tellestory.script") private var script = "Tu historia merece ser contada.\n\nHabla con confianza.\n\nTu historia. Tu voz."
    @AppStorage("tellestory.speed") private var speed: Double = 40
    @AppStorage("tellestory.font") private var fontSize: Double = 25
    @State private var showEditor = false
    @State private var promptPlaying = false
    @State private var showPreview = false
    @State private var section: Int = 1

    private let gold = Color(red: 0.84, green: 0.66, blue: 0.38)
    private let background = Color(red: 0.045, green: 0.045, blue: 0.056)

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image("TelleStoryLogo")
                    .resizable().scaledToFill()
                    .frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    (Text("Telle").foregroundColor(.white) + Text("Story").foregroundColor(gold))
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                    Text("TU HISTORIA. TU VOZ.")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .tracking(2).foregroundStyle(.gray)
                }
                Spacer()
                Text("NATIVO 0.1").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(gold).padding(8)
                    .background(gold.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, 16)
            Picker("Sección", selection: $section) {
                Text("Guion").tag(0)
                Text("Grabar").tag(1)
                Text("Resultado").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            Group {
                if section == 0 { scriptEditor }
                else if section == 1 { recordingView }
                else { resultsView }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 10)
        .background(background.ignoresSafeArea())
        .tint(gold)
        .onAppear { camera.start() }
        .sheet(isPresented: $showEditor) { scriptSheet }
        .sheet(isPresented: $showPreview) {
            if let url = camera.lastRecording {
                NavigationStack {
                    VideoPlayer(player: AVPlayer(url: url))
                        .background(.black)
                        .navigationTitle("Revisar video")
                        .toolbar { ToolbarItem(placement: .confirmationAction) {
                            Button("Cerrar") { showPreview = false }
                        } }
                }
            }
        }
    }

    private var scriptEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tu guion").font(.title2.bold())
                TextEditor(text: $script)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .frame(height: 290)
                promptSettings
                Button("Ir a grabar") { section = 1 }
                    .buttonStyle(GoldButtonStyle())
            }.padding(18)
        }
    }

    private var promptSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Velocidad de lectura").foregroundStyle(.white)
                Spacer()
                Text("\(Int(speed))").foregroundStyle(gold)
            }
            Slider(value: $speed, in: 10...100, step: 5)
            HStack {
                Text("Tamaño de letra").foregroundStyle(.white)
                Spacer()
                Text("\(Int(fontSize))").foregroundStyle(gold)
            }
            Slider(value: $fontSize, in: 17...40, step: 1)
        }
    }

    private var scriptSheet: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $script)
                    .padding(12)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                promptSettings.padding(.horizontal)
            }
            .padding(14)
            .navigationTitle("Guion")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Listo") { showEditor = false }
            } }
        }
        .preferredColorScheme(.dark)
    }

    private var recordingView: some View {
        VStack(spacing: 11) {
            ZStack(alignment: .top) {
                CameraPreview(session: camera.session)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(9.0/16.0, contentMode: .fit)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                if !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    TeleprompterOverlay(script: script, speed: speed, fontSize: fontSize,
                                       isPlaying: $promptPlaying)
                        .frame(height: 230)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 8)
                        .padding(.top, 15)
                }
                VStack {
                    Spacer()
                    HStack {
                        Label("9:16 · Original", systemImage: "iphone")
                        Spacer()
                        Text(timeString(camera.elapsed))
                            .monospacedDigit()
                    }
                    .font(.caption.weight(.semibold))
                    .padding(11)
                    .background(.black.opacity(0.72), in: Capsule())
                    .padding(10)
                }
            }
            .frame(maxWidth: 300)
            .frame(maxHeight: .infinity)
            .layoutPriority(1)

            HStack(spacing: 12) {
                Button { showEditor = true } label: {
                    Label("Guion", systemImage: "text.alignleft")
                }
                .disabled(camera.recording)
                Button { promptPlaying.toggle() } label: {
                    Label(promptPlaying ? "Pausar texto" : "Leer", systemImage: promptPlaying ? "pause.fill" : "play.fill")
                }
                Button { camera.toggleCamera() } label: {
                    Image(systemName: "camera.rotate")
                }.disabled(camera.recording || camera.busy)
            }
            .font(.system(size: 13, weight: .medium))
            .buttonStyle(.bordered)

            Button(action: {
                if camera.recording { camera.stopRecording() }
                else { camera.record() }
            }) {
                Label(camera.recording ? "Detener grabación" : "Grabar video",
                      systemImage: camera.recording ? "stop.fill" : "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GoldButtonStyle())
            .disabled((!camera.cameraReady || camera.busy) && !camera.recording)
            .padding(.horizontal, 16)

            Text(camera.message)
                .font(.caption)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            if let error = camera.errorMessage {
                Text(error).font(.caption2).foregroundStyle(.red).padding(.horizontal)
            }
            if camera.lastRecording != nil {
                Button("Ver el video terminado") { section = 2 }
                    .font(.caption.weight(.bold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tu última toma").font(.title2.bold())
                if let url = camera.lastRecording {
                    Label("Archivo original listo", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Grabado mediante la cámara nativa del iPhone. Sin música ni conversión web.")
                        .font(.subheadline).foregroundStyle(.gray)
                    Button("Reproducir video") { showPreview = true }
                        .buttonStyle(GoldButtonStyle())
                    Button("Guardar directamente en Fotos") { camera.saveToPhotos() }
                        .buttonStyle(GoldButtonStyle())
                    ShareLink(item: url) {
                        Label("Compartir video original", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered)
                } else {
                    Text("Todavía no hay un video terminado. Graba una toma de 90 segundos para comprobar que la imagen no se congela.")
                        .foregroundStyle(.gray)
                    Button("Ir a grabar") { section = 1 }.buttonStyle(GoldButtonStyle())
                }
                Text(camera.message).font(.caption).foregroundStyle(.gray)
                Divider()
                Text("Prueba recomendada").font(.headline)
                Text("1. Graba 90 segundos. 2. Reproduce inicio, mitad y final. 3. Guarda en Fotos. 4. Confirma que tu voz e imagen continúen hasta el final.")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }.padding(20)
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "00:00" }
        let total = max(Int(seconds), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.04))
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.84, green: 0.66, blue: 0.38), in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
