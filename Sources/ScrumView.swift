import SwiftUI

/// 데일리 스크럼 미리보기.
/// 패널 안에서 할 일 목록 자리를 잠깐 대신한다.
/// 메뉴바 패널에서는 시트가 잘 뜨지 않아 화면을 통째로 바꾸는 쪽을 골랐다.
///
/// 이 화면은 두 가지 다른 일을 한다. 섞이지 않게 떼어 두었다.
///
/// 1. **글 복사** — 늘 한다. 지난 미완료도 글에는 늘 담긴다. 오늘 할 일이니까.
/// 2. **목록의 날짜 옮기기** — 고를 수 있다. 자료를 고치는 일이라 되돌릴 거리를 남긴다.
///
/// 단추 이름에 둘 다 적는다. 복사만 하는 줄 알았는데 목록이 바뀌어 있으면 안 된다.
struct ScrumView: View {
    @ObservedObject var store: TodoStore
    let week: WorkWeek
    let onClose: () -> Void

    /// 복사한 뒤 지난 미완료의 날짜를 오늘로 옮길지.
    /// 글의 내용과는 상관이 없다.
    @State private var movingAfterCopy = true
    /// 옮길 할 일의 제목을 펼쳐 보고 있는지.
    @State private var showingCarryOver = false
    @State private var outcome: Outcome?
    /// 알림을 지울 타이머를 가리는 표. 뒤늦은 타이머가 새 알림을 지우지 못하게 한다.
    @State private var outcomeToken = 0

    /// 복사를 마친 뒤 한 줄로 남기는 알림.
    private struct Outcome {
        /// 오늘로 옮긴 할 일들의 옛 날짜. 비어 있으면 복사만 한 것이다.
        let moved: [MovedDay]
    }

    private var report: ScrumReport {
        ScrumBuilder.report(items: store.items, week: week)
    }

    private var chromeBackground: Color { Color(nsColor: .windowBackgroundColor) }
    private var listBackground: Color { Color(nsColor: .textBackgroundColor) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            preview
            Divider()
            if let outcome {
                outcomeRow(outcome)
            } else {
                carryRow
            }
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

    /// 붙여 넣을 글 그대로. 아래 체크박스에 따라 달라지지 않는다.
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

    // MARK: - 날짜 옮기기 고르기

    @ViewBuilder
    private var carryRow: some View {
        let carry = report.carryOver
        if !carry.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Toggle(isOn: $movingAfterCopy) {
                    Text("복사한 뒤 지난 미완료 \(carry.count)개를 오늘 날짜로 옮기기")
                        .font(.system(size: 11))
                }
                .toggleStyle(.checkbox)

                HStack(spacing: 5) {
                    Text(movingAfterCopy
                         ? "내 목록이 바뀝니다 · 되돌릴 수 있습니다"
                         : "글만 복사합니다 · 목록은 그대로 둡니다")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Button(showingCarryOver ? "접기" : "어떤 건지 보기") {
                        withAnimation(.easeInOut(duration: 0.15)) { showingCarryOver.toggle() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                }
                .padding(.leading, 18)

                if showingCarryOver {
                    carryOverList(carry)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }

    /// 옮길 할 일이 어떤 것들인지. 며칠씩 묵은 게 섞여 있으면 여기서 보인다.
    private func carryOverList(_ carry: [TodoItem]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(carry) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        // 날짜보다 얼마나 밀렸는지가 눈에 들어와야 한다.
                        Text(DayFormat.age(item.day) ?? "")
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 42, alignment: .trailing)

                        Text(item.title)
                            .font(.system(size: 10))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .help(DayFormat.short(item.day))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
        }
        .frame(maxHeight: 76)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.09)))
        .padding(.leading, 18)
    }

    // MARK: - 끝난 뒤 알림

    /// 무엇을 했는지 끝난 뒤에도 말해 준다. 옮긴 게 있으면 되돌릴 수 있다.
    private func outcomeRow(_ outcome: Outcome) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)

            Text(outcome.moved.isEmpty
                 ? "복사했습니다"
                 : "복사했습니다 · \(outcome.moved.count)개를 오늘로 옮겼습니다")
                .font(.system(size: 11))

            Spacer()

            if !outcome.moved.isEmpty {
                Button("되돌리기") { undo(outcome) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - 단추

    private var actions: some View {
        HStack(spacing: 8) {
            Spacer()

            Button("닫기", action: onClose)

            Button(copyButtonTitle, action: copy)
                .keyboardShortcut(.defaultAction)
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// 단추가 할 일을 다 말하게 한다. 옮길 게 있고 옮기기로 해 두었으면 그 수까지.
    private var copyButtonTitle: String {
        let count = report.carryOver.count
        guard movingAfterCopy, count > 0 else { return "복사하기" }
        return "복사하고 \(count)개 옮기기"
    }

    // MARK: - 하는 일

    /// 글을 먼저 만들어 두고 나서 할 일을 옮긴다.
    /// 순서가 바뀌면 미리보기와 복사된 글이 어긋난다.
    private func copy() {
        let text = ScrumBuilder.text(report)
        let willMove = movingAfterCopy && !report.carryOver.isEmpty

        var moved: [MovedDay] = []
        if willMove {
            withAnimation(.easeInOut(duration: 0.2)) { moved = store.pullOverdueToToday() }
        }

        TodoExporter.copyToClipboard(text)
        show(Outcome(moved: moved))
    }

    private func undo(_ outcome: Outcome) {
        withAnimation(.easeInOut(duration: 0.2)) { store.restoreDays(outcome.moved) }
        // 되돌렸으니 다시 고를 수 있게 원래 화면으로 돌린다.
        outcomeToken += 1
        withAnimation(.easeOut(duration: 0.15)) { self.outcome = nil }
    }

    /// 알림을 띄우고 잠시 뒤 지운다.
    /// 되돌릴 게 있으면 누를 틈을 주어야 해서 더 오래 둔다.
    private func show(_ outcome: Outcome) {
        outcomeToken += 1
        let token = outcomeToken
        withAnimation(.easeOut(duration: 0.1)) { self.outcome = outcome }

        let linger: TimeInterval = outcome.moved.isEmpty ? 1.5 : 6
        DispatchQueue.main.asyncAfter(deadline: .now() + linger) {
            guard token == outcomeToken else { return }
            withAnimation(.easeIn(duration: 0.2)) { self.outcome = nil }
        }
    }
}
