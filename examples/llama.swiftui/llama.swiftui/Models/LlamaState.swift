import Foundation

struct Model: Identifiable {
    var id = UUID()
    var name: String
    var url: String
    var filename: String
    var status: String?
}

enum ChatRole: Equatable {
    case user
    case assistant
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    var text: String
}

@MainActor
class LlamaState: ObservableObject {
    @Published var messageLog = ""
    @Published var messages: [ChatMessage] = []
    @Published var isGenerating = false
    @Published var activeModelName = "Loading model..."
    @Published var isModelReady = false
    @Published var isModelLoading = false
    @Published var modelStatus = "Checking local model..."
    @Published var cacheCleared = false
    @Published var downloadedModels: [Model] = []
    @Published var undownloadedModels: [Model] = []
    let NS_PER_S = 1_000_000_000.0

    private var llamaContext: LlamaContext?
    private let defaultModel = Model(
        name: "Afi Gemma4 E2B (IQ4_XS, 3.3 GB)",
        url: "https://huggingface.co/afifaimran/afi-gemma4-e2b-merged-gguf/resolve/main/afi_gemma4_e2b_merged-IQ4_XS.gguf?download=true",
        filename: "afi_gemma4_e2b_merged-IQ4_XS.gguf",
        status: "download"
    )

    init() {
        loadModelsFromDisk()
        loadDefaultModelList()
    }

    private func loadModelsFromDisk() {
        do {
            let documentsURL = getDocumentsDirectory()
            let modelURLs = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            for modelURL in modelURLs {
                guard modelURL.pathExtension == "gguf" else {
                    continue
                }
                let modelName = modelURL.deletingPathExtension().lastPathComponent
                downloadedModels.append(Model(name: modelName, url: "", filename: modelURL.lastPathComponent, status: "downloaded"))
            }
        } catch {
            print("Error loading models from disk: \(error)")
        }
    }

    private func loadDefaultModelList() {
        downloadedModels.removeAll { $0.filename == defaultModel.filename }
        undownloadedModels.removeAll { $0.filename == defaultModel.filename }

        if let localURL = findLocalDefaultModel() {
            let modelName = localURL.deletingPathExtension().lastPathComponent
            downloadedModels.append(Model(name: modelName, url: defaultModel.url, filename: defaultModel.filename, status: "downloaded"))
        } else {
            undownloadedModels.append(defaultModel)
        }
    }

    func loadBundledModelIfNeeded() {
        guard llamaContext == nil, !isModelReady, !isModelLoading else {
            return
        }

        activeModelName = defaultModel.name
        modelStatus = "মডেল লোড হচ্ছে..."
        messageLog += "Checking local model...\n"
        isModelReady = false
        isModelLoading = true

        Task.detached {
            do {
                let modelUrl = try await self.resolveDefaultModelUrl()
                let modelName = modelUrl.deletingPathExtension().lastPathComponent

                await MainActor.run {
                    self.modelStatus = "Loading \(modelName)..."
                    self.messageLog += "Loading model...\n"
                }

                let context = try LlamaContext.create_context(path: modelUrl.path())

                await MainActor.run {
                    self.llamaContext = context
                    self.messageLog += "Loaded model \(modelUrl.lastPathComponent)\n"
                    self.activeModelName = modelName
                    self.modelStatus = "প্রস্তুত"
                    self.isModelReady = true
                    self.isModelLoading = false
                    self.updateDownloadedModels(modelName: modelUrl.lastPathComponent, status: "downloaded")
                }
            } catch {
                await MainActor.run {
                    self.messageLog += "Error loading model: \(error.localizedDescription)\n"
                    self.activeModelName = "Model failed to load"
                    self.modelStatus = "Model failed to load"
                    self.isModelReady = false
                    self.isModelLoading = false
                }
            }
        }
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    private func findLocalDefaultModel() -> URL? {
        let documentsURL = getDocumentsDirectory().appendingPathComponent(defaultModel.filename)
        if FileManager.default.fileExists(atPath: documentsURL.path) {
            return documentsURL
        }

        if let bundledURL = Bundle.main.url(forResource: "afi_gemma4_e2b_merged-IQ4_XS", withExtension: "gguf", subdirectory: "models") {
            return bundledURL
        }

        return Bundle.main.url(forResource: "afi_gemma4_e2b_merged-IQ4_XS", withExtension: "gguf")
    }

    private func resolveDefaultModelUrl() async throws -> URL {
        if let localURL = findLocalDefaultModel() {
            return localURL
        }

        guard let downloadURL = URL(string: defaultModel.url) else {
            throw URLError(.badURL)
        }

        modelStatus = "Downloading \(defaultModel.name)..."
        messageLog += "Downloading \(defaultModel.filename)...\n"

        let destinationURL = getDocumentsDirectory().appendingPathComponent(defaultModel.filename)
        let temporaryURL = destinationURL.appendingPathExtension("download")

        if FileManager.default.fileExists(atPath: temporaryURL.path) {
            try FileManager.default.removeItem(at: temporaryURL)
        }

        let (downloadedURL, response) = try await URLSession.shared.download(from: downloadURL)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        try FileManager.default.moveItem(at: downloadedURL, to: temporaryURL)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        downloadedModels.append(Model(name: defaultModel.name, url: defaultModel.url, filename: defaultModel.filename, status: "downloaded"))
        undownloadedModels.removeAll { $0.filename == defaultModel.filename }

        return destinationURL
    }

    func loadModel(modelUrl: URL?) throws {
        isModelReady = false
        isModelLoading = true
        defer {
            isModelLoading = false
        }
        if let modelUrl {
            messageLog += "Loading model...\n"
            llamaContext = try LlamaContext.create_context(path: modelUrl.path())
            messageLog += "Loaded model \(modelUrl.lastPathComponent)\n"
            activeModelName = modelUrl.deletingPathExtension().lastPathComponent
            isModelReady = true

            updateDownloadedModels(modelName: modelUrl.lastPathComponent, status: "downloaded")
        } else {
            messageLog += "Load a model from the list below\n"
            activeModelName = "No model loaded"
            isModelReady = false
        }
    }

    private func updateDownloadedModels(modelName: String, status: String) {
        undownloadedModels.removeAll { $0.name == modelName || $0.filename == modelName }
    }

    func sendChatMessage(_ text: String) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, !isGenerating else {
            return
        }

        guard let llamaContext else {
            messages.append(ChatMessage(role: .assistant, text: "No model is loaded yet."))
            return
        }

        messages.append(ChatMessage(role: .user, text: trimmedText))
        let prompt = buildChatPrompt()
        let assistantMessage = ChatMessage(role: .assistant, text: "")
        messages.append(assistantMessage)
        isGenerating = true

        await llamaContext.completion_init(text: prompt)
        messageLog += "\(prompt)"

        Task.detached {
            while await !llamaContext.is_done {
                let result = await llamaContext.completion_loop()
                await MainActor.run {
                    self.appendToken(result, to: assistantMessage.id)
                    self.messageLog += "\(result)"
                }
            }

            await llamaContext.clear()

            await MainActor.run {
                self.isGenerating = false
            }
        }
    }

    // FIX 2: We ONLY clear the message array now. We don't force a hard C++ context clear
    // because that was causing the model to crash/hang on the next prompt.
    func clearChat() async {
        messages.removeAll()
        messageLog = ""
        isGenerating = false
    }

    // FIX 3: Sliding Window Memory. It now only remembers the last 4 messages.
    // This stops the prompt from growing too large and crashing the context limit.
    private func buildChatPrompt() -> String {
        var prompt = ""
        let systemPrompt = "তুমি মেনোচ্যাট (Menochat), মেয়েদের পিরিয়ড এবং স্বাস্থ্য বিষয়ক একটি সহায়ক, সহানুভূতিশীল এবং নির্ভরযোগ্য এআই। তুমি সবসময় পরিষ্কার এবং গোছানো বাংলায় উত্তর দেবে। ব্যবহারকারীর প্রশ্নের বিস্তারিত অথচ সহজবোধ্য উত্তর দেবে (৪-৫ বাক্যের মধ্যে)। খুব বেশি বড় বা অপ্রাসঙ্গিক কথা বলবে না।"

        // Keep the context window manageable (last 4 messages to avoid crashing the local model)
        let recentMessages = messages.count > 4 ? Array(messages.suffix(4)) : messages

        for (index, message) in recentMessages.enumerated() {
            switch message.role {
            case .user:
                if prompt.isEmpty {
                    // Always inject the persona securely at the top of the memory window
                    prompt += "<start_of_turn>user\nSystem: \(systemPrompt)\n\nUser: \(message.text)<end_of_turn>\n"
                } else {
                    prompt += "<start_of_turn>user\n\(message.text)<end_of_turn>\n"
                }
            case .assistant where !message.text.isEmpty:
                prompt += "<start_of_turn>model\n\(message.text)<end_of_turn>\n"
            case .assistant:
                continue
            }
        }

        prompt += "<start_of_turn>model\n"
        return prompt
    }

    private func appendToken(_ token: String, to messageID: UUID) {
        guard let messageIndex = messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }
        messages[messageIndex].text += token
    }
    
    func complete(text: String) async { /* Left empty, replaced by chat logic */ }
    func bench() async { /* Unchanged */ }
    func clear() async {
        guard let llamaContext else { return }
        await llamaContext.clear()
        messageLog = ""
    }
}
