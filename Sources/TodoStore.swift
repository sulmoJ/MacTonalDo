import Foundation
import Combine
import SwiftUI

/// 할 일 목록의 단일 소스. 변경이 멈추면 JSON 으로 저장한다.
final class TodoStore: ObservableObject {
    @Published var items: [TodoItem] = []
    /// 패널이 지금 보여 주고 있는 날. 패널을 열 때마다 오늘로 돌아간다.
    @Published var selectedDay: Date = DayFormat.today

    let fileURL: URL
    private var cancellables = Set<AnyCancellable>()

    /// `fileURL` 을 주면 그 파일을 쓴다. 미리보기나 테스트에서 진짜 자료를 건드리지 않으려는 구멍이다.
    init(fileURL override: URL? = nil) {
        if let override {
            try? FileManager.default.createDirectory(at: override.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            fileURL = override
        } else {
            let support = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let dir = support.appendingPathComponent("macTonaldo", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            fileURL = dir.appendingPathComponent("todos.json")
            Self.bringOverLegacyStore(into: fileURL, under: support)
        }

        load()

        $items
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.save() }
            .store(in: &cancellables)
    }

    // MARK: - 저장소

    /// 앱 이름이 MenuTodo 이던 시절의 자료를 새 폴더로 한 번 베껴 온다.
    /// 옮기지 않고 베끼는 건, 새 이름으로 뭔가 어긋나도 옛 파일이 그대로 남아 있게 하려는 것이다.
    private static func bringOverLegacyStore(into newURL: URL, under support: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: newURL.path) else { return }

        let legacy = support
            .appendingPathComponent("MenuTodo", isDirectory: true)
            .appendingPathComponent("todos.json")
        guard fm.fileExists(atPath: legacy.path) else { return }

        try? fm.copyItem(at: legacy, to: newURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(TodoFile.self, from: data) else { return }
        items = file.items
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(TodoFile(items: items)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - 조회

    private func index(of id: UUID) -> Int? {
        items.firstIndex { $0.id == id }
    }

    /// 그 날에 속한 할 일. 저장된 순서를 그대로 지킨다.
    func items(on day: Date) -> [TodoItem] {
        let target = DayFormat.day(day)
        return items.filter { DayFormat.isSameDay($0.day, target) }
    }

    /// 보고 있는 날의 할 일.
    var visibleItems: [TodoItem] { items(on: selectedDay) }

    func totalCount(on day: Date) -> Int { items(on: day).count }
    func doneCount(on day: Date) -> Int { items(on: day).filter(\.done).count }
    func remainingCount(on day: Date) -> Int { items(on: day).filter { !$0.done }.count }

    /// 메뉴바에 띄우는 수. 오늘 할 일과 지난 미완료를 함께 센다.
    /// 지난 일이 그냥 묻히지 않게 하려는 뜻이다.
    var pendingCount: Int {
        let today = DayFormat.today
        return items.filter { !$0.done && $0.day <= today }.count
    }

    /// 오늘보다 앞선 날에 남아 있는 할 일의 수.
    var overdueCount: Int {
        let today = DayFormat.today
        return items.filter { !$0.done && $0.day < today }.count
    }

    /// 같은 날에 속한 항목들의 전체 배열 위 자리.
    private func slots(on day: Date) -> [Int] {
        let target = DayFormat.day(day)
        return items.indices.filter { DayFormat.isSameDay(items[$0].day, target) }
    }

    // MARK: - 날짜 넘기기

    func goToDay(_ day: Date) {
        selectedDay = DayFormat.day(day)
    }

    func stepDay(_ days: Int) {
        selectedDay = DayFormat.shifted(selectedDay, by: days)
    }

    var isOnToday: Bool { DayFormat.isSameDay(selectedDay, DayFormat.today) }

    /// id 로 찾아 쓰는 바인딩. 인덱스가 밀려도 안전하다.
    func binding(for id: UUID) -> Binding<TodoItem> {
        Binding(
            get: { [weak self] in
                self?.items.first { $0.id == id } ?? TodoItem(title: "")
            },
            set: { [weak self] newValue in
                guard let self, let i = self.index(of: id) else { return }
                self.items[i] = newValue
            }
        )
    }

    // MARK: - 변경

    @discardableResult
    func add(title: String) -> UUID? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // 새 할 일은 지금 보고 있는 날짜에 붙는다.
        let item = TodoItem(title: trimmed, day: selectedDay)
        items.append(item)
        return item.id
    }

    /// 할 일을 토글하면 하위 할 일도 같은 상태로 따라간다.
    func toggleDone(_ id: UUID) {
        guard let i = index(of: id) else { return }
        let next = !items[i].done
        items[i].done = next
        for k in items[i].subtasks.indices {
            items[i].subtasks[k].done = next
        }
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// 같은 날짜 안에서만 위아래로 옮긴다.
    func move(_ id: UUID, by offset: Int) {
        guard let i = index(of: id) else { return }
        let sameDay = slots(on: items[i].day)
        guard let pos = sameDay.firstIndex(of: i),
              sameDay.indices.contains(pos + offset) else { return }
        items.swapAt(i, sameDay[pos + offset])
    }

    func clearCompleted(on day: Date) {
        let target = DayFormat.day(day)
        items.removeAll { $0.done && DayFormat.isSameDay($0.day, target) }
    }

    // MARK: - 날짜 옮기기

    func setDay(_ day: Date, for id: UUID) {
        guard let i = index(of: id) else { return }
        items[i].day = DayFormat.day(day)
    }

    func shiftDay(_ id: UUID, by days: Int) {
        guard let i = index(of: id) else { return }
        items[i].day = DayFormat.shifted(items[i].day, by: days)
    }

    /// 지난 날에 안 끝난 채 남아 있는 할 일을 모두 오늘로 끌어온다.
    func pullOverdueToToday() {
        let today = DayFormat.today
        for i in items.indices where !items[i].done && items[i].day < today {
            items[i].day = today
        }
    }

    func setPriority(_ priority: Priority, for id: UUID) {
        guard let i = index(of: id) else { return }
        items[i].priority = priority
    }

    /// 그 날짜만 우선순위 높은 순으로 한 번 정리한다.
    /// 같은 등급끼리는 지금 순서를 지키고, 다른 날짜는 건드리지 않는다.
    func sortByPriority(on day: Date) {
        let places = slots(on: day)
        let sorted = places.map { items[$0] }
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.priority.rawValue != rhs.element.priority.rawValue {
                    return lhs.element.priority.rawValue > rhs.element.priority.rawValue
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
        for (place, item) in zip(places, sorted) { items[place] = item }
    }

    // MARK: - 드래그로 순서 바꾸기

    /// 끌고 있는 할 일을 target 자리로 옮긴다. 드래그 중에 실시간으로 불린다.
    /// 날짜가 다르면 무시한다. 순서 바꾸기는 같은 날 안에서만 뜻이 있다.
    func moveItem(_ id: UUID, toPositionOf targetID: UUID) {
        guard id != targetID,
              let from = index(of: id),
              let to = index(of: targetID),
              DayFormat.isSameDay(items[from].day, items[to].day) else { return }
        let moved = items.remove(at: from)
        items.insert(moved, at: to)
    }

    // MARK: - 하위 할 일

    func addSubtask(to id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = index(of: id) else { return }
        items[i].subtasks.append(Subtask(title: trimmed))
        items[i].expanded = true
        syncParent(i)
    }

    func toggleSubtask(todo id: UUID, sub subID: UUID) {
        guard let i = index(of: id),
              let k = items[i].subtasks.firstIndex(where: { $0.id == subID }) else { return }
        items[i].subtasks[k].done.toggle()
        syncParent(i)
    }

    func deleteSubtask(todo id: UUID, sub subID: UUID) {
        guard let i = index(of: id) else { return }
        items[i].subtasks.removeAll { $0.id == subID }
        syncParent(i)
    }

    /// 하위 할 일이 모두 끝나면 상위도 끝난 것으로 본다.
    private func syncParent(_ i: Int) {
        guard !items[i].subtasks.isEmpty else { return }
        items[i].done = items[i].subtasks.allSatisfy(\.done)
    }
}
