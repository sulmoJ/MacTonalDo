import AppKit
import SwiftUI
import os

/// 메뉴바를 거치지 않고 목록을 여는 떠다니는 창.
///
/// 메뉴바 아이콘은 자리를 못 받을 수 있다. 노치가 있는 맥북에서 아이콘이
/// 몇 개만 늘어도 macOS 는 넘치는 것을 소리 없이 빼 버리고, 늦게 올라온
/// 앱일수록 먼저 밀린다. `MenuBarExtra` 가 유일한 입구인 앱은 그 순간
/// 떠 있으면서도 열 방법이 사라진다.
///
/// 그래서 입구를 하나 더 둔다. 이 창은 메뉴바와 아무 상관이 없다.
///
/// 열 때마다 내용을 새로 만든다. `ContentView` 는 `onAppear` 에서 오늘로
/// 돌아가고 입력칸에 초점을 주는데, 창을 숨겼다 다시 보여 주는 식으로는
/// 그게 다시 불리지 않아서다.
@MainActor
final class QuickPanel: NSObject, NSWindowDelegate {
    private let store: TodoStore
    private var panel: NSPanel?
    private var hotkey: Hotkey?

    private static let log = Logger(subsystem: "local.mactonaldo", category: "panel")

    init(store: TodoStore) {
        self.store = store
        super.init()
    }

    /// 단축키를 잡는다. 못 잡아도 앱은 그대로 돌아간다.
    func listen() {
        hotkey = Hotkey(keyCode: DefaultHotkey.keyCode,
                        modifiers: DefaultHotkey.modifiers) { [weak self] in
            self?.toggle()
        }
    }

    func toggle() {
        if panel != nil { hide() } else { show() }
    }

    // MARK: - 열고 닫기

    private func show() {
        let hosting = NSHostingView(rootView: ContentView(store: store))
        hosting.setFrameSize(hosting.fittingSize)

        let panel = KeyablePanel(contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered,
                                 defer: false)
        panel.delegate = self

        // 제목줄이 있는 창은 그 높이가 내용 위에 빈 띠로 남는다.
        // 메뉴바에서 열리던 패널과 같은 모양이어야 해서 테두리를 없애고,
        // 둥근 모서리는 직접 깎는다.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 11
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting

        panel.isMovableByWindowBackground = true

        // 메뉴바가 가려 둔 입구를 대신하는 창이다. 전체 화면 위에도 떠야 한다.
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow

        place(panel)

        // 메뉴바에 아이콘이 없는 앱이라, 띄우는 것만으로는 글쇠를 못 받는다.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
        Self.log.notice("단축키로 열었다")
    }

    private func hide() {
        panel?.orderOut(nil)
        panel?.delegate = nil
        panel = nil
    }

    /// 마우스가 있는 화면의 위쪽 가운데. Spotlight 가 서는 자리와 비슷하다.
    /// 메뉴바 아이콘 밑에 붙이고 싶어도, 아이콘이 없을 때를 위한 창이라 붙을 데가 없다.
    private func place(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let area = screen?.visibleFrame else { return }

        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: area.midX - size.width / 2,
                                     y: area.maxY - size.height - 24))
    }

    // MARK: - NSWindowDelegate

    /// 다른 데를 누르면 닫는다. 메뉴바에서 열리는 패널과 같은 느낌으로.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}

/// 제목 없는 패널은 기본으로 글쇠를 받지 않는다.
/// 할 일을 쳐 넣어야 하는 창이라 받도록 연다.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
