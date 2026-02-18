import Cocoa

final class PianoKeyboardView: NSView {
    private struct WhiteBinding {
        let symbol: String
        let keyCode: UInt16
    }
    
    private struct PianoKey {
        let id: String
        let keyboardLabel: String
        let noteLabel: String
        let frequency: Double
        let whiteIndex: Int
    }
    
    private static let majorScaleSemitones = [0, 2, 4, 5, 7, 9, 11]
    private static let noteLetters = ["C", "D", "E", "F", "G", "A", "B"]
    private static let sharpSupportedDegrees: Set<Int> = [0, 1, 3, 4, 5] // C D F G A
    
    // autopiano 风格：1-0 q-p a-l z-m
    private static let whiteBindings: [WhiteBinding] = [
        .init(symbol: "1", keyCode: 18),
        .init(symbol: "2", keyCode: 19),
        .init(symbol: "3", keyCode: 20),
        .init(symbol: "4", keyCode: 21),
        .init(symbol: "5", keyCode: 23),
        .init(symbol: "6", keyCode: 22),
        .init(symbol: "7", keyCode: 26),
        .init(symbol: "8", keyCode: 28),
        .init(symbol: "9", keyCode: 25),
        .init(symbol: "0", keyCode: 29),
        
        .init(symbol: "q", keyCode: 12),
        .init(symbol: "w", keyCode: 13),
        .init(symbol: "e", keyCode: 14),
        .init(symbol: "r", keyCode: 15),
        .init(symbol: "t", keyCode: 17),
        .init(symbol: "y", keyCode: 16),
        .init(symbol: "u", keyCode: 32),
        .init(symbol: "i", keyCode: 34),
        .init(symbol: "o", keyCode: 31),
        .init(symbol: "p", keyCode: 35),
        
        .init(symbol: "a", keyCode: 0),
        .init(symbol: "s", keyCode: 1),
        .init(symbol: "d", keyCode: 2),
        .init(symbol: "f", keyCode: 3),
        .init(symbol: "g", keyCode: 5),
        .init(symbol: "h", keyCode: 4),
        .init(symbol: "j", keyCode: 38),
        .init(symbol: "k", keyCode: 40),
        .init(symbol: "l", keyCode: 37),
        
        .init(symbol: "z", keyCode: 6),
        .init(symbol: "x", keyCode: 7),
        .init(symbol: "c", keyCode: 8),
        .init(symbol: "v", keyCode: 9),
        .init(symbol: "b", keyCode: 11),
        .init(symbol: "n", keyCode: 45),
        .init(symbol: "m", keyCode: 46)
    ]
    
    private let audioSynthesizer: AudioSynthesizer
    
    private var whiteKeys: [PianoKey] = []
    private var blackKeys: [PianoKey] = []
    private var keysByID: [String: PianoKey] = [:]
    private var whiteKeyByCode: [UInt16: PianoKey] = [:]
    private var blackIDByWhiteID: [String: String] = [:]
    private var keyFrames: [String: NSRect] = [:]
    
    private var pressedKeyIDs: Set<String> = []
    private var activeKeyIDByCode: [UInt16: String] = [:]
    private var animatedPress: [String: CGFloat] = [:]
    private var mousePressedKeyID: String?
    private var animationTimer: Timer?
    
    init(frame: NSRect, audioSynthesizer: AudioSynthesizer) {
        self.audioSynthesizer = audioSynthesizer
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1.0).cgColor
        buildKeys()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        animationTimer?.invalidate()
        audioSynthesizer.stopAll()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        recalculateKeyFrames()
        drawBackground()
        drawHeader()
        drawWhiteKeys()
        drawBlackKeys()
    }
    
    @discardableResult
    func handleKeyDownEvent(_ event: NSEvent) -> Bool {
        guard let keyID = keyIDForEvent(event) else {
            return false
        }
        
        if event.isARepeat {
            return activeKeyIDByCode[event.keyCode] != nil
        }
        
        if let previousKeyID = activeKeyIDByCode[event.keyCode], previousKeyID != keyID {
            _ = releaseKey(id: previousKeyID)
        }
        
        activeKeyIDByCode[event.keyCode] = keyID
        return pressKey(id: keyID)
    }
    
    @discardableResult
    func handleKeyUpEvent(_ event: NSEvent) -> Bool {
        if let activeID = activeKeyIDByCode.removeValue(forKey: event.keyCode) {
            return releaseKey(id: activeID)
        }
        
        guard let keyID = keyIDForEvent(event) else {
            return false
        }
        
        return releaseKey(id: keyID)
    }
    
    override func keyDown(with event: NSEvent) {
        if !handleKeyDownEvent(event) {
            super.keyDown(with: event)
        }
    }
    
    override func keyUp(with event: NSEvent) {
        if !handleKeyUpEvent(event) {
            super.keyUp(with: event)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        updateMousePressedKey(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        updateMousePressedKey(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        if let keyID = mousePressedKeyID {
            _ = releaseKey(id: keyID)
            mousePressedKeyID = nil
        }
    }
    
    override var acceptsFirstResponder: Bool {
        true
    }
    
    override func becomeFirstResponder() -> Bool {
        true
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
    
    private func buildKeys() {
        whiteKeys.removeAll()
        blackKeys.removeAll()
        keysByID.removeAll()
        whiteKeyByCode.removeAll()
        blackIDByWhiteID.removeAll()
        
        let baseOctave = 3
        
        for (index, binding) in Self.whiteBindings.enumerated() {
            let degree = index % Self.majorScaleSemitones.count
            let semitone = Self.majorScaleSemitones[degree]
            let octave = baseOctave + index / Self.majorScaleSemitones.count
            let noteLetter = Self.noteLetters[degree]
            let midi = 12 * (octave + 1) + semitone
            
            let whiteKey = PianoKey(
                id: binding.symbol,
                keyboardLabel: binding.symbol,
                noteLabel: "\(noteLetter)\(octave)",
                frequency: midiToFrequency(midi),
                whiteIndex: index
            )
            
            whiteKeys.append(whiteKey)
            keysByID[whiteKey.id] = whiteKey
            whiteKeyByCode[binding.keyCode] = whiteKey
            
            guard Self.sharpSupportedDegrees.contains(degree), let blackSymbol = shiftedSymbol(for: binding.symbol) else {
                continue
            }
            
            let blackKey = PianoKey(
                id: blackSymbol,
                keyboardLabel: blackSymbol,
                noteLabel: "\(noteLetter)#\(octave)",
                frequency: midiToFrequency(midi + 1),
                whiteIndex: index
            )
            
            blackKeys.append(blackKey)
            keysByID[blackKey.id] = blackKey
            blackIDByWhiteID[whiteKey.id] = blackKey.id
        }
    }
    
    private func drawBackground() {
        let gradient = NSGradient(colors: [
            NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.0),
            NSColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1.0)
        ])
        gradient?.draw(in: bounds, angle: -90)
        
        let keyboardRect = keyboardBounds()
        let panelRect = keyboardRect.insetBy(dx: -16, dy: -14)
        let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 14, yRadius: 14)
        NSColor(red: 0.13, green: 0.15, blue: 0.20, alpha: 0.92).setFill()
        panelPath.fill()
        NSColor(red: 0.27, green: 0.32, blue: 0.42, alpha: 0.78).setStroke()
        panelPath.lineWidth = 1
        panelPath.stroke()
    }
    
    private func drawHeader() {
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 17, weight: .bold),
            .foregroundColor: NSColor(red: 0.93, green: 0.95, blue: 0.99, alpha: 0.98)
        ]
        let titleRect = NSRect(x: 24, y: bounds.height - 42, width: bounds.width - 48, height: 20)
        NSAttributedString(string: "Auto Piano Layout", attributes: titleAttr).draw(in: titleRect)
        
        let helpAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor(red: 0.74, green: 0.78, blue: 0.88, alpha: 0.95)
        ]
        let helpText = "White: 1-0 q-p a-l z-m   |   Black: hold Shift + same key"
        let helpRect = NSRect(x: 24, y: bounds.height - 60, width: bounds.width - 48, height: 15)
        NSAttributedString(string: helpText, attributes: helpAttr).draw(in: helpRect)
    }
    
    private func drawWhiteKeys() {
        for key in whiteKeys {
            guard var rect = keyFrames[key.id] else {
                continue
            }
            
            let press = currentPress(for: key.id)
            rect.origin.y -= press * 4
            
            let fillTop = blendedColor(
                from: NSColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 1.0),
                to: NSColor(red: 0.88, green: 0.95, blue: 1.0, alpha: 1.0),
                amount: press
            )
            let fillBottom = blendedColor(
                from: NSColor(red: 0.88, green: 0.87, blue: 0.84, alpha: 1.0),
                to: NSColor(red: 0.70, green: 0.84, blue: 1.0, alpha: 1.0),
                amount: press
            )
            
            let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            let fillGradient = NSGradient(starting: fillTop, ending: fillBottom)
            fillGradient?.draw(in: path, angle: -90)
            
            blendedColor(
                from: NSColor(red: 0.62, green: 0.64, blue: 0.70, alpha: 1.0),
                to: NSColor(red: 0.35, green: 0.56, blue: 0.92, alpha: 1.0),
                amount: press
            ).setStroke()
            path.lineWidth = 1
            path.stroke()
            
            drawWhiteKeyText(for: key, in: rect)
        }
    }
    
    private func drawBlackKeys() {
        for key in blackKeys {
            guard var rect = keyFrames[key.id] else {
                continue
            }
            
            let press = currentPress(for: key.id)
            rect.origin.y -= press * 2.5
            
            let top = blendedColor(
                from: NSColor(red: 0.22, green: 0.24, blue: 0.30, alpha: 1.0),
                to: NSColor(red: 0.25, green: 0.44, blue: 0.72, alpha: 1.0),
                amount: press
            )
            let bottom = blendedColor(
                from: NSColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1.0),
                to: NSColor(red: 0.16, green: 0.29, blue: 0.52, alpha: 1.0),
                amount: press
            )
            
            let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
            let gradient = NSGradient(starting: top, ending: bottom)
            gradient?.draw(in: path, angle: -90)
            
            NSColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 0.96).setStroke()
            path.lineWidth = 1
            path.stroke()
            
            drawBlackKeyText(for: key, in: rect)
        }
    }
    
    private func drawWhiteKeyText(for key: PianoKey, in rect: NSRect) {
        let noteAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor(red: 0.18, green: 0.22, blue: 0.30, alpha: 0.92)
        ]
        let noteRect = NSRect(x: rect.minX + 3, y: rect.maxY - 20, width: rect.width - 6, height: 12)
        NSAttributedString(string: key.noteLabel, attributes: noteAttr).draw(in: noteRect)
        
        let keyAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor(red: 0.34, green: 0.39, blue: 0.52, alpha: 0.96)
        ]
        let keyRect = NSRect(x: rect.minX + 3, y: rect.minY + 8, width: rect.width - 6, height: 12)
        NSAttributedString(string: key.keyboardLabel, attributes: keyAttr).draw(in: keyRect)
    }
    
    private func drawBlackKeyText(for key: PianoKey, in rect: NSRect) {
        let noteAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: NSColor(red: 0.90, green: 0.93, blue: 0.99, alpha: 0.9)
        ]
        let noteRect = NSRect(x: rect.minX + 2, y: rect.maxY - 16, width: rect.width - 4, height: 10)
        NSAttributedString(string: key.noteLabel, attributes: noteAttr).draw(in: noteRect)
        
        let keyAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor(red: 0.88, green: 0.92, blue: 1.0, alpha: 0.98)
        ]
        let keyRect = NSRect(x: rect.minX + 2, y: rect.minY + 6, width: rect.width - 4, height: 10)
        NSAttributedString(string: key.keyboardLabel, attributes: keyAttr).draw(in: keyRect)
    }
    
    private func keyboardBounds() -> NSRect {
        NSRect(
            x: 22,
            y: 20,
            width: bounds.width - 44,
            height: max(160, bounds.height - 96)
        )
    }
    
    private func recalculateKeyFrames() {
        keyFrames.removeAll(keepingCapacity: true)
        
        guard !whiteKeys.isEmpty else {
            return
        }
        
        let keyboardRect = keyboardBounds()
        let spacing: CGFloat = 1
        let whiteCount = CGFloat(whiteKeys.count)
        let totalSpacing = spacing * (whiteCount - 1)
        let whiteWidth = max(18, (keyboardRect.width - totalSpacing) / whiteCount)
        let whiteHeight = keyboardRect.height
        
        for (index, key) in whiteKeys.enumerated() {
            let x = keyboardRect.minX + CGFloat(index) * (whiteWidth + spacing)
            keyFrames[key.id] = NSRect(x: x, y: keyboardRect.minY, width: whiteWidth, height: whiteHeight)
        }
        
        let blackWidth = max(12, whiteWidth * 0.62)
        let blackHeight = whiteHeight * 0.62
        
        for key in blackKeys {
            guard let leftRect = keyFrames[whiteKeys[key.whiteIndex].id] else {
                continue
            }
            
            let x = leftRect.maxX - blackWidth * 0.42
            let y = keyboardRect.maxY - blackHeight
            keyFrames[key.id] = NSRect(x: x, y: y, width: blackWidth, height: blackHeight)
        }
    }
    
    private func keyIDForEvent(_ event: NSEvent) -> String? {
        guard let whiteKey = whiteKeyByCode[event.keyCode] else {
            return nil
        }
        
        if event.modifierFlags.contains(.shift) {
            return blackIDByWhiteID[whiteKey.id]
        }
        
        return whiteKey.id
    }
    
    private func updateMousePressedKey(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let hoveredKeyID = keyID(at: point)
        
        if hoveredKeyID == mousePressedKeyID {
            return
        }
        
        if let currentID = mousePressedKeyID {
            _ = releaseKey(id: currentID)
        }
        
        mousePressedKeyID = hoveredKeyID
        
        if let hoveredKeyID {
            _ = pressKey(id: hoveredKeyID)
        }
    }
    
    private func keyID(at point: NSPoint) -> String? {
        recalculateKeyFrames()
        
        for key in blackKeys.reversed() {
            if let rect = keyFrames[key.id], rect.contains(point) {
                return key.id
            }
        }
        
        for key in whiteKeys {
            if let rect = keyFrames[key.id], rect.contains(point) {
                return key.id
            }
        }
        
        return nil
    }
    
    private func pressKey(id: String) -> Bool {
        guard let key = keysByID[id] else {
            return false
        }
        
        if pressedKeyIDs.contains(id) {
            return true
        }
        
        pressedKeyIDs.insert(id)
        audioSynthesizer.playNote(id: key.id, frequency: key.frequency, duration: 3.0)
        print("⬇️ Key pressed: \(key.id)")
        beginAnimationIfNeeded()
        return true
    }
    
    private func releaseKey(id: String) -> Bool {
        guard keysByID[id] != nil else {
            return false
        }
        
        if pressedKeyIDs.contains(id) {
            pressedKeyIDs.remove(id)
            audioSynthesizer.stopNote(key: id)
            print("⬆️ Key released: \(id)")
            beginAnimationIfNeeded()
        }
        
        return true
    }
    
    private func currentPress(for keyID: String) -> CGFloat {
        if let value = animatedPress[keyID] {
            return value
        }
        
        return pressedKeyIDs.contains(keyID) ? 1.0 : 0.0
    }
    
    private func beginAnimationIfNeeded() {
        if animationTimer == nil {
            animationTimer = Timer.scheduledTimer(
                timeInterval: 1.0 / 60.0,
                target: self,
                selector: #selector(stepAnimation),
                userInfo: nil,
                repeats: true
            )
            if let animationTimer {
                RunLoop.main.add(animationTimer, forMode: .common)
            }
        }
        
        needsDisplay = true
    }
    
    @objc
    private func stepAnimation() {
        var hasAnimating = false
        
        for keyID in keysByID.keys {
            let target: CGFloat = pressedKeyIDs.contains(keyID) ? 1.0 : 0.0
            let current = animatedPress[keyID] ?? target
            let next = current + (target - current) * 0.28
            
            if abs(next - target) < 0.01 {
                animatedPress[keyID] = target
            } else {
                animatedPress[keyID] = next
                hasAnimating = true
            }
        }
        
        needsDisplay = true
        
        if !hasAnimating {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }
    
    private func blendedColor(from: NSColor, to: NSColor, amount: CGFloat) -> NSColor {
        let clamped = min(max(amount, 0), 1)
        
        guard
            let fromRGB = from.usingColorSpace(.deviceRGB),
            let toRGB = to.usingColorSpace(.deviceRGB)
        else {
            return from
        }
        
        var fr: CGFloat = 0
        var fg: CGFloat = 0
        var fb: CGFloat = 0
        var fa: CGFloat = 0
        fromRGB.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        
        var tr: CGFloat = 0
        var tg: CGFloat = 0
        var tb: CGFloat = 0
        var ta: CGFloat = 0
        toRGB.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        
        return NSColor(
            red: fr + (tr - fr) * clamped,
            green: fg + (tg - fg) * clamped,
            blue: fb + (tb - fb) * clamped,
            alpha: fa + (ta - fa) * clamped
        )
    }
    
    private func midiToFrequency(_ midi: Int) -> Double {
        440.0 * pow(2.0, Double(midi - 69) / 12.0)
    }
    
    private func shiftedSymbol(for symbol: String) -> String? {
        switch symbol {
        case "1": return "!"
        case "2": return "@"
        case "3": return "#"
        case "4": return "$"
        case "5": return "%"
        case "6": return "^"
        case "7": return "&"
        case "8": return "*"
        case "9": return "("
        case "0": return ")"
        default:
            return symbol.uppercased()
        }
    }
}
