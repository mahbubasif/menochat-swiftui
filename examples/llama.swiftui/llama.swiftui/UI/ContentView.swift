import SwiftUI

struct ContentView: View {
    
    @StateObject var llamaState = LlamaState()
    
    // --- NATIVE VOICE & TTS MANAGERS ---
    @StateObject var speech = NativeSpeechManager()
    @StateObject var tts = TTSManager()
    
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    // FIX 1: Actual working Dark Mode state
    @State private var isDarkMode = true

    // Dynamic UI Colors based on mode
    var bgColor: Color {
        isDarkMode ? Color(red: 0.13, green: 0.13, blue: 0.13) : Color(uiColor: .systemGray6)
    }
    
    var textColor: Color {
        isDarkMode ? .white : .primary
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if llamaState.messages.isEmpty {
                            MenochatHomeView(
                                isModelReady: llamaState.isModelReady,
                                textColor: textColor,
                                onSuggestionTapped: { suggestion in
                                    messageText = suggestion
                                    sendMessage()
                                }
                            )
                            .padding(.top, 60)
                            .padding(.bottom, 20)
                        }

                        ForEach(llamaState.messages) { message in
                            ChatBubble(
                                message: message,
                                isGenerating: llamaState.isGenerating,
                                isDarkMode: isDarkMode,
                                tts: tts // Pass the TTS manager to the bubble
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                }
                .background(bgColor)
                .onTapGesture {
                    isInputFocused = false
                }
                .onChange(of: llamaState.messages.count) { _ in
                    scrollToLatestMessage(proxy)
                }
                .onChange(of: llamaState.messages.last?.text) { _ in
                    scrollToLatestMessage(proxy)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Menochat")
                        .font(.headline)
                        .foregroundStyle(textColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Moon/Sun icon now ACTUALLY toggles dark mode
                    Button {
                        isDarkMode.toggle()
                    } label: {
                        Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                            .foregroundStyle(isDarkMode ? .gray : .orange)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    // The edit icon now correctly clears the chat for a new session
                    Button {
                        clearChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(textColor)
                    }
                    .disabled(llamaState.messages.isEmpty || llamaState.isGenerating)
                }
            }
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                ChatInputBar(
                    text: $messageText,
                    isGenerating: llamaState.isGenerating,
                    isModelReady: llamaState.isModelReady,
                    isFocused: $isInputFocused,
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                    speech: speech, // Pass the speech manager to the input bar
                    onSend: {
                        // Automatically stop recording when you hit send
                        if speech.isRecording { speech.toggleRecording() }
                        sendMessage()
                    }
                )
                .background(bgColor)
            }
            .task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                llamaState.loadBundledModelIfNeeded()
            }
        }
        // Apply the color scheme across the entire app
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !llamaState.isGenerating, llamaState.isModelReady else {
            return
        }

        messageText = ""
        Task {
            await llamaState.sendChatMessage(text)
        }
    }

    private func clearChat() {
        Task {
            await llamaState.clearChat()
        }
    }

    private func scrollToLatestMessage(_ proxy: ScrollViewProxy) {
        guard let latestMessage = llamaState.messages.last else {
            return
        }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(latestMessage.id, anchor: .bottom)
        }
    }
}

// MARK: - Menochat Home & Suggestions
private struct MenochatHomeView: View {
    let isModelReady: Bool
    let textColor: Color
    let onSuggestionTapped: (String) -> Void
    
    let suggestions = [
        "পিরিয়ডের সময় অস্বস্তি বা ব্যথা অনুভব করছো?",
        "পিরিয়ড অনিয়মিত হলে কী করা উচিত?",
        "প্যাড, কাপ, নাকি ট্যাম্পন — কোনটা তোমার জন্য ভালো?",
        "পিরিয়ড চলাকালীন খাবার বা ব্যায়াম নিয়ে দ্বিধায় আছো?",
        "পিরিয়ড নিয়ে মানসিক চাপ বা লজ্জা অনুভব করছো?"
    ]

    var body: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.6, green: 0.8, blue: 0.9), Color.purple.opacity(0.8)],
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading
                    ))
                    .frame(width: 140, height: 140)
                
                Image(systemName: "leaf.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            VStack(spacing: 8) {
                Text("Menochat / মেনোচ্যাট: সচেতনতা এবং স্বস্তি")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(textColor)
                
                if !isModelReady {
                    ProgressView()
                        .padding(.top, 10)
                }
            }
            .padding(.bottom, 20)

            VStack(spacing: 12) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: {
                        onSuggestionTapped(suggestion)
                    }) {
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundStyle(textColor)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .stroke(textColor.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .disabled(!isModelReady)
                    .opacity(isModelReady ? 1.0 : 0.5)
                }
            }
            .padding(.horizontal, 10)
        }
    }
}

// MARK: - Chat Bubbles
private struct ChatBubble: View {
    let message: ChatMessage
    let isGenerating: Bool
    let isDarkMode: Bool
    @ObservedObject var tts: TTSManager // We added the TTS manager here

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 40)
            } else {
                Circle()
                    .fill(Color.purple.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .overlay(Image(systemName: "leaf.fill").font(.system(size: 12)).foregroundColor(.white))
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text.isEmpty && !isUser ? "উত্তর তৈরি হচ্ছে..." : message.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .foregroundStyle(isUser ? .white : (isDarkMode ? .white : .black))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        bubbleColor,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                
                // --- NEW TTS PLAY BUTTON FOR AI RESPONSES ---
                if !isUser && !isGenerating {
                    Button(action: {
                        if tts.isSpeaking {
                            tts.stop()
                        } else {
                            tts.speak(text: message.text)
                        }
                    }) {
                        Image(systemName: tts.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .padding(.leading, 12)
                            .padding(.top, 2)
                    }
                }
            }
            .frame(maxWidth: 300, alignment: isUser ? .trailing : .leading)

            if !isUser {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var bubbleColor: Color {
        if isUser {
            return isDarkMode ? Color(red: 0.25, green: 0.25, blue: 0.25) : .blue
        } else {
            return isDarkMode ? Color(red: 0.18, green: 0.18, blue: 0.18) : .white
        }
    }
}

// MARK: - Input Bar
private struct ChatInputBar: View {
    @Binding var text: String
    let isGenerating: Bool
    let isModelReady: Bool
    var isFocused: FocusState<Bool>.Binding
    let isDarkMode: Bool
    let textColor: Color
    @ObservedObject var speech: NativeSpeechManager // We added the speech manager here
    let onSend: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating && isModelReady
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "paperclip")
                .font(.system(size: 20))
                .foregroundStyle(textColor)
                .rotationEffect(.degrees(-45))
            
            // --- UPDATED WAVEFORM BUTTON TO TRIGGER MICROPHONE ---
            Button(action: {
                speech.toggleRecording()
            }) {
                Image(systemName: speech.isRecording ? "stop.circle.fill" : "waveform")
                    .font(.system(size: 20))
                    // Turns red when actively listening!
                    .foregroundStyle(speech.isRecording ? .red : textColor)
            }

            TextField(isModelReady ? "প্রশ্ন লিখুন..." : "মডেল লোড হচ্ছে...", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .focused(isFocused)
                .textFieldStyle(.plain)
                .foregroundStyle(textColor)
                .padding(.horizontal, 10)
                .submitLabel(.send)
                .onSubmit {
                    if canSend { onSend() }
                }
                .disabled(!isModelReady)

            Button(action: onSend) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.45, green: 0.35, blue: 0.7))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .disabled(!canSend)
            .opacity(canSend ? 1.0 : 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isDarkMode ? Color(red: 0.18, green: 0.18, blue: 0.18) : .white,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        // Add a subtle shadow in light mode so it pops off the background
        .shadow(color: .black.opacity(isDarkMode ? 0 : 0.05), radius: 5, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        // --- THIS LINKS THE SPEECH RECOGNITION TO YOUR TEXT FIELD ---
        .onChange(of: speech.transcribedText) { newValue in
            if speech.isRecording {
                text = newValue
            }
        }
    }
}
