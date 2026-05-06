import SwiftUI

struct InputButton: View {
    @ObservedObject var llamaState: LlamaState
    
    // --- APPLE NATIVE SPEECH & TTS INTEGRATION ---
    @StateObject private var speech = NativeSpeechManager()
    @StateObject private var tts = TTSManager()
    
    @State private var inputLink: String = ""
    @State private var status: String = "download"
    @State private var filename: String = ""

    @State private var downloadTask: URLSessionDownloadTask?
    @State private var progress = 0.0
    @State private var observation: NSKeyValueObservation?

    private static func extractModelInfo(from link: String) -> (modelName: String, filename: String)? {
        guard let url = URL(string: link),
              let lastPathComponent = url.lastPathComponent.components(separatedBy: ".").first,
              let modelName = lastPathComponent.components(separatedBy: "-").dropLast().joined(separator: "-").removingPercentEncoding,
              let filename = lastPathComponent.removingPercentEncoding else {
            return nil
        }

        return (modelName, filename)
    }

    private static func getFileURL(filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
    }

    private func download() {
        guard let extractedInfo = InputButton.extractModelInfo(from: inputLink) else {
            return
        }

        let (modelName, filename) = extractedInfo
        self.filename = filename

        status = "downloading"
        print("Downloading model \(modelName) from \(inputLink)")
        guard let url = URL(string: inputLink) else { return }
        let fileURL = InputButton.getFileURL(filename: filename)

        downloadTask = URLSession.shared.downloadTask(with: url) { temporaryURL, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }

            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                print("Server error!")
                return
            }

            do {
                if let temporaryURL = temporaryURL {
                    try FileManager.default.copyItem(at: temporaryURL, to: fileURL)
                    print("Writing to \(filename) completed")

                    DispatchQueue.main.async {
                        self.llamaState.cacheCleared = false
                        let model = Model(name: modelName, url: self.inputLink, filename: filename, status: "downloaded")
                        self.llamaState.downloadedModels.append(model)
                        self.status = "downloaded"
                    }
                }
            } catch let err {
                print("Error: \(err.localizedDescription)")
            }
        }

        observation = downloadTask?.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                self.progress = progress.fractionCompleted
            }
        }

        downloadTask?.resume()
    }

    var body: some View {
        VStack(spacing: 15) {
            
            // --- EXISTING DOWNLOAD UI ---
            HStack {
                TextField("Paste Quantized Download Link", text: $inputLink)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: {
                    downloadTask?.cancel()
                    status = "download"
                }) {
                    Text("Cancel")
                }
            }

            if status == "download" {
                Button(action: download) {
                    Text("Download Custom Model")
                }
            } else if status == "downloading" {
                Button(action: {
                    downloadTask?.cancel()
                    status = "download"
                }) {
                    Text("Downloading \(Int(progress * 100))%")
                }
            } else if status == "downloaded" {
                Button(action: {
                    let fileURL = InputButton.getFileURL(filename: self.filename)
                    if !FileManager.default.fileExists(atPath: fileURL.path) {
                        download()
                        return
                    }
                    do {
                        try llamaState.loadModel(modelUrl: fileURL)
                    } catch let err {
                        print("Error: \(err.localizedDescription)")
                    }
                }) {
                    Text("Load Custom Model")
                }
            } else {
                Text("Unknown status")
            }
            
            // --- NEW NATIVE BENGALI VOICE UI ---
            Divider()
                .padding(.vertical, 10)
            
            VStack(spacing: 15) {
                Text("Menochat Voice Interface")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Text box showing transcribed text
                Text(speech.transcribedText.isEmpty ? "Tap mic to speak..." : speech.transcribedText)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                HStack(spacing: 30) {
                    // Record Button
                    Button(action: {
                        speech.toggleRecording()
                    }) {
                        Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(speech.isRecording ? .red : .blue)
                    }
                    
                    // SEND TO AI BUTTON
                    Button(action: {
                        // Stop recording if it's still listening
                        if speech.isRecording { speech.toggleRecording() }
                        
                        // Send the transcribed text to the LLaMA model
                        if !speech.transcribedText.isEmpty {
                            Task {
                                await llamaState.complete(text: speech.transcribedText)
                            }
                        }
                    }) {
                        Image(systemName: "paperplane.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(speech.transcribedText.isEmpty ? .gray : .green)
                    }
                    .disabled(speech.transcribedText.isEmpty)
                }
                
                // TTS BUTTON: Read the LLM's response
                Button(action: {
                    if tts.isSpeaking {
                        tts.stop()
                    } else {
                        // Pass the LLM's output text to the TTS engine
                        tts.speak(text: llamaState.messageLog)
                    }
                }) {
                    HStack {
                        Image(systemName: tts.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        Text(tts.isSpeaking ? "Stop Speaking" : "Read AI Response")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            // ----------------------------
            
        }
        .onDisappear() {
            downloadTask?.cancel()
        }
        .onChange(of: llamaState.cacheCleared) { newValue in
            if newValue {
                downloadTask?.cancel()
                let fileURL = InputButton.getFileURL(filename: self.filename)
                status = FileManager.default.fileExists(atPath: fileURL.path) ? "downloaded" : "download"
            }
        }
    }
}
