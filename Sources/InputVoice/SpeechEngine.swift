import Foundation
import Speech
import AVFoundation

protocol SpeechEngineDelegate: AnyObject {
    func speechEngine(_ engine: SpeechEngine, didUpdateTranscription text: String)
    func speechEngine(_ engine: SpeechEngine, didUpdateRMSLevel level: Float)
    func speechEngineDidFinish(_ engine: SpeechEngine, finalText: String)
}

class SpeechEngine: NSObject {
    weak var delegate: SpeechEngineDelegate?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var currentTranscription = ""
    private var isRecording = false

    // RMS metering
    private var rmsLevel: Float = 0.0

    override init() {
        super.init()
        let lang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "zh-CN"
        updateLanguage(lang)
    }

    func updateLanguage(_ code: String) {
        let locale = Locale(identifier: code)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.defaultTaskHint = .dictation
    }

    func startRecording() {
        guard !isRecording else { return }
        currentTranscription = ""

        // Stop any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session (macOS uses AVAudioEngine directly)
        let inputNode = audioEngine.inputNode

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        // Install tap for audio buffer
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        let sampleRate = recordingFormat.sampleRate
        let bufferSize: AVAudioFrameCount = 1024

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.computeRMS(buffer: buffer, sampleRate: sampleRate)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("[SpeechEngine] Failed to start audio engine: \(error)")
            return
        }

        isRecording = true

        let lang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "zh-CN"
        updateLanguage(lang)

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                self.currentTranscription = text
                self.delegate?.speechEngine(self, didUpdateTranscription: text)
            }

            if let error = error {
                let nsError = error as NSError
                // Ignore cancellation errors
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 301 {
                    // Normal cancellation
                } else {
                    print("[SpeechEngine] Recognition error: \(error)")
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        recognitionRequest?.endAudio()

        // Give a short grace period for final results
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.recognitionTask?.finish()
            self.recognitionTask = nil
            self.recognitionRequest = nil
            let text = self.currentTranscription
            self.delegate?.speechEngineDidFinish(self, finalText: text)
        }
    }

    private func computeRMS(buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        var sum: Float = 0
        let data = channelData[0]
        for i in 0..<frameCount {
            let sample = data[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameCount))

        // Normalize to 0-1 range (typical speech RMS is roughly 0.01-0.3)
        let normalized = min(1.0, rms * 5.0)
        delegate?.speechEngine(self, didUpdateRMSLevel: normalized)
    }
}
