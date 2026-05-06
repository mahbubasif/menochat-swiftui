import AVFoundation
import SwiftUI

class TTSManager: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    
    func speak(text: String) {
        // Stop any current speech before starting new one
        synthesizer.stopSpeaking(at: .immediate)
        
        let utterance = AVSpeechUtterance(string: text)
        // Force the voice to Bengali (Bangladesh)
        utterance.voice = AVSpeechSynthesisVoice(language: "bn-BD")
        
        // You can adjust these to make it sound more natural
        utterance.rate = 0.5   // Speed (0.0 to 1.0)
        utterance.pitchMultiplier = 1.0 // Pitch
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}
