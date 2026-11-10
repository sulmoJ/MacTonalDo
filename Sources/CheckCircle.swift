import SwiftUI

/// 할 일 / 하위 할 일에 공통으로 쓰는 체크박스.
struct CheckCircle: View {
    let done: Bool
    var size: CGFloat = 14

    var body: some View {
        Image(systemName: done ? "checkmark.circle.fill" : "circle")
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(done ? Color.accentColor : Color.secondary.opacity(0.65))
            .contentShape(Rectangle())
    }
}

/// 호버했을 때만 보이는 아이콘 버튼.
struct IconButton: View {
    let systemName: String
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
