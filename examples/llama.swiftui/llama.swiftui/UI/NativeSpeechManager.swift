import Foundation
import Speech
import AVFoundation

class NativeSpeechManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText = ""
    
    private var audioEngine = AVAudioEngine()
    // This strictly forces the Apple engine to listen for Bengali (Bangladesh)
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "bn-BD"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.beginAudioEngine()
                } else {
                    self.transcribedText = "Speech permission denied."
                }
            }
        }
    }
    
    private func beginAudioEngine() {
        task?.cancel()
        task = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }
        request.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
        
        isRecording = true
        transcribedText = "Listening to Bengali..."
        
        task = speechRecognizer?.recognitionTask(with: request) { result, error in
            var isFinal = false
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.request = nil
                self.task = nil
                self.isRecording = false
            }
        }
    }
    
    private func stopRecording() {
        audioEngine.stop()
        request?.endAudio()
        isRecording = false
    }
}
