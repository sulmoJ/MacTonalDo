import AppKit
import Carbon.HIToolbox
import os

/// 어느 앱을 쓰고 있든 듣는 단축키 하나.
///
/// Carbon 의 `RegisterEventHotKey` 를 쓴다. 낡아 보이지만 이유가 있다.
/// `NSEvent.addGlobalMonitorForEvents` 는 손쉬운 사용(Accessibility) 권한을
/// 요구해서, 깔자마자 시스템 설정으로 보내 체크를 받아야 듣기 시작한다.
/// 메뉴바에 아이콘이 없어서 앱을 못 여는 사람에게 그 안내를 띄울 자리가
/// 마땅치 않다. Carbon 쪽은 권한 없이 바로 듣는다.
///
/// 등록은 조용히 실패할 수 있다 — 다른 앱이 같은 조합을 먼저 차지했을 때다.
/// 그래서 실패를 로그로 남긴다. `log show --predicate 'subsystem == "local.mactonaldo"'`
final class Hotkey {
    /// 눌렸을 때 할 일. 늘 주 스레드에서 부른다.
    private let action: () -> Void
    private let id: UInt32
    private var ref: EventHotKeyRef?

    /// Carbon 의 콜백은 C 함수 포인터라 바깥 값을 담지 못한다.
    /// 그래서 번호로 자기 자신을 되찾도록 여기에 적어 둔다.
    private static var byID: [UInt32: Hotkey] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false
    /// 네 글자 서명 'MTDo'. 다른 앱의 단축키와 섞이지 않게 하는 표식이다.
    private static let signature: OSType = 0x4D54446F

    private static let log = Logger(subsystem: "local.mactonaldo", category: "hotkey")

    /// `keyCode` 는 `kVK_ANSI_T` 같은 가상 키 번호,
    /// `modifiers` 는 `cmdKey | optionKey` 처럼 Carbon 의 조합값이다.
    /// 자리를 잡지 못하면 `nil` 을 준다.
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        self.id = Hotkey.nextID
        Hotkey.nextID += 1

        Hotkey.installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: Hotkey.signature, id: id)
        var created: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &created)

        guard status == noErr, let created else {
            Hotkey.log.notice("단축키를 못 잡았다 (status \(status)). 다른 앱이 쓰고 있을 수 있다")
            return nil
        }

        ref = created
        Hotkey.byID[id] = self
        Hotkey.log.notice("단축키를 잡았다")
    }

    deinit { unregister() }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        Hotkey.byID[id] = nil
    }

    /// 눌림을 받아 줄 손을 한 번만 달아 둔다.
    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            guard let event else { return OSStatus(eventNotHandledErr) }

            var pressed = EventHotKeyID()
            let err = GetEventParameter(event,
                                        EventParamName(kEventParamDirectObject),
                                        EventParamType(typeEventHotKeyID),
                                        nil,
                                        MemoryLayout<EventHotKeyID>.size,
                                        nil,
                                        &pressed)
            guard err == noErr else { return err }
            guard let hotkey = Hotkey.byID[pressed.id] else {
                return OSStatus(eventNotHandledErr)
            }

            DispatchQueue.main.async { hotkey.action() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}

/// 기본으로 잡아 두는 조합. ⌃⌥⌘T.
///
/// 셋을 다 겹친 건 일부러다. 둘짜리 조합은 이미 임자가 많아서,
/// 남의 단축키를 빼앗으면 그쪽이 조용히 먹통이 된다.
enum DefaultHotkey {
    static let keyCode = UInt32(kVK_ANSI_T)
    static let modifiers = UInt32(controlKey | optionKey | cmdKey)
    /// 사람에게 보여 줄 때 쓰는 모양.
    static let label = "⌃⌥⌘T"
}
