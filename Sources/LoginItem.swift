import AppKit
import Foundation
import ServiceManagement

/// 로그인할 때 앱이 저절로 뜨게 하는 일.
///
/// 두 가지 길을 쓴다.
///
/// 1. `SMAppService` — 요즘 방식이다. 시스템 설정 → 일반 → 로그인 항목에 제대로 나오고
///    사용자가 거기서 바로 끌 수 있다. 다만 앱이 서명되지 않았거나 `/Applications` 밖
///    (내려받기 폴더, 빌드 폴더 같은 곳)에 있으면 등록이 거절되는 일이 잦다.
/// 2. LaunchAgent — `~/Library/LaunchAgents` 에 plist 를 하나 깐다.
///    서명을 따지지 않아서 1번이 막혔을 때도 통한다.
///
/// 1번을 먼저 시도하고, 거절당하면 2번으로 내려간다.
enum LoginItem {
    /// 지금 어느 쪽으로 켜져 있는지.
    enum Backend {
        case service
        case agent
        case off
    }

    static let agentLabel = "local.mactonaldo.login"

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(agentLabel).plist")
    }

    static var backend: Backend {
        if SMAppService.mainApp.status == .enabled { return .service }
        if FileManager.default.fileExists(atPath: agentURL.path) { return .agent }
        return .off
    }

    static var isEnabled: Bool { backend != .off }

    /// 켜거나 끈다. 잘 되면 `nil`, 안 되면 사람이 읽을 수 있는 까닭을 돌려준다.
    @discardableResult
    static func setEnabled(_ enable: Bool) -> String? {
        enable ? turnOn() : turnOff()
    }

    // MARK: - 켜기

    private static func turnOn() -> String? {
        if SMAppService.mainApp.status == .enabled { return nil }

        do {
            try SMAppService.mainApp.register()
            // 등록이 통했으면 예전에 깔아 둔 LaunchAgent 는 치운다. 두 번 뜨면 곤란하다.
            removeAgent()
            return nil
        } catch {
            // 서명이나 위치 때문에 거절당한 경우. LaunchAgent 로 돌아간다.
            if writeAgent() { return nil }
            return "자동 실행을 켜지 못했습니다. \(error.localizedDescription)"
        }
    }

    private static func turnOff() -> String? {
        var failure: String?

        if SMAppService.mainApp.status == .enabled {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                failure = "자동 실행을 끄지 못했습니다. \(error.localizedDescription)"
            }
        }

        removeAgent()
        return failure
    }

    // MARK: - LaunchAgent

    /// 지금 돌고 있는 앱을 가리키는 plist 를 깐다.
    /// 다음 로그인부터 먹는다. 지금 당장 한 벌 더 띄우지는 않는다.
    private static func writeAgent() -> Bool {
        let executable = Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS", isDirectory: true)
            .appendingPathComponent(Bundle.main.executableURL?.lastPathComponent ?? "MacTonalDo")

        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": [executable.path],
            "RunAtLoad": true,
            // 로그인 화면이나 데몬 자리에서는 띄우지 않는다. 사람이 쓰는 세션에서만.
            "LimitLoadToSessionType": "Aqua",
        ]

        let dir = agentURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist,
                                                             format: .xml, options: 0),
              (try? data.write(to: agentURL, options: .atomic)) != nil
        else { return false }

        return true
    }

    private static func removeAgent() {
        guard FileManager.default.fileExists(atPath: agentURL.path) else { return }

        // 이미 올라와 있으면 내려 둔다. 안 올라와 있으면 실패하는데, 그래도 상관없다.
        let unload = Process()
        unload.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        unload.arguments = ["bootout", "gui/\(getuid())/\(agentLabel)"]
        unload.standardOutput = FileHandle.nullDevice
        unload.standardError = FileHandle.nullDevice
        try? unload.run()
        unload.waitUntilExit()

        try? FileManager.default.removeItem(at: agentURL)
    }

    // MARK: - 첫 실행

    /// 메뉴바 앱은 떠 있지 않으면 쓸모가 없어서, 처음 켤 때 한 번 자동 실행을 걸어 둔다.
    /// 한 번만 한다. 사용자가 꺼 두면 다시 켜지 않는다.
    static func enableOnFirstRun() {
        let key = "didTryLaunchAtLoginOnce"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        guard !isEnabled else { return }
        setEnabled(true)
    }
}
