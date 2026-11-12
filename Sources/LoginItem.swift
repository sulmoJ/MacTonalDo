import AppKit
import Foundation
import ServiceManagement
import os

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
///
/// 켜 두는 일은 한 번으로 끝나지 않는다. 앱이 다른 폴더로 옮겨 가면 옛 등록은
/// 못 쓰게 되고, LaunchAgent 는 사라진 경로를 가리킨다. 그래서 `ensureEnabled()` 를
/// 실행할 때마다 불러 지금 자리로 다시 걸어 둔다. 사용자가 손수 끈 경우만 빼고.
enum LoginItem {
    /// 지금 어느 쪽으로 켜져 있는지.
    enum Backend {
        /// `SMAppService` 로 켜져 있다.
        case service
        /// 등록은 됐고, 시스템 설정에서 사용자가 켜 주기를 기다린다.
        case serviceNeedsApproval
        /// LaunchAgent 로 켜져 있다.
        case agent
        case off
    }

    static let agentLabel = "local.mactonaldo.login"

    /// 사용자가 손수 끈 적이 있는지. 이 깃발이 서 있으면 다시 켜지 않는다.
    private static let optOutKey = "launchAtLoginOptOut"
    /// 1.0.0 이 쓰던 깃발. '한 번 해 봤다' 는 뜻이라 앱이 옮겨 가도 다시 걸지 못했다.
    private static let legacyTriedKey = "didTryLaunchAtLoginOnce"

    private static let log = Logger(subsystem: "local.mactonaldo", category: "login")

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(agentLabel).plist")
    }

    /// 지금 돌고 있는 앱의 실행 파일. LaunchAgent 가 가리켜야 할 자리다.
    private static var executableURL: URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS", isDirectory: true)
            .appendingPathComponent(Bundle.main.executableURL?.lastPathComponent ?? "MacTonalDo")
    }

    static var backend: Backend {
        switch SMAppService.mainApp.status {
        case .enabled: return .service
        case .requiresApproval: return .serviceNeedsApproval
        default: break
        }
        if FileManager.default.fileExists(atPath: agentURL.path) { return .agent }
        return .off
    }

    static var isEnabled: Bool { backend != .off }

    /// 켜거나 끈다. 잘 되면 `nil`, 안 되면 사람이 읽을 수 있는 까닭을 돌려준다.
    @discardableResult
    static func setEnabled(_ enable: Bool) -> String? {
        // 사용자가 손수 건드린 것이니 그 뜻을 적어 둔다.
        UserDefaults.standard.set(!enable, forKey: optOutKey)
        return enable ? turnOn() : turnOff()
    }

    // MARK: - 켜기

    private static func turnOn() -> String? {
        if SMAppService.mainApp.status == .enabled { return nil }

        do {
            try SMAppService.mainApp.register()
            // 등록이 통했으면 예전에 깔아 둔 LaunchAgent 는 치운다. 두 번 뜨면 곤란하다.
            removeAgent()
            log.notice("SMAppService 로 걸었다")
            return nil
        } catch {
            // 서명이나 위치 때문에 거절당한 경우. LaunchAgent 로 돌아간다.
            log.notice("SMAppService 거절: \(error.localizedDescription, privacy: .public)")
            if writeAgent() {
                log.notice("LaunchAgent 로 걸었다")
                return nil
            }
            log.error("LaunchAgent 도 못 깔았다")
            return "자동 실행을 켜지 못했습니다. \(error.localizedDescription)"
        }
    }

    private static func turnOff() -> String? {
        var failure: String?

        if SMAppService.mainApp.status != .notRegistered {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                failure = "자동 실행을 끄지 못했습니다. \(error.localizedDescription)"
            }
        }

        removeAgent()
        if let failure { log.error("끄는 중 실패: \(failure, privacy: .public)") }
        else { log.notice("껐다") }
        return failure
    }

    // MARK: - LaunchAgent

    /// 지금 돌고 있는 앱을 가리키는 plist 를 깐다.
    /// 다음 로그인부터 먹는다. 지금 당장 한 벌 더 띄우지는 않는다.
    private static func writeAgent() -> Bool {
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": [executableURL.path],
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

    /// LaunchAgent 가 지금 이 앱을 가리키고 있는지. 앱이 옮겨 가면 어긋난다.
    private static func agentPointsHere() -> Bool {
        guard let data = try? Data(contentsOf: agentURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any],
              let args = dict["ProgramArguments"] as? [String],
              let first = args.first
        else { return false }
        return first == executableURL.path
    }

    // MARK: - 실행할 때마다

    /// 메뉴바 앱은 떠 있지 않으면 쓸모가 없어서, 자동 실행을 기본으로 걸어 둔다.
    /// 사용자가 손수 끈 적이 있으면 건드리지 않는다.
    ///
    /// 실행할 때마다 부른다. 한 번만 걸고 끝내면, 앱이 다른 폴더로 옮겨 간 뒤에는
    /// 사라진 경로를 가리키는 등록만 남아 아무 일도 일어나지 않는다.
    static func ensureEnabled() {
        let defaults = UserDefaults.standard

        // 1.0.0 의 '한 번 해 봤다' 깃발은 끄겠다는 뜻이 아니었으니 치운다.
        if defaults.object(forKey: legacyTriedKey) != nil {
            defaults.removeObject(forKey: legacyTriedKey)
            log.notice("옛 깃발(didTryLaunchAtLoginOnce) 치움")
        }

        guard !defaults.bool(forKey: optOutKey) else {
            log.notice("사용자가 꺼 둔 상태. 건드리지 않는다")
            return
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            // 켜져 있다. 옛 LaunchAgent 가 함께 남아 있으면 두 벌 뜨니 치운다.
            if FileManager.default.fileExists(atPath: agentURL.path) {
                log.notice("SMAppService 로 켜져 있어 남은 LaunchAgent 치움")
                removeAgent()
            } else {
                log.notice("이미 켜져 있다 (SMAppService)")
            }

        case .requiresApproval:
            log.notice("등록됨. 시스템 설정 → 로그인 항목에서 켜 주기를 기다린다")

        default:
            // 등록이 없거나 지금 번들을 못 찾는다. LaunchAgent 가 제 자리를
            // 가리키고 있으면 그걸 믿고, 아니면 지금 자리로 다시 건다.
            if agentPointsHere() {
                log.notice("LaunchAgent 로 켜져 있다")
            } else {
                log.notice("안 걸려 있다. 지금 자리로 건다: \(executableURL.path, privacy: .public)")
                _ = turnOn()
            }
        }
    }
}
