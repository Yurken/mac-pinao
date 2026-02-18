import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow?
    private var pianoView: PianoKeyboardView?
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🎹 Mac Piano - Application Launching")
        
        let audioSynthesizer = AudioSynthesizer()
        
        // 创建窗口
        window = NSWindow(
            contentRect: NSRect(x: 80, y: 80, width: 1240, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window?.title = "Mac Piano"
        window?.isReleasedWhenClosed = false
        window?.delegate = self
        window?.minSize = NSSize(width: 900, height: 320)
        window?.backgroundColor = NSColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0)
        
        // 创建菜单栏
        setupMenuBar()
        
        // 创建内容视图（使用普通 NSView，避免视觉特效导致黑屏）
        let createdPianoView = PianoKeyboardView(frame: window!.contentView!.bounds, audioSynthesizer: audioSynthesizer)
        createdPianoView.autoresizingMask = [.width, .height]
        createdPianoView.wantsLayer = true
        createdPianoView.layer?.backgroundColor = NSColor(red: 0.07, green: 0.09, blue: 0.13, alpha: 1.0).cgColor
        window?.contentView?.addSubview(createdPianoView)
        pianoView = createdPianoView
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installKeyboardMonitoring()
        DispatchQueue.main.async { [weak self] in
            self?.focusPianoView()
        }
        print("✅ Window shown and app activated")
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        focusPianoView()
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        focusPianoView()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        removeKeyboardMonitoring()
    }
    
    private func focusPianoView() {
        guard let window, let pianoView else {
            return
        }
        
        if window.firstResponder !== pianoView {
            window.makeFirstResponder(pianoView)
            print("✅ Piano view set as first responder")
        }
    }
    
    private func installKeyboardMonitoring() {
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let pianoView else {
                return event
            }
            
            guard self.shouldRouteKeyboardEvent(event) else {
                return event
            }
            
            if pianoView.handleKeyDownEvent(event) {
                return nil
            }
            return event
        }
        
        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self, let pianoView else {
                return event
            }
            
            guard self.shouldRouteKeyboardEvent(event) else {
                return event
            }
            
            if pianoView.handleKeyUpEvent(event) {
                return nil
            }
            return event
        }
        
        print("✅ App-level keyboard monitoring set up")
    }
    
    private func removeKeyboardMonitoring() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }
        if let keyUpMonitor {
            NSEvent.removeMonitor(keyUpMonitor)
            self.keyUpMonitor = nil
        }
    }
    
    private func shouldRouteKeyboardEvent(_ event: NSEvent) -> Bool {
        guard NSApp.isActive, let window else {
            return false
        }
        
        if !window.isKeyWindow {
            return false
        }
        
        let blockedModifiers = event.modifierFlags.intersection([.command, .option, .control])
        return blockedModifiers.isEmpty
    }
    
    private func setupMenuBar() {
        let mainMenu = NSMenu(title: "Main")
        
        // 应用菜单
        let appMenu = NSMenu(title: "App")
        appMenu.addItem(NSMenuItem(title: "Quit Mac Piano", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        let appMenuItem = NSMenuItem(title: "Mac Piano", action: nil, keyEquivalent: "")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
