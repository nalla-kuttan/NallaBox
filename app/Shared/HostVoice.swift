import AVFoundation

/// Reads the host's lines aloud (captions always show on the TV). Queued; silent when turned off.
@MainActor
final class HostVoice {
    private let synth = AVSpeechSynthesizer()
    var enabled = true

    func speak(_ line: String) {
        guard enabled, !line.isEmpty else { return }
        let u = AVSpeechUtterance(string: line)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        u.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en-GB")
        synth.speak(u)
    }

    func stop() { synth.stopSpeaking(at: .immediate) }
}
