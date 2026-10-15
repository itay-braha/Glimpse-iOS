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

    private func waitUntilGone(_ element: XCUIElement, timeout: Double) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter.wait(for: [gone], timeout: timeout) == .completed
    }

    /// The on-screen card tags its own elements ".active" (neighbours stay loaded).
    private func clipPositionElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "clipPosition.active").firstMatch
    }

    private func clipPosition(_ app: XCUIApplication) -> String {
        let element = clipPositionElement(app)
        return element.waitForExistence(timeout: 5) ? element.label : "?"
    }

    private func currentName(_ app: XCUIApplication) -> String {
        let element = app.descendants(matching: .any).matching(identifier: "profileName.active").firstMatch
        return element.waitForExistence(timeout: 5) ? element.label : "?"
    }

    private func visible(_ query: XCUIElementQuery) -> XCUIElement? {
        query.allElementsBoundByIndex.first { $0.exists && $0.isHittable }
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

        let idea = app.buttons["hub.inspiration"]
        XCTAssertTrue(idea.waitForExistence(timeout: 10))
        snap("1-5 Let others get a Glimpse of YOU")
        idea.tap()

        let camera = app.buttons["inspiration.camera.best_friend"]
        XCTAssertTrue(camera.waitForExistence(timeout: 10))
        camera.tap()

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

    // A -> G: the three ways to add a moment, from the profile's Add button.
    func testVideoFirstProfile() {
        let app = launch("addVideo")
        let upload = app.buttons["hub.upload"]
        XCTAssertTrue(upload.waitForExistence(timeout: 20))
        snap("5-1 Let others get a Glimpse of YOU")
        upload.tap()

        let sample = app.buttons["upload.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        snap("5-2 Quick upload rules")
        sample.tap()

        let add = app.buttons["upload.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 60))
        pause(2)
        snap("5-3 Clip checked (length, 9:16, 20 MB)")
        add.tap()
        XCTAssertTrue(waitUntilGone(add, timeout: 60))

        let addTile = app.buttons["profile.addVideo"]
        XCTAssertTrue(addTile.waitForExistence(timeout: 10))
        pause(1)
        snap("5-4 Uploaded moment on the profile")
        addTile.tap()

        let embed = app.buttons["hub.embed"]
        XCTAssertTrue(embed.waitForExistence(timeout: 10))
        embed.tap()
        let field = app.textFields["embed.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("https://www.instagram.com/stories/glimpse.demo/3301234567890123456/")
        XCTAssertTrue(app.buttons["embed.useUpload"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["embed.add"].isEnabled)
        snap("5-5 Stories must be uploaded, not linked")
        app.buttons["Clear"].tap()

        field.tap()
        field.typeText("https://www.instagram.com/reel/C9xYzAbC12/?igsh=MWQ1ZGUx")
        XCTAssertTrue(app.staticTexts["embed.found"].waitForExistence(timeout: 10)
            || text(app, containing: "video found").waitForExistence(timeout: 5))
        snap("5-6 Public Reel recognized")

        field.typeText("\n") // the return key dismisses the keyboard
        let consent = app.switches["embed.consent"]
        XCTAssertTrue(consent.waitForExistence(timeout: 10))
        for _ in 0..<5 where !consent.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        consent.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        pause(0.5)
        snap("5-7 Links-to-your-profile consent")
        let addLink = app.buttons["embed.add"]
        XCTAssertTrue(addLink.isEnabled)
        addLink.tap()
        XCTAssertTrue(waitUntilGone(addLink, timeout: 20))

        let linkedTile = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Instagram link moment")).firstMatch
        XCTAssertTrue(linkedTile.waitForExistence(timeout: 10))
        pause(1)
        snap("5-8 Linked Reel on the profile")
    }

    // A -> C: the viewer. Clips start muted, one tap turns sound on, linked posts
    // play in the platform's own player with a badge that opens the app.
    func testVideoViewer() {
        let app = launch("feed")
        let mute = app.buttons["muteToggle"].firstMatch
        XCTAssertTrue(mute.waitForExistence(timeout: 20))
        pause(4)
        XCTAssertEqual(mute.label, "Unmute")
        snap("6-1 Muted by default")
        mute.tap()
        XCTAssertEqual(mute.label, "Mute")
        snap("6-2 Sound on")

        let card = app.windows.firstMatch
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.4)).tap()
        pause(1)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.4)).tap()
        let badge = app.buttons["platformBadge"].firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 10))
        pause(1.5)
        snap("6-3 Linked TikTok in its own player")
    }

    // How people move around a profile and between people (the same in every card).
    func testFeedNavigation() {
        let app = XCUIApplication()
        continueAfterFailure = false
        // 15-second clip time (UserDefaults via launch arguments) so the checks
        // below never race the auto-advance on a slow simulator.
        app.launchArguments = ["-demo", "-screen", "feed", "-showTips", "-glimpse.clipSeconds", "15"]
        app.launch()

        let gotIt = app.buttons["tips.done"]
        XCTAssertTrue(gotIt.waitForExistence(timeout: 20))
        snap("7-1 First-time tips")
        gotIt.tap()

        let window = app.windows.firstMatch
        XCTAssertTrue(app.buttons["Glimpse"].firstMatch.waitForExistence(timeout: 10))
        let first = currentName(app)
        XCTAssertEqual(clipPosition(app), "Clip 1 of 3")
        snap("7-2 Clip 1 of 3")

        window.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.42)).tap()
        pause(0.8)
        XCTAssertEqual(clipPosition(app), "Clip 2 of 3")
        snap("7-3 Tap right: next clip")

        window.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.42)).tap()
        pause(0.8)
        XCTAssertEqual(clipPosition(app), "Clip 1 of 3")

        // After the clip time (7 s by default) the next clip starts by itself.
        let advanced = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Clip 2 of 3"),
            object: clipPositionElement(app)
        )
        XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 25), .completed)
        snap("7-4 Clip time up: next clip on its own")

        let more = visible(app.buttons.matching(identifier: "watchMore"))
        XCTAssertNotNil(more)
        more?.tap()
        pause(0.5)
        snap("7-5 +more: watching the rest")

        window.swipeUp()
        pause(1.5)
        let second = currentName(app)
        XCTAssertNotEqual(second, first)
        snap("7-6 Swipe up: next person")

        window.swipeLeft()
        pause(1.5)
        let third = currentName(app)
        XCTAssertNotEqual(third, second)
        snap("7-7 Swipe left: pass")

        window.swipeRight()
        XCTAssertTrue(button(app, containing: "anyway").waitForExistence(timeout: 8))
        snap("7-8 Swipe right: like (at 20, asks first)")
    }

    // A -> F: a chat that does more than send text.
    func testChatRepliesAndReactions() {
        let app = launch("chat")
        let incoming = app.descendants(matching: .any).matching(identifier: "bubble.incoming")
        XCTAssertTrue(incoming.firstMatch.waitForExistence(timeout: 20))
        pause(1)
        snap("8-1 Reactions and a quoted reply")

        let last = incoming.allElementsBoundByIndex.last!
        let reactionsBefore = app.descendants(matching: .any).matching(identifier: "bubble.reactions").count
        last.doubleTap()
        let hearted = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > %d", reactionsBefore),
            object: app.descendants(matching: .any).matching(identifier: "bubble.reactions")
        )
        XCTAssertEqual(XCTWaiter.wait(for: [hearted], timeout: 5), .completed)
        snap("8-2 Double-tap: a heart")

        last.press(forDuration: 1.0)
        let reply = app.buttons["Reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        snap("8-3 Hold: react, reply, copy")
        reply.tap()

        XCTAssertTrue(app.descendants(matching: .any)["chat.replyBar"].waitForExistence(timeout: 5))
        // Reply focuses the message box.
        app.typeText("Sunset it is. 7pm?")
        snap("8-4 Replying to her message")
        app.buttons["Send"].tap()

        XCTAssertTrue(text(app, containing: "Sunset it is").waitForExistence(timeout: 5))
        XCTAssertTrue(text(app, containing: "I like where this is going").waitForExistence(timeout: 15)
            || app.descendants(matching: .any).matching(identifier: "bubble.incoming").count > incoming.count)
        pause(1)
        snap("8-5 Sent with the quote; she reacted and answered")

        incoming.allElementsBoundByIndex.first!.swipeRight()
        XCTAssertTrue(app.descendants(matching: .any)["chat.replyBar"].waitForExistence(timeout: 5))
        snap("8-6 Swipe a message right to reply")
    }

    // A -> C: what buzzes is the member's choice, asked before iOS asks.
    func testAlertChoice() {
        let app = launch("alerts")
        let turnOn = app.buttons["alerts.turnOn"]
        XCTAssertTrue(turnOn.waitForExistence(timeout: 20))
        snap("9-1 What should buzz")
        app.buttons["alerts.messages"].tap()
        snap("9-2 Just messages")
        turnOn.tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 8) {
            snap("9-3 Then iOS asks")
            allow.tap()
        }
        XCTAssertTrue(waitUntilGone(turnOn, timeout: 5))
    }
}
