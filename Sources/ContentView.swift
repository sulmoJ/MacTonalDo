import SwiftUI
import UniformTypeIdentifiers

/// 메뉴바 아이콘을 누르면 열리는 패널 전체.
///
/// 배경은 일부러 불투명하게 칠한다. MenuBarExtra 의 기본 재질은 반투명이라
/// 뒤에 있는 창에 따라 글자 가독성이 들쭉날쭉해진다.
///
/// 목록은 늘 하루 분만 보여 준다. 패널을 열면 오늘로 돌아온다.
struct ContentView: View {
    @ObservedObject var store: TodoStore

    @AppStorage("hideCompleted") private var hideCompleted = false
    @AppStorage("workWeek") private var workWeekRaw = WorkWeek.weekdays.rawValue
    @State private var newTitle = ""
    @State private var justCopied = false
    @State private var draggingID: UUID?
    @State private var showingScrum = false
    @FocusState private var inputFocused: Bool

    private var workWeek: WorkWeek { WorkWeek.from(workWeekRaw) }

    /// 보고 있는 날짜의 할 일.
    private var dayItems: [TodoItem] { store.visibleItems }

    private var visible: [TodoItem] {
        hideCompleted ? dayItems.filter { !$0.done } : dayItems
    }

    private var isToday: Bool { store.isOnToday }

    /// 머리말·입력창·꼬리말에 쓰는 바탕색.
    private var chromeBackground: Color { Color(nsColor: .windowBackgroundColor) }
    /// 목록에 쓰는 바탕색. 글자 대비가 가장 높은 색이다.
    private var listBackground: Color { Color(nsColor: .textBackgroundColor) }

    var body: some View {
        Group {
            if showingScrum {
                ScrumView(store: store, week: workWeek) { showingScrum = false }
            } else {
                todoPanel
            }
        }
        .onAppear {
            draggingID = nil
            showingScrum = false
            // 열 때는 늘 오늘부터 본다.
            store.goToDay(DayFormat.today)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { inputFocused = true }
        }
    }

    private var todoPanel: some View {
        VStack(spacing: 0) {
            header
            dateBar
            Divider()
            overdueBar
            inputRow
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 340)
        .background(chromeBackground)
    }

    // MARK: - 머리말

    private var header: some View {
        HStack(spacing: 6) {
            Text("할 일")
                .font(.system(size: 13, weight: .semibold))

            let remaining = store.remainingCount(on: store.selectedDay)
            if remaining > 0 {
                Text("\(remaining)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.accentColor))
            }

            Spacer()

            scrumButton
            exportMenu

            Menu {
                Toggle("완료한 항목 숨기기", isOn: $hideCompleted)
                Button("이 날짜의 완료 항목 삭제") {
                    store.clearCompleted(on: store.selectedDay)
                }
                .disabled(store.doneCount(on: store.selectedDay) == 0)
                Divider()
                Button("우선순위 높은 순으로 정렬") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.sortByPriority(on: store.selectedDay)
                    }
                }
                .disabled(dayItems.count < 2)
                Divider()
                Menu("작업일 범위") {
                    ForEach(WorkWeek.allCases) { option in
                        Button { workWeekRaw = option.rawValue } label: {
                            if workWeek == option {
                                Label(option.menuLabel, systemImage: "checkmark")
                            } else {
                                Text(option.menuLabel)
                            }
                        }
                    }
                }
                Toggle("로그인할 때 자동 실행", isOn: launchAtLoginBinding)
                Button("저장 폴더 열기") { revealStorage() }
                Divider()
                Button("종료") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 20)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - 날짜 띠

    private var dateBar: some View {
        HStack(spacing: 0) {
            stepButton(-1, icon: "chevron.left", help: "전날 (⌘[)", key: "[")

            Spacer(minLength: 0)

            Text(DayFormat.headline(store.selectedDay))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isToday ? Color.primary : Color.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            stepButton(1, icon: "chevron.right", help: "다음날 (⌘])", key: "]")

            Button { store.goToDay(DayFormat.today) } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isToday ? Color.secondary.opacity(0.4) : Color.accentColor)
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 20)
            .contentShape(Rectangle())
            .disabled(isToday)
            .keyboardShortcut("t", modifiers: .command)
            .help("오늘로 (⌘T)")
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 7)
    }

    /// 날짜를 하루씩 넘기는 단추.
    private func stepButton(_ days: Int, icon: String, help: String, key: KeyEquivalent) -> some View {
        Button { store.stepDay(days) } label: {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .frame(width: 22, height: 20)
        .contentShape(Rectangle())
        .keyboardShortcut(key, modifiers: .command)
        .help(help)
    }

    // MARK: - 지난 미완료

    /// 오늘을 보고 있을 때만, 지난 날에 남은 일이 있으면 알려 준다.
    @ViewBuilder
    private var overdueBar: some View {
        if isToday, store.overdueCount > 0 {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)

                    Text("지난 미완료 \(store.overdueCount)개")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("오늘로 가져오기") {
                        withAnimation(.easeInOut(duration: 0.2)) { _ = store.pullOverdueToToday() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.12))

                Divider()
            }
        }
    }

    // MARK: - 데일리 스크럼

    /// 아이콘만으로는 무슨 단추인지 알기 어려워 글자를 넣었다.
    private var scrumButton: some View {
        Button { showingScrum = true } label: {
            Text("scrum")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.14)))
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .help("데일리 스크럼 (\u{2318}D)")
        .keyboardShortcut("d", modifiers: .command)
    }

    // MARK: - 내보내기

    private var exportMenu: some View {
        Menu {
            Section(DayFormat.headline(store.selectedDay)) {
                Button("텍스트로 복사") { copyDay(.plain, onlyRemaining: false) }
                Button("마크다운으로 복사") { copyDay(.markdown, onlyRemaining: false) }
                Button("남은 할 일만 복사") { copyDay(.plain, onlyRemaining: true) }
            }
            .disabled(dayItems.isEmpty)

            Section("전체 날짜") {
                Button("마크다운으로 복사") { copyAll(.markdown) }
                Button("파일로 저장…") { saveToFile() }
            }
        } label: {
            Image(systemName: justCopied ? "checkmark" : "square.and.arrow.up")
                .font(.system(size: 12))
                .foregroundStyle(justCopied ? Color.accentColor : Color.primary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 20)
        .disabled(store.items.isEmpty)
        .help("할 일 목록 내보내기")
    }

    /// 보고 있는 날짜만 복사한다.
    private func copyDay(_ format: ExportFormat, onlyRemaining: Bool) {
        let text = TodoExporter.text(items: dayItems,
                                     format: format,
                                     onlyRemaining: onlyRemaining,
                                     dayTitle: DayFormat.short(store.selectedDay))
        TodoExporter.copyToClipboard(text)
        flashCopied()
    }

    /// 날짜별로 묶어 전부 복사한다.
    private func copyAll(_ format: ExportFormat) {
        let text = TodoExporter.grouped(items: store.items,
                                        format: format,
                                        onlyRemaining: false)
        TodoExporter.copyToClipboard(text)
        flashCopied()
    }

    private func saveToFile() {
        let text = TodoExporter.grouped(items: store.items,
                                        format: .markdown,
                                        onlyRemaining: false)
        TodoExporter.saveToFile(text, suggestedName: "\(DayFormat.stamp(DayFormat.today)) 할 일.md")
    }

    /// 복사했다는 걸 아이콘으로 잠깐 알려 준다.
    private func flashCopied() {
        withAnimation(.easeOut(duration: 0.1)) { justCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.2)) { justCopied = false }
        }
    }

    // MARK: - 입력

    private var inputRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            TextField(inputPlaceholder, text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($inputFocused)
                .onSubmit(addTodo)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// 지금 보고 있는 날짜에 붙는다는 걸 입력창에서 알려 준다.
    private var inputPlaceholder: String {
        isToday ? "새 할 일 입력 후 Enter" : "\(DayFormat.short(store.selectedDay))에 추가"
    }

    private func addTodo() {
        store.add(title: newTitle)
        newTitle = ""
        inputFocused = true
    }

    // MARK: - 목록

    private var list: some View {
        Group {
            if visible.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(visible) { item in
                            TodoRowView(store: store,
                                        item: store.binding(for: item.id),
                                        draggingID: $draggingID)
                                .id(item.id)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                }
                .frame(maxHeight: 420)
            }
        }
        .frame(maxWidth: .infinity)
        .background(listBackground)
        .onDrop(of: [.text], delegate: ReorderCancelDropDelegate(draggingID: $draggingID))
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text(emptyMessage)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var emptyMessage: String {
        if !dayItems.isEmpty { return "남은 할 일이 없어요" }
        if isToday { return "오늘 할 일이 없어요" }
        return "\(DayFormat.short(store.selectedDay))에는 할 일이 없어요"
    }

    // MARK: - 꼬리말

    private var footer: some View {
        let done = store.doneCount(on: store.selectedDay)
        let total = dayItems.count

        return HStack(spacing: 8) {
            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .progressViewStyle(.linear)
                .frame(height: 4)

            Text("\(done)/\(total)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: - 거들기

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { LoginItem.isEnabled },
            set: { enable in
                guard let problem = LoginItem.setEnabled(enable) else { return }

                let alert = NSAlert()
                alert.messageText = problem
                alert.informativeText = "시스템 설정 → 일반 → 로그인 항목에서 직접 추가할 수 있습니다."
                alert.alertStyle = .warning
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        )
    }

    private func revealStorage() {
        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
    }
}
