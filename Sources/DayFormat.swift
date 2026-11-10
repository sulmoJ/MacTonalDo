import Foundation

/// 날짜를 "하루" 단위로만 다루기 위한 거들기.
/// 시각은 전부 버리고 그 날 자정으로 맞춘다. 비교도 하루 단위로만 한다.
enum DayFormat {
    static var calendar: Calendar { Calendar.current }

    /// 시각을 떼고 그 날 자정으로 맞춘다.
    static func day(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static var today: Date { day(Date()) }

    static func shifted(_ day: Date, by days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: day) ?? day
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// 오늘을 기준으로 며칠 떨어져 있는지. 어제는 -1, 내일은 1.
    static func offsetFromToday(_ date: Date) -> Int {
        calendar.dateComponents([.day], from: today, to: day(date)).day ?? 0
    }

    /// "오늘"처럼 부를 수 있으면 그 이름. 아니면 nil.
    static func nickname(_ date: Date) -> String? {
        switch offsetFromToday(date) {
        case 0: return "오늘"
        case -1: return "어제"
        case -2: return "그저께"
        case 1: return "내일"
        case 2: return "모레"
        default: return nil
        }
    }

    /// "11월 6일 (금)"
    static func short(_ date: Date) -> String {
        shortFormatter.string(from: date)
    }

    /// 머리말에 쓰는 이름. "오늘 · 11월 6일 (금)"
    static func headline(_ date: Date) -> String {
        guard let nick = nickname(date) else { return short(date) }
        return "\(nick) · \(short(date))"
    }

    /// 파일 이름에 쓰는 "2026-11-06"
    static func stamp(_ date: Date) -> String {
        stampFormatter.string(from: date)
    }

    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f
    }()

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

extension DayFormat {
    /// 기준 날짜보다 앞선 가장 가까운 작업일.
    /// 작업일 범위가 월~금이면 월요일의 전 작업일은 금요일이 된다.
    static func previousWorkday(before date: Date, week: WorkWeek) -> Date {
        var candidate = shifted(day(date), by: -1)
        var steps = 0
        // 범위가 아무리 좁아도 일주일 안에는 작업일이 있다. 혹시 몰라 걸어 둔 빗장이다.
        while !week.isWorkday(candidate), steps < 14 {
            candidate = shifted(candidate, by: -1)
            steps += 1
        }
        return candidate
    }
}
