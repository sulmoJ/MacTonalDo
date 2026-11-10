import SwiftUI

extension Priority {
    var color: Color {
        switch self {
        case .none: return .secondary
        case .low: return .gray
        case .medium: return .orange
        case .high: return .red
        }
    }
}

/// 우선순위 깃발. 누르면 다음 등급으로 돌아간다.
struct PriorityFlag: View {
    let priority: Priority
    let onCycle: () -> Void

    var body: some View {
        Button(action: onCycle) {
            Image(systemName: "flag.fill")
                .font(.system(size: 9))
                .foregroundStyle(priority.color)
                .frame(width: 13, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("우선순위 \(priority.label)")
    }
}
