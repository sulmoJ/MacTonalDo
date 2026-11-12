import SwiftUI

@main
struct MacTonalDoApp: App {
    @StateObject private var store = TodoStore()

    init() {
        // 메뉴바 앱은 떠 있어야 쓸모가 있다. 자동 실행을 걸어 둔다.
        // 실행할 때마다 부른다 — 앱이 옮겨 가면 옛 등록은 못 쓰기 때문이다.
        LoginItem.ensureEnabled()
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
        } label: {
            MenuBarLabel(remaining: store.pendingCount)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 메뉴바에 올라가는 아이콘.
/// 오늘 남은 일과 지난 미완료를 합쳐서 보여 준다. 내일 일은 세지 않는다.
struct MenuBarLabel: View {
    let remaining: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: remaining == 0 ? "checklist.checked" : "checklist")
            if remaining > 0 {
                Text("\(remaining)")
                    .font(.system(size: 11, weight: .medium))
            }
        }
    }
}
