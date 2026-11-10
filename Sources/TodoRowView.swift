import SwiftUI
import UniformTypeIdentifiers

/// 할 일 한 줄. 메모와 하위 할 일을 펼쳐서 함께 보여 준다.
struct TodoRowView: View {
    @ObservedObject var store: TodoStore
    @Binding var item: TodoItem
    @Binding var draggingID: UUID?

    @State private var hovering = false
    @State private var showNote = false
    @State private var addingSub = false
    @State private var subDraft = ""
    @FocusState private var subFocused: Bool

    private var id: UUID { item.id }
    private var noteVisible: Bool { showNote || !item.note.isEmpty }
    private var isDragging: Bool { draggingID == id }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            titleRow
            if item.expanded {
                if noteVisible { noteEditor }
                ForEach(item.subtasks) { sub in
                    SubtaskRowView(
                        title: subtaskTitleBinding(sub.id),
                        done: sub.done,
                        onToggle: { store.toggleSubtask(todo: id, sub: sub.id) },
                        onDelete: { store.deleteSubtask(todo: id, sub: sub.id) }
                    )
                    .padding(.leading, 42)
                }
                if addingSub { subDraftRow }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovering && !isDragging ? Color.primary.opacity(0.06) : Color.clear)
        )
        .opacity(isDragging ? 0.35 : 1)
        .onHover { hovering = $0 }
        .onAppear { showNote = !item.note.isEmpty }
        .onDrop(of: [.text],
                delegate: ReorderDropDelegate(targetID: id,
                                              draggingID: $draggingID,
                                              store: store))
        .contextMenu { rowMenu }
    }

    // MARK: - 제목 줄

    private var titleRow: some View {
        HStack(spacing: 5) {
            dragHandle
            disclosure

            Button { store.toggleDone(id) } label: { CheckCircle(done: item.done) }
                .buttonStyle(.plain)

            if item.priority != .none {
                PriorityFlag(priority: item.priority) { cyclePriority() }
            }

            EditableText(text: $item.title, placeholder: "할 일", size: 13, done: item.done)

            if !item.subtasks.isEmpty {
                Text("\(item.doneSubtaskCount)/\(item.subtasks.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }

            if hovering {
                IconButton(systemName: "plus", help: "하위 할 일 추가") { startAddingSub() }
                Menu {
                    rowMenu
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 16)
            }
        }
    }

    /// 드래그는 이 손잡이에서만 시작한다.
    /// 줄 전체에 걸면 제목을 눌러 고치려다 끌려 버린다.
    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.tertiary)
            .frame(width: 12, height: 18)
            .contentShape(Rectangle())
            .opacity(hovering ? 1 : 0)
            .onDrag {
                draggingID = id
                return NSItemProvider(object: id.uuidString as NSString)
            }
            .help("끌어서 순서 바꾸기")
    }

    @ViewBuilder
    private var disclosure: some View {
        if item.hasDetail {
            Button {
                withAnimation(.easeInOut(duration: 0.12)) { item.expanded.toggle() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(item.expanded ? 90 : 0))
                    .frame(width: 10)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 10, height: 1)
        }
    }

    // MARK: - 메모

    private var noteEditor: some View {
        TextField("메모", text: $item.note, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1...6)
            .padding(.leading, 46)
            .padding(.trailing, 4)
    }

    // MARK: - 하위 할 일

    private func subtaskTitleBinding(_ subID: UUID) -> Binding<String> {
        Binding(
            get: { item.subtasks.first { $0.id == subID }?.title ?? "" },
            set: { newValue in
                guard let k = item.subtasks.firstIndex(where: { $0.id == subID }) else { return }
                item.subtasks[k].title = newValue
            }
        )
    }

    private var subDraftRow: some View {
        HStack(spacing: 5) {
            CheckCircle(done: false, size: 12)
            TextField("하위 할 일", text: $subDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($subFocused)
                .onSubmit { commitSub() }
                .onExitCommand { addingSub = false; subDraft = "" }
        }
        .padding(.leading, 42)
    }

    private func startAddingSub() {
        item.expanded = true
        addingSub = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { subFocused = true }
    }

    private func commitSub() {
        let text = subDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        subDraft = ""
        guard !text.isEmpty else { addingSub = false; return }
        store.addSubtask(to: id, title: text)
        // 연달아 더 넣을 수 있도록 입력창을 열어 둔다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { subFocused = true }
    }

    private func cyclePriority() {
        store.setPriority(item.priority.next, for: id)
    }

    // MARK: - 날짜

    /// 다른 날로 옮기는 메뉴. 옮기면 지금 보고 있는 날짜에서 바로 빠진다.
    @ViewBuilder
    private var dayMenu: some View {
        Menu("날짜 옮기기") {
            ForEach([-1, 0, 1], id: \.self) { offset in
                let target = DayFormat.shifted(DayFormat.today, by: offset)
                Button {
                    store.setDay(target, for: id)
                } label: {
                    let name = DayFormat.nickname(target) ?? DayFormat.short(target)
                    if DayFormat.isSameDay(item.day, target) {
                        Label("\(name)로", systemImage: "checkmark")
                    } else {
                        Text("\(name)로")
                    }
                }
            }
            Divider()
            Button("하루 앞으로") { store.shiftDay(id, by: -1) }
            Button("하루 뒤로") { store.shiftDay(id, by: 1) }
        }
    }

    // MARK: - 메뉴

    @ViewBuilder
    private var rowMenu: some View {
        Menu("우선순위") {
            ForEach([Priority.high, .medium, .low, .none], id: \.self) { level in
                Button {
                    store.setPriority(level, for: id)
                } label: {
                    if item.priority == level {
                        Label(level.label, systemImage: "checkmark")
                    } else {
                        Text(level.label)
                    }
                }
            }
        }
        dayMenu
        Divider()
        Button("하위 할 일 추가") { startAddingSub() }
        Button(noteVisible ? "메모 지우기" : "메모 추가") {
            if noteVisible {
                item.note = ""
                showNote = false
            } else {
                item.expanded = true
                showNote = true
            }
        }
        Divider()
        Button("위로 이동") { store.move(id, by: -1) }
        Button("아래로 이동") { store.move(id, by: 1) }
        Divider()
        Button("삭제") { store.delete(id) }
    }
}

/// 하위 할 일 한 줄.
private struct SubtaskRowView: View {
    @Binding var title: String
    let done: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 5) {
            Button(action: onToggle) { CheckCircle(done: done, size: 12) }
                .buttonStyle(.plain)

            EditableText(text: $title, placeholder: "하위 할 일", size: 12, done: done)

            if hovering {
                IconButton(systemName: "xmark", help: "삭제", action: onDelete)
            }
        }
        .onHover { hovering = $0 }
        .contextMenu {
            Button("삭제") { onDelete() }
        }
    }
}
