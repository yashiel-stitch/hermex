import UIKit
import XCTest
@testable import HermesMobile

@MainActor
final class ComposerMacKeyCommandTests: XCTestCase {
    private func command(_ input: String, in textView: ComposerChipTextView) -> UIKeyCommand? {
        textView.keyCommands?.first { $0.input == input && $0.modifierFlags.isEmpty }
    }

    private func macTextView() -> ComposerChipTextView {
        let textView = ComposerChipTextView()
        textView.usesMacKeyCommands = true
        return textView
    }

    func testPlainReturnAndEscapeAreNotClaimedOffTheMac() {
        let textView = ComposerChipTextView()
        textView.usesMacKeyCommands = false
        textView.isKeyboardStopEnabled = true

        XCTAssertNil(command("\r", in: textView))
        XCTAssertNil(command(UIKeyCommand.inputEscape, in: textView))
    }

    func testReturnSendsOnlyThroughTheSendGateAndYieldsToIMEComposition() throws {
        let textView = macTextView()
        var sends = 0
        textView.onKeyboardSend = { sends += 1 }
        let returnCommand = try XCTUnwrap(command("\r", in: textView))
        XCTAssertTrue(returnCommand.wantsPriorityOverSystemBehavior)
        let send = try XCTUnwrap(returnCommand.action)

        textView.perform(send, with: nil)
        XCTAssertEqual(sends, 0, "Send gate closed: Return does not send")

        textView.isKeyboardSendEnabled = true
        textView.perform(send, with: nil)
        XCTAssertEqual(sends, 1)

        XCTAssertTrue(textView.canPerformAction(send, withSender: nil))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(textView)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        textView.becomeFirstResponder()
        textView.setMarkedText("か", selectedRange: NSRange(location: 0, length: 1))
        XCTAssertNotNil(textView.markedTextRange)
        XCTAssertFalse(textView.canPerformAction(send, withSender: nil), "IME composition keeps Return")
    }

    func testShiftReturnInsertsANewLineInsteadOfSending() throws {
        let textView = macTextView()
        textView.isKeyboardSendEnabled = true
        var sends = 0
        textView.onKeyboardSend = { sends += 1 }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(textView)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        textView.becomeFirstResponder()
        textView.insertText("first")

        let shiftReturn = try XCTUnwrap(textView.keyCommands?.first { $0.input == "\r" && $0.modifierFlags == .shift })
        XCTAssertTrue(shiftReturn.wantsPriorityOverSystemBehavior)
        XCTAssertTrue(textView.canPerformAction(try XCTUnwrap(shiftReturn.action), withSender: shiftReturn))
        textView.perform(shiftReturn.action, with: shiftReturn)
        XCTAssertEqual(textView.text, "first\n")

        let plainReturn = try XCTUnwrap(command("\r", in: textView))
        textView.perform(plainReturn.action, with: shiftReturn)
        XCTAssertEqual(textView.text, "first\n\n", "A Shift-modified Return reaching the send command still inserts a line")
        XCTAssertEqual(sends, 0)

        let phone = ComposerChipTextView()
        phone.usesMacKeyCommands = false
        XCTAssertNil(phone.keyCommands?.first { $0.input == "\r" && $0.modifierFlags == .shift })
    }

    func testEscapeIsClaimedOnlyWhileAStopIsAvailable() throws {
        let textView = macTextView()
        var stops = 0
        textView.onKeyboardStop = { stops += 1 }

        XCTAssertNil(command(UIKeyCommand.inputEscape, in: textView))

        textView.isKeyboardStopEnabled = true
        let stop = try XCTUnwrap(command(UIKeyCommand.inputEscape, in: textView)?.action)
        XCTAssertTrue(textView.canPerformAction(stop, withSender: nil))
        textView.perform(stop, with: nil)
        XCTAssertEqual(stops, 1)

        textView.isKeyboardStopEnabled = false
        XCTAssertFalse(textView.canPerformAction(stop, withSender: nil))
        textView.perform(stop, with: nil)
        XCTAssertEqual(stops, 1)
    }
}
