import Foundation
import AVFoundation
import whisper

class WhisperManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var transcribedText = ""
    
    private var audioRecorder: AVAudioRecorder?
    private var whisperContext: OpaquePointer?
    private let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.wav")
    
    override init() {
        super.init()
        setupWhisper()
    }
    
    // MARK: - Model Setup
    private func setupWhisper() {
        if let modelPath = Bundle.main.path(forResource: "ggml-model-q5_0", ofType: "bin") {
            whisperContext = whisper_init_from_file(modelPath)
            print("Whisper model loaded successfully!")
        } else {
            print("Error: Could not find ggml-model-q5_0.bin in bundle.")
        }
    }
    
    // MARK: - Audio Recording
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            transcribedText = "Recording..."
            
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        transcribedText = "Processing audio..."
        transcribeAudio(url: audioURL)
    }
    
    // MARK: - Transcription
    private func transcribeAudio(url: URL) {
        guard let ctx = whisperContext else { return }
        
        let file = try! AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        try! file.read(into: buffer)
        
        let floatArray = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
        
        DispatchQueue.global(qos: .userInitiated).async {
            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            params.print_progress = false
            
            // THE FIX: Safely bridging the Swift String to a C++ String
            "bn".withCString { cString in
                params.language = cString
                
                // We execute the C++ function INSIDE this block
                whisper_full(ctx, params, floatArray, Int32(floatArray.count))
            }
            
            let n_segments = whisper_full_n_segments(ctx)
            var fullText = ""
            for i in 0..<n_segments {
                let text = String(cString: whisper_full_get_segment_text(ctx, i))
                fullText += text
            }
            
            DispatchQueue.main.async {
                self.transcribedText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
    
    deinit {
        if let ctx = whisperContext {
            whisper_free(ctx)
        }
    }
}
