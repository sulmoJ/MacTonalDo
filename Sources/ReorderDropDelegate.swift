import SwiftUI

/// 드래그가 다른 줄 위로 올라온 순간 바로 자리를 바꾼다.
/// 끌어 놓을 자리를 선으로 그리는 대신 목록이 실시간으로 밀려나는 방식이다.
struct ReorderDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggingID: UUID?
    let store: TodoStore

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingID, dragging != targetID else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            store.moveItem(dragging, toPositionOf: targetID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

/// 줄 바깥 빈 곳에 놓았을 때 끌던 상태를 풀어 주는 용도.
struct ReorderCancelDropDelegate: DropDelegate {
    @Binding var draggingID: UUID?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
