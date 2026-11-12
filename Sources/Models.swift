import Foundation

/// 할 일의 우선순위. 저장은 Int 로 해서 나중에 단계를 늘려도 깨지지 않는다.
enum Priority: Int, Codable, CaseIterable, Hashable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    var label: String {
        switch self {
        case .none: return "없음"
        case .low: return "낮음"
        case .medium: return "보통"
        case .high: return "높음"
        }
    }

    /// 깃발을 눌렀을 때 돌아가는 차례. 없음 → 높음 → 보통 → 낮음 → 없음.
    var next: Priority {
        switch self {
        case .none: return .high
        case .high: return .medium
        case .medium: return .low
        case .low: return .none
        }
    }
}

/// 하위 할 일. 한 단계만 중첩한다.
struct Subtask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var done: Bool = false

    init(id: UUID = UUID(), title: String, done: Bool = false) {
        self.id = id
        self.title = title
        self.done = done
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
    }
}

struct TodoItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var done: Bool = false
    var priority: Priority = .none
    var note: String = ""
    var subtasks: [Subtask] = []
    var expanded: Bool = true
    /// 이 할 일이 속한 날. 늘 그 날 자정으로 맞춰 둔다.
    var day: Date = DayFormat.today
    var createdAt: Date = Date()

    var hasDetail: Bool { !note.isEmpty || !subtasks.isEmpty }
    var doneSubtaskCount: Int { subtasks.filter(\.done).count }

    init(id: UUID = UUID(), title: String, done: Bool = false, priority: Priority = .none,
         note: String = "", subtasks: [Subtask] = [], expanded: Bool = true,
         day: Date = DayFormat.today, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.done = done
        self.priority = priority
        self.note = note
        self.subtasks = subtasks
        self.expanded = expanded
        self.day = DayFormat.day(day)
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        priority = try c.decodeIfPresent(Priority.self, forKey: .priority) ?? .none
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        subtasks = try c.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
        expanded = try c.decodeIfPresent(Bool.self, forKey: .expanded) ?? true
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        // 날짜가 없던 시절에 저장된 파일은 오늘 할 일로 본다.
        // 만든 날로 흩뿌리면 쓰던 목록이 과거로 사라져 버린다.
        if let stored = try c.decodeIfPresent(Date.self, forKey: .day) {
            day = DayFormat.day(stored)
        } else {
            day = DayFormat.today
        }
    }
}

/// 디스크에 저장되는 최상위 구조. 나중에 필드를 더해도 하위 호환된다.
struct TodoFile: Codable {
    var version: Int = 2
    var items: [TodoItem] = []
}

/// 날짜를 옮긴 할 일 하나. 되돌릴 때 쓴다.
struct MovedDay {
    let id: UUID
    /// 옮기기 전의 날짜.
    let day: Date
}
