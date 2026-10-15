import XCTest

/// End-to-end walks through the main journeys in demo mode. Every step saves a
/// named screenshot (kept in the test results) so a run reads as A -> B -> C.
@MainActor
final class FlowTests: XCTestCase {
    private func launch(_ screen: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-screen", screen]
        app.launch()
        return app
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func button(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func text(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Multi-line text fields can surface as text views.
    private func input(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        let field = app.textFields[label]
        return field.exists ? field : app.textViews[label]
    }

    private func pause(_ seconds: Double) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    // A -> F: a brand-new member gets from the welcome screen to the feed.
    func testOnboardingToFeed() {
        let app = launch("welcome")
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 15))
        snap("1-1 Welcome")
        app.buttons["Get started"].tap()

        let phone = app.textFields["Mobile number"]
        XCTAssertTrue(phone.waitForExistence(timeout: 5))
        phone.tap()
        phone.typeText("5550100")
        snap("1-2 Phone number")
        app.buttons["Send code"].tap()

        let code = app.textFields["Six digit code"]
        XCTAssertTrue(code.waitForExistence(timeout: 10))
        code.tap()
        code.typeText("12345")
        snap("1-3 SMS code")
        code.typeText("6")

        let name = app.textFields["Your first name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Itay")
        app.staticTexts["The basics"].tap()
        app.buttons["Man"].tap()
        app.buttons["Women"].tap()
        snap("1-4 Profile basics")
        app.buttons["Continue"].tap()

        let record = button(app, containing: "Record a clip")
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        snap("1-5 First moment")
        record.tap()

        let sample = app.buttons["Use a sample moment"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        sample.tap()

        XCTAssertTrue(app.buttons["Glimpse"].firstMatch.waitForExistence(timeout: 20))
        pause(4)
        snap("1-6 Feed")
    }

    // A -> D: at 20/20 a like becomes a choice, then a match, then a conversation.
    func testMatchAtCapacityThenChat() {
        let app = launch("feed")
        let like = app.buttons["Glimpse"].firstMatch
        XCTAssertTrue(like.waitForExistence(timeout: 20))
        pause(5)
        snap("2-1 Feed at 20 of 20")
        like.tap()

        let anyway = app.buttons["Like Maya anyway"]
        XCTAssertTrue(anyway.waitForExistence(timeout: 8))
        snap("2-2 Capacity choice")
        anyway.tap()

        let message = app.buttons["Send a message"]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        pause(1)
        snap("2-3 It's a Glimpse")
        message.tap()

        let field = input(app, "Message Maya")
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Hey Maya! Sunrise swim this weekend?")
        app.buttons["Send"].tap()
        XCTAssertTrue(text(app, containing: "I like where this is going").waitForExistence(timeout: 15))
        snap("2-4 Chat with a reply")
    }

    // A -> I: the full 3-Minute Vibe Check from his side of a woman–man match.
    func testVibeCheck() {
        let app = launch("chat")
        let suggest = app.buttons["Suggest a time"]
        XCTAssertTrue(suggest.waitForExistence(timeout: 20))
        snap("3-1 She unlocked the Vibe Check")
        suggest.tap()

        let slot = app.buttons["In 30 minutes"]
        XCTAssertTrue(slot.waitForExistence(timeout: 8))
        snap("3-2 Suggest a time")
        slot.tap()
        pause(1.5)
        snap("3-3 Waiting for her to confirm")

        let join = app.buttons["Join Vibe Check"]
        XCTAssertTrue(join.waitForExistence(timeout: 45))
        snap("3-4 Confirmed, lobby open")
        join.tap()

        let ready = app.buttons["I'm ready"]
        XCTAssertTrue(ready.waitForExistence(timeout: 10))
        snap("3-5 Lobby")
        ready.tap()

        XCTAssertTrue(app.buttons["End now and report"].waitForExistence(timeout: 15))
        pause(1)
        snap("3-6 Live call")
        pause(6)
        snap("3-7 Countdown running")
        app.buttons["Hang up"].tap()

        let matched = button(app, containing: "The vibe matched")
        XCTAssertTrue(matched.waitForExistence(timeout: 10))
        snap("3-8 Private survey")
        matched.tap()

        XCTAssertTrue(text(app, containing: "Vibe Verified").waitForExistence(timeout: 20))
        snap("3-9 Vibe Verified")
    }

    // A -> D: freemium "Liked you": teaser, free daily reveal, Glimpse+.
    func testLikedYouAndGlimpsePlus() {
        let app = launch("likes")
        XCTAssertTrue(text(app, containing: "want to see more").waitForExistence(timeout: 20))
        pause(1)
        snap("4-1 Liked you (free)")

        button(app, containing: "Reveal 1 free").tap()
        pause(2)
        snap("4-2 Daily free reveal")

        app.buttons["See all"].tap()
        let tryPlus = button(app, containing: "Try Glimpse+")
        XCTAssertTrue(tryPlus.waitForExistence(timeout: 10))
        snap("4-3 Glimpse+ paywall")
        tryPlus.tap()
        pause(3)
        snap("4-4 Everyone revealed with Glimpse+")
    }
}
