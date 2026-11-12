import Foundation

/// 한 주에서 "일하는 날"로 치는 범위.
/// 데일리 스크럼이 어디까지 거슬러 올라가 완료한 일을 모을지 정한다.
enum WorkWeek: String, CaseIterable, Identifiable {
    case weekdays
    case everyday

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekdays: return "월~금"
        case .everyday: return "월~일"
        }
    }

    var menuLabel: String {
        switch self {
        case .weekdays: return "월~금 (주말 빼고)"
        case .everyday: return "월~일 (매일)"
        }
    }

    func isWorkday(_ date: Date) -> Bool {
        switch self {
        case .everyday:
            return true
        case .weekdays:
            // 1 = 일요일, 7 = 토요일
            let weekday = DayFormat.calendar.component(.weekday, from: date)
            return weekday != 1 && weekday != 7
        }
    }

    static func from(_ raw: String) -> WorkWeek {
        WorkWeek(rawValue: raw) ?? .weekdays
    }
}

/// 데일리 스크럼 한 판.
struct ScrumReport {
    /// 완료한 일을 모으기 시작한 날. 곧 전 작업일이다.
    let since: Date
    let today: Date
    /// 전 작업일부터 어제까지 끝낸 일.
    let done: [TodoItem]
    /// 오늘 진행할 일.
    let todo: [TodoItem]
    /// 오늘로 끌어올 수 있는 지난 미완료.
    let carryOver: [TodoItem]
}

enum ScrumBuilder {

    /// 전 작업일부터 어제까지 끝낸 일과, 오늘 진행할 일을 모은다.
    ///
    /// 지난 미완료는 `진행할 일` 에 늘 담는다. 날짜가 어제로 남아 있든 오늘로 옮겼든
    /// 오늘 할 일인 것은 같기 때문이다. 목록의 날짜를 실제로 옮기는 일
    /// (`TodoStore.pullOverdueToToday()`) 은 글의 내용과 상관없이 따로 고른다.
    static func report(items: [TodoItem],
                       today: Date = DayFormat.today,
                       week: WorkWeek) -> ScrumReport {
        let today = DayFormat.day(today)
        let since = DayFormat.previousWorkday(before: today, week: week)
        let yesterday = DayFormat.shifted(today, by: -1)

        // 전 작업일부터 어제까지. 금요일 다음 월요일이면 주말에 끝낸 일도 함께 담긴다.
        let done = items.filter {
            let day = DayFormat.day($0.day)
            return $0.done && day >= since && day <= yesterday
        }

        let carryOver = items.filter { !$0.done && DayFormat.day($0.day) < today }

        // 오늘까지의 미완료를 적어 둔 순서 그대로. 오늘 이미 체크한 일은 빼고.
        let todo = items.filter { !$0.done && DayFormat.day($0.day) <= today }

        return ScrumReport(since: since, today: today, done: done, todo: todo, carryOver: carryOver)
    }

    /// 슬랙·메신저에 그대로 붙여 넣는 글.
    static func text(_ report: ScrumReport) -> String {
        section("완료한 일", items: report.done, keepSubtask: { $0.done })
            + "\n\n\n"
            + section("진행할 일", items: report.todo, keepSubtask: { !$0.done })
    }

    /// 하위 할 일은 한 칸 들여서 함께 적는다.
    /// 완료한 일에는 끝낸 하위만, 진행할 일에는 남은 하위만 담는다.
    private static func section(_ title: String,
                                items: [TodoItem],
                                keepSubtask: (Subtask) -> Bool) -> String {
        var lines = [title, ""]
        guard !items.isEmpty else {
            lines.append("없음")
            return lines.joined(separator: "\n")
        }
        for item in items {
            lines.append("* \(item.title)")
            for sub in item.subtasks where keepSubtask(sub) {
                lines.append("  * \(sub.title)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
