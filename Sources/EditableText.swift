import SwiftUI

/// 평소에는 Text 로 그리다가 클릭하면 TextField 로 바뀐다.
/// TextField 는 취소선·흐린 색 같은 텍스트 스타일을 받지 않기 때문에
/// 완료 표시를 제대로 보여 주려면 이렇게 나눠야 한다.
struct EditableText: View {
    @Binding var text: String
    var placeholder: String
    var size: CGFloat = 13
    var done: Bool = false

    @State private var editing = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if editing {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { editing = false }
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused { editing = false }
                    }
                    .onExitCommand { editing = false }
            } else {
                Text(text.isEmpty ? placeholder : text)
                    .foregroundColor(color)
                    .strikethrough(done, color: .secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { beginEditing() }
            }
        }
        .font(.system(size: size))
    }

    private var color: Color {
        if text.isEmpty { return Color.secondary.opacity(0.6) }
        return done ? .secondary : .primary
    }

    private func beginEditing() {
        editing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true }
    }
}
