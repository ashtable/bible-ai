import SwiftUI
import OSLog

private let spikeLog = Logger(subsystem: "com.retryai.bibleai", category: "spike")

@main
struct BibleAIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var spikeStatus = "Checking models…"
    @State private var spikeImage: UIImage?
    @State private var running = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Bible AI").font(.largeTitle)
            if let img = spikeImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300)
                    .cornerRadius(12)
            }
            Text(spikeStatus)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Run spike") { Task { await runSpike() } }
                .buttonStyle(.borderedProminent)
                .disabled(running)
        }
        .task { await runSpike() }
    }

    private func runSpike() async {
        guard !running else { return }
        running = true
        defer { running = false }

        guard CoreMLSpikeRunner.modelIsInstalled else {
            let url = (try? CoreMLSpikeRunner.spikeResourceURL())?.path ?? "nil"
            spikeStatus = "Model not installed at\n\(url)"
            spikeLog.error("Model not installed at \(url, privacy: .public)")
            return
        }

        spikeStatus = "Loading pipeline (cold start)…"
        print("SPIKE: loading pipeline (cold start)"); fflush(stdout)
        do {
            let runner = try CoreMLSpikeRunner()
            spikeStatus = "Running 20-step inference…"
            print("SPIKE: running 20-step inference"); fflush(stdout)
            let start = Date()
            let (cgImage, steps) = try await runner.run(prompt: "golden light through forest trees")
            let elapsed = Date().timeIntervalSince(start)
            spikeImage = UIImage(cgImage: cgImage)
            let pass = elapsed < 15
            let result = "\(pass ? "✓ PASS" : "✗ FAIL") · \(steps.count) steps · \(String(format: "%.1f", elapsed))s · \(cgImage.width)×\(cgImage.height)"
            spikeStatus = result + (pass ? "\nTask 0ʹ gate met (<15s)" : "\nexceeds 15s gate")
            print("SPIKE RESULT: \(result)"); fflush(stdout)
        } catch {
            spikeStatus = "✗ Error: \(error)"
            print("SPIKE ERROR: \(String(describing: error))"); fflush(stdout)
        }
    }
}
