import XCTest
@testable import NuvoCore

final class UndoHistoryTests: XCTestCase {
    func testInitialStateCannotUndoOrRedo() {
        let history = UndoHistory(initial: 0)
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testUndoAndRedoRestoreValues() {
        var history = UndoHistory(initial: 0)
        history.commit(1)
        history.commit(2)
        history.undo()
        XCTAssertEqual(history.current, 1)
        history.undo()
        XCTAssertEqual(history.current, 0)
        history.redo()
        XCTAssertEqual(history.current, 1)
    }

    func testCommitClearsRedo() {
        var history = UndoHistory(initial: 0)
        history.commit(1)
        history.undo()
        history.commit(5)
        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(history.current, 5)
    }

    func testSameValueIsNotRecorded() {
        var history = UndoHistory(initial: 3)
        history.commit(3)
        XCTAssertFalse(history.canUndo)
    }

    func testUndoAtStartIsNoOp() {
        var history = UndoHistory(initial: 7)
        history.undo()
        XCTAssertEqual(history.current, 7)
    }
}
