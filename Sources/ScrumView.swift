import SwiftUI

/// 데일리 스크럼 미리보기.
/// 패널 안에서 할 일 목록 자리를 잠깐 대신한다.
/// 메뉴바 패널에서는 시트가 잘 뜨지 않아 화면을 통째로 바꾸는 쪽을 골랐다.
struct ScrumView: View {
    @ObservedObject var store: TodoStore
    let week: WorkWeek
    let onClose: () -> Void

    @State private var carryingOver = true
    @State private var justCopied = false

    private var report: ScrumReport {
        ScrumBuilder.report(items: store.items, week: week, carryingOver: carryingOver)
    }

    private var chromeBackground: Color { Color(nsColor: .windowBackgroundColor) }
    private var listBackground: Color { Color(nsColor: .textBackgroundColor) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            preview
            Divider()
            carryRow
            actions
        }
        .frame(width: 340)
        .background(chromeBackground)
    }

    // MARK: - 머리말

    private var header: some View {
        let report = self.report

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 18)
                .contentShape(Rectangle())
                .keyboardShortcut(.escape, modifiers: [])
                .help("할 일 목록으로 (Esc)")

                Text("데일리 스크럼")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text(week.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }

            HStack(spacing: 4) {
                Text("\(DayFormat.short(report.since)) → \(DayFormat.short(report.today))")
                Text("·")
                Text("완료 \(report.done.count) · 진행 \(report.todo.count)")
                    .monospacedDigit()
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(.leading, 22)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 미리보기

    private var preview: some View {
        ScrollView {
            Text(ScrumBuilder.text(report))
                .font(.system(size: 12))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .frame(maxHeight: 340)
        .background(listBackground)
    }

    // MARK: - 지난 미완료 끌어오기

    @ViewBuilder
    private var carryRow: some View {
        let carry = report.carryOver
        if !carry.isEmpty || carryingOver {
            Toggle(isOn: $carryingOver) {
                Text(carry.isEmpty
                     ? "지난 미완료 없음"
                     : "지난 미완료 \(carry.count)개를 오늘로 가져오기")
                    .font(.system(size: 11))
                    .foregroundStyle(carry.isEmpty ? Color.secondary : Color.primary)
            }
            .toggleStyle(.checkbox)
            .disabled(carry.isEmpty)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }

    // MARK: - 단추

    private var actions: some View {
        HStack(spacing: 8) {
            Spacer()

            Button("닫기", action: onClose)

            Button(justCopied ? "복사됨" : "복사하기", action: copy)
                .keyboardShortcut(.defaultAction)
                .disabled(justCopied)
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// 글을 먼저 만들어 두고 나서 할 일을 옮긴다.
    /// 순서가 바뀌면 미리보기와 복사된 글이 어긋난다.
    private func copy() {
        let snapshot = report
        let text = ScrumBuilder.text(snapshot)

        if carryingOver && !snapshot.carryOver.isEmpty {
            withAnimation(.easeInOut(duration: 0.2)) { store.pullOverdueToToday() }
        }

        TodoExporter.copyToClipboard(text)

        withAnimation(.easeOut(duration: 0.1)) { justCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.2)) { justCopied = false }
        }
    }
}
