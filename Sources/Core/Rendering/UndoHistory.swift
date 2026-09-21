/// 値のスナップショットによる Undo/Redo。
/// `AdjustmentParameters` は小さな値型なので、差分ではなく丸ごと保持する。
public struct UndoHistory<Value: Equatable & Sendable>: Sendable {
    public private(set) var current: Value
    private var past: [Value] = []
    private var future: [Value] = []

    public init(initial: Value) {
        current = initial
    }

    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }

    /// 現在値を確定する。同じ値なら履歴を増やさない。
    public mutating func commit(_ value: Value) {
        guard value != current else { return }
        past.append(current)
        current = value
        future.removeAll()
    }

    public mutating func undo() {
        guard let previous = past.popLast() else { return }
        future.append(current)
        current = previous
    }

    public mutating func redo() {
        guard let next = future.popLast() else { return }
        past.append(current)
        current = next
    }
}
