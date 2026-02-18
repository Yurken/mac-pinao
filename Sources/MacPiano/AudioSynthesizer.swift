import AVFoundation
import Foundation

final class AudioSynthesizer {
    private let audioEngine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let sampleRate: Double = 44100
    private let sampleSubdirectory = "Samples/acoustic_grand_piano"
    private var activePlayers: [String: AVAudioPlayerNode] = [:]
    private var sampleBuffers: [String: AVAudioPCMBuffer] = [:]
    private let lock = NSLock()
    private var isEngineRunning = false
    
    init() {
        setupAudioEngine()
        loadSampleLibrary()
    }
    
    private func setupAudioEngine() {
        do {
            // 附加 mixer 节点到引擎
            audioEngine.attach(mixer)
            mixer.outputVolume = 1.0
            
            // 连接 mixer 到主输出
            audioEngine.connect(mixer, to: audioEngine.mainMixerNode, format: nil)
            
            // 启动引擎
            try audioEngine.start()
            isEngineRunning = true
            print("✅ Audio engine started successfully")
        } catch {
            print("❌ Failed to setup audio engine: \(error)")
            isEngineRunning = false
        }
    }
    
    private func loadSampleLibrary() {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        
        let urlsFromSubdirectory = bundle.urls(forResourcesWithExtension: "mp3", subdirectory: sampleSubdirectory) ?? []
        let urlsFromBundleRoot = bundle.urls(forResourcesWithExtension: "mp3", subdirectory: nil) ?? []
        let urls = urlsFromSubdirectory.isEmpty ? urlsFromBundleRoot : urlsFromSubdirectory
        
        guard !urls.isEmpty else {
            print("⚠️ No piano sample files found, fallback to synthesized audio")
            return
        }
        
        var loadedCount = 0
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let buffer = loadAudioBuffer(from: url) else {
                continue
            }
            
            let note = url.deletingPathExtension().lastPathComponent
            sampleBuffers[note] = buffer
            loadedCount += 1
        }
        
        if loadedCount > 0 {
            print("✅ Loaded \(loadedCount) piano samples")
        } else {
            print("⚠️ Failed to decode piano samples, fallback to synthesized audio")
        }
    }
    
    private func loadAudioBuffer(from url: URL) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: url)
            let frameCount = AVAudioFrameCount(file.length)
            
            guard frameCount > 0 else {
                return nil
            }
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
                return nil
            }
            
            try file.read(into: buffer)
            return buffer
        } catch {
            print("⚠️ Failed to load sample file \(url.lastPathComponent): \(error)")
            return nil
        }
    }
    
    func playNote(id: String, frequency: Double, duration: Double = 1.0) {
        let keyID = id
        
        // 如果已有该键的音符在播放，先停止
        stopNote(key: keyID)
        
        // 确保引擎正在运行
        if !isEngineRunning {
            print("❌ Audio engine is not running")
            return
        }
        
        let audioBuffer: AVAudioPCMBuffer
        let source: String
        
        if let sampleNote = sampleNoteName(for: frequency), let sampleBuffer = sampleBuffers[sampleNote] {
            audioBuffer = sampleBuffer
            source = "sample \(sampleNote)"
        } else {
            guard let generated = generateAudioBuffer(frequency: frequency, duration: duration) else {
                print("❌ Failed to generate audio buffer for frequency \(frequency)")
                return
            }
            
            audioBuffer = generated
            source = "synth"
        }
        
        // 创建播放节点
        let playerNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)
        
        // 使用正确的音频格式连接
        audioEngine.connect(playerNode, to: mixer, format: audioBuffer.format)
        
        playerNode.scheduleBuffer(audioBuffer, completionHandler: { [weak self, weak playerNode] in
            guard let self, let playerNode else {
                return
            }
            
            DispatchQueue.main.async { [weak self, weak playerNode] in
                guard let self, let playerNode else {
                    return
                }
                self.removePlayerIfMatching(keyID: keyID, expected: playerNode, detachNode: true)
            }
        })
        playerNode.play()
        
        lock.lock()
        activePlayers[keyID] = playerNode
        lock.unlock()
        
        print("🎵 Playing note: \(keyID) at \(frequency)Hz [\(source)]")
    }
    
    func stopNote(key: String) {
        let keyID = key
        
        lock.lock()
        let playerNode = activePlayers.removeValue(forKey: keyID)
        lock.unlock()
        
        if let playerNode {
            fadeOutAndDetach(playerNode)
            print("🛑 Stopped note: \(keyID)")
        }
    }
    
    func stopAll() {
        lock.lock()
        let players = Array(activePlayers.values)
        activePlayers.removeAll()
        lock.unlock()
        
        for playerNode in players {
            playerNode.stop()
            if playerNode.engine != nil {
                audioEngine.detach(playerNode)
            }
        }
        print("🛑 Stopped all notes")
    }
    
    private func removePlayerIfMatching(keyID: String, expected playerNode: AVAudioPlayerNode, detachNode: Bool) {
        var shouldDetach = false
        
        lock.lock()
        if let currentNode = activePlayers[keyID], currentNode === playerNode {
            activePlayers.removeValue(forKey: keyID)
            shouldDetach = true
        }
        lock.unlock()
        
        if shouldDetach && detachNode && playerNode.engine != nil {
            audioEngine.detach(playerNode)
        }
    }
    
    private func fadeOutAndDetach(_ playerNode: AVAudioPlayerNode) {
        let startVolume = max(playerNode.volume, 0.0001)
        let steps = 20
        let stepDuration = 0.0045
        
        for step in 1...steps {
            let delay = stepDuration * Double(step)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak playerNode] in
                guard let self, let playerNode else {
                    return
                }
                
                let progress = Float(step) / Float(steps)
                let eased = 1.0 - (progress * progress)
                playerNode.volume = startVolume * eased
                
                if step == steps {
                    playerNode.stop()
                    if playerNode.engine != nil {
                        self.audioEngine.detach(playerNode)
                    }
                    playerNode.volume = 1.0
                }
            }
        }
    }
    
    private func sampleNoteName(for frequency: Double) -> String? {
        guard frequency > 0 else {
            return nil
        }
        
        let midi = Int(round(69.0 + 12.0 * log2(frequency / 440.0)))
        guard midi >= 21 && midi <= 108 else {
            return nil
        }
        
        let noteNames = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
        let noteIndex = (midi % 12 + 12) % 12
        let octave = midi / 12 - 1
        return "\(noteNames[noteIndex])\(octave)"
    }
    
    private func generateAudioBuffer(frequency: Double, duration: Double) -> AVAudioPCMBuffer? {
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        guard let audioFormat = audioFormat else {
            print("❌ Failed to create audio format")
            return nil
        }
        
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            print("❌ Failed to create audio buffer")
            return nil
        }
        
        audioBuffer.frameLength = frameCount
        
        let channelData = audioBuffer.floatChannelData!
        var phase: Float = 0
        let phaseIncrement = Float(2.0 * Double.pi * frequency / sampleRate)
        
        for frame in 0..<Int(frameCount) {
            // 生成正弦波
            let amplitude = Float(sin(Double(phase)))
            
            // 添加包络以避免点击声 - 使用余弦包络更自然
            let progress = Float(frame) / Float(frameCount)
            let envelope: Float
            
            if progress < 0.05 {
                // 快速上升（0-5%）
                let attackProgress = progress / 0.05
                envelope = 0.5 * (1.0 - cosf(Float.pi * attackProgress))
            } else if progress > 0.9 {
                // 快速下降（90-100%）
                let releaseProgress = (progress - 0.9) / 0.1
                envelope = 0.5 * (1.0 + cosf(Float.pi * releaseProgress))
            } else {
                // 维持（5-90%）
                envelope = 1.0
            }
            
            // 组合波形和包络 - 增加振幅到 0.7
            channelData[0][frame] = amplitude * envelope * 0.7
            phase += phaseIncrement
            
            // 防止 phase 值过大
            if phase > Float.pi * 2.0 {
                phase -= Float.pi * 2.0
            }
        }
        
        print("✅ Generated audio buffer: \(frequency)Hz, duration: \(duration)s, frames: \(frameCount)")
        return audioBuffer
    }
    
    deinit {
        audioEngine.stop()
    }
}
