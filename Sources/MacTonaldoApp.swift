import SwiftUI

@main
struct MacTonaldoApp: App {
    @StateObject private var store = TodoStore()

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
