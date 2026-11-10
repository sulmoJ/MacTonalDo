import Foundation
import AppKit

/// 내보내기 형식.
enum ExportFormat {
    /// 슬랙·메신저에 그대로 붙여 넣는 용도. 유니코드 체크박스를 쓴다.
    case plain
    /// 마크다운 체크리스트. 노션·깃허브·문서 도구용.
    case markdown
}

enum TodoExporter {

    // MARK: - 글 만들기

    /// 한 날짜 분을 글로 만든다. dayTitle 을 주면 머리말에 날짜가 함께 붙는다.
    static func text(items: [TodoItem],
                     format: ExportFormat,
                     onlyRemaining: Bool,
                     dayTitle: String? = nil) -> String {
        let source = onlyRemaining ? items.filter { !$0.done } : items
        let doneCount = items.filter(\.done).count

        var lines: [String] = [heading(done: doneCount,
                                       total: items.count,
                                       onlyRemaining: onlyRemaining,
                                       format: format,
                                       dayTitle: dayTitle), ""]

        for item in source {
            lines.append(box(item.done, format: format, depth: 0)
                         + priorityTag(item.priority)
                         + item.title)

            if !item.note.isEmpty {
                for noteLine in item.note.split(separator: "\n", omittingEmptySubsequences: false) {
                    lines.append(notePrefix(format) + noteLine)
                }
            }

            for sub in item.subtasks where !(onlyRemaining && sub.done) {
                lines.append(box(sub.done, format: format, depth: 1) + sub.title)
            }
        }

        if source.isEmpty {
            lines.append(onlyRemaining ? "남은 할 일이 없습니다." : "할 일이 없습니다.")
        }

        return lines.joined(separator: "\n")
    }

    /// 날짜별로 묶어 한 번에 내보낸다. 지난 날이 위로 온다.
    static func grouped(items: [TodoItem],
                        format: ExportFormat,
                        onlyRemaining: Bool) -> String {
        let source = onlyRemaining ? items.filter { !$0.done } : items
        guard !source.isEmpty else {
            return onlyRemaining ? "남은 할 일이 없습니다." : "할 일이 없습니다."
        }

        let days = Set(source.map { DayFormat.day($0.day) }).sorted()
        return days.map { day in
            text(items: items.filter { DayFormat.isSameDay($0.day, day) },
                 format: format,
                 onlyRemaining: onlyRemaining,
                 dayTitle: DayFormat.short(day))
        }
        .joined(separator: "\n\n")
    }

    private static func heading(done: Int, total: Int, onlyRemaining: Bool,
                                format: ExportFormat, dayTitle: String?) -> String {
        let status = onlyRemaining ? "남은 할 일 \(total - done)개" : "할 일 \(done)/\(total) 완료"
        let title = dayTitle.map { "\($0) · \(status)" } ?? status
        return format == .markdown ? "## \(title)" : title
    }

    private static func box(_ done: Bool, format: ExportFormat, depth: Int) -> String {
        let indent = String(repeating: "  ", count: depth)
        switch format {
        case .plain:
            return indent + (done ? "☑ " : "☐ ")
        case .markdown:
            return indent + (done ? "- [x] " : "- [ ] ")
        }
    }

    private static func priorityTag(_ priority: Priority) -> String {
        priority == .none ? "" : "[\(priority.label)] "
    }

    private static func notePrefix(_ format: ExportFormat) -> String {
        format == .markdown ? "  - 메모: " : "   ↳ "
    }

    // MARK: - 내보내기

    static func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    /// 저장 패널은 메뉴바 앱에서도 뜨도록 앱을 먼저 전면으로 올린다.
    static func saveToFile(_ string: String, suggestedName: String) {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.level = .modalPanel

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? string.write(to: url, atomically: true, encoding: .utf8)
    }
}
