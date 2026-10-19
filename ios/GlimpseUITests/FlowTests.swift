import XCTest

/// End-to-end walks through the main journeys in demo mode. Every step saves a
/// named screenshot (kept in the test results) so a run reads as A -> B -> C.
@MainActor
final class FlowTests: XCTestCase {
    /// Screenshots of other people's videos come out blank in the app, so scripted
    /// runs pass `-allowCapture` unless a test is checking that protection.
    private func launch(_ screen: String, protectMedia: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-screen", screen] + (protectMedia ? [] : ["-allowCapture"])
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

    /// The on-screen card's clip number ("Clip 2 of 3" -> 2).
    private func clipNumber(_ app: XCUIApplication) -> Int {
        Int(clipPosition(app).split(separator: " ").dropFirst().first ?? "") ?? 0
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
        let start = app.buttons["Get started"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        snap("1-1 Welcome")
        // Two explicit agreements before anything else: 18+ and the terms, and sensitive data.
        XCTAssertFalse(start.isEnabled)
        for id in ["consent.terms", "consent.sensitive"] {
            let toggle = app.switches[id]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        XCTAssertTrue(start.isEnabled)
        snap("1-1b Agreed")
        start.tap()

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
        // Height: a number, or choose not to show it. Until then, Continue waits.
        XCTAssertFalse(app.buttons["Continue"].isEnabled)
        app.buttons["height.hide"].tap()
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
        // Other people's height shows on their card while you watch.
        XCTAssertTrue(app.descendants(matching: .any)["card.height"].firstMatch.waitForExistence(timeout: 5))
    }

    // A -> D: at 15/15 a like becomes a choice, then a match, then a conversation.
    func testMatchAtCapacityThenChat() {
        let app = launch("feed")
        let like = app.buttons["Glimpse"].firstMatch
        XCTAssertTrue(like.waitForExistence(timeout: 20))
        pause(5)
        snap("2-1 Feed at 15 of 15")
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
        // Nobody joins without agreeing to the private safety recording.
        XCTAssertFalse(ready.isEnabled)
        let agree = app.switches["vibe.agree"]
        XCTAssertTrue(agree.waitForExistence(timeout: 5))
        agree.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertTrue(ready.isEnabled)
        // The call's video sits in the layer iOS leaves out of screenshots and recordings.
        XCTAssertTrue(app.descendants(matching: .any)["vibe.captureProtected"].exists)
        snap("3-5 Lobby: no capture, safety recording agreed")
        ready.tap()

        XCTAssertTrue(app.buttons["End now and report"].waitForExistence(timeout: 15))
        pause(1)
        snap("3-6 Live call")
        // Topics are on by default: tap for a new one, × to hide, "Topics" to bring them back.
        let nextTopic = app.buttons["vibe.nextTopic"]
        XCTAssertTrue(nextTopic.waitForExistence(timeout: 5))
        nextTopic.tap()
        app.buttons["vibe.hideTopics"].tap()
        let showTopics = app.buttons["vibe.showTopics"]
        XCTAssertTrue(showTopics.waitForExistence(timeout: 3))
        snap("3-6b Topics hidden")
        showTopics.tap()
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
    func testLikedYouIsFree() {
        let app = launch("likes")
        XCTAssertTrue(text(app, containing: "want to see more").waitForExistence(timeout: 20))
        XCTAssertTrue(button(app, containing: "Liked you.").waitForExistence(timeout: 10), "admirers are shown, not blurred")
        XCTAssertFalse(button(app, containing: "Reveal").exists)
        pause(1)
        snap("4-1 Liked you: everyone, free")
    }

    // Glimpse Gold: Rewind and the Gold hub.
    func testCaptureProtectionAndGold() {
        let app = launch("feed", protectMedia: true)
        XCTAssertTrue(app.buttons["Glimpse"].firstMatch.waitForExistence(timeout: 20))
        pause(3)
        snap("11-1 Feed")

        let first = currentName(app)
        app.swipeUp()
        pause(2)
        XCTAssertNotEqual(currentName(app), first)

        let rewind = app.buttons["feed.rewind"]
        rewind.tap()
        let buy = app.buttons["paywall.buy"]
        XCTAssertTrue(buy.waitForExistence(timeout: 10))
        XCTAssertTrue(button(app, containing: "Try Glimpse Gold").exists, "Rewind opens Glimpse Gold")
        snap("11-2 Glimpse Gold")
        buy.tap()
        XCTAssertTrue(waitUntilGone(buy, timeout: 10))

        rewind.tap()
        pause(2)
        XCTAssertEqual(currentName(app), first, "Rewind brings back the person just passed")
        snap("11-3 Rewind: they're back")

        app.terminate()
        let settings = launch("settings")
        let gold = settings.buttons["settings.gold"]
        XCTAssertTrue(gold.waitForExistence(timeout: 20))
        gold.tap()
        XCTAssertTrue(settings.buttons["gold.upsell"].waitForExistence(timeout: 10))
        snap("11-4 Gold hub before upgrading")
    }

    // After a good Vibe Check: a first-date idea, the same for both of them.
    func testDateIdeaAfterVibeCheck() {
        let app = launch("dateIdea")
        XCTAssertTrue(app.descendants(matching: .any)["dateIdea"].waitForExistence(timeout: 20))
        snap("12-1 A first-date idea after a good Vibe Check")
        app.buttons["dateIdea.another"].tap()
        pause(1)
        snap("12-2 Another idea")
        // Pick a time there; in the demo they say yes a moment later.
        app.buttons["dateIdea.plan"].tap()
        let suggest = app.buttons["datePlan.suggest"]
        XCTAssertTrue(suggest.waitForExistence(timeout: 5))
        snap("12-3 Pick a time")
        suggest.tap()
        XCTAssertTrue(app.descendants(matching: .any)["plannedDate"].waitForExistence(timeout: 5))
        XCTAssertTrue(text(app, containing: "Your date with").waitForExistence(timeout: 8), "they accepted")
        snap("12-4 The date is set")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["matches.dateChip"].firstMatch.waitForExistence(timeout: 10))
        snap("12-5 The date shows in Connections")
    }

    // Hebrew, right to left: brand names stay in Latin, layout mirrors, swipes stay physical.
    func testHebrew() {
        func hebrew(_ screen: String) -> XCUIApplication {
            let app = XCUIApplication()
            app.launchArguments = ["-demo", "-screen", screen, "-allowCapture", "-AppleLanguages", "(he)", "-AppleLocale", "he_IL"]
            app.launch()
            return app
        }
        continueAfterFailure = false

        var app = hebrew("welcome")
        XCTAssertTrue(app.buttons["בואו נתחיל"].waitForExistence(timeout: 20), "the welcome screen is in Hebrew")
        snap("13-1 Hebrew: welcome and consent")
        app.terminate()

        app = hebrew("feed")
        XCTAssertTrue(app.buttons["Glimpse"].firstMatch.waitForExistence(timeout: 20))
        pause(3)
        snap("13-2 Hebrew: feed")
        app.terminate()

        app = hebrew("chat")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "bubble.incoming").firstMatch.waitForExistence(timeout: 20))
        pause(1)
        snap("13-3 Hebrew: chat")
        app.terminate()

        app = hebrew("settings")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 20))
        let terms = app.buttons["תנאי שימוש"]
        for _ in 0..<6 where !(terms.exists && terms.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(terms.waitForExistence(timeout: 5))
        snap("13-4 Hebrew: settings")
        terms.tap()
        XCTAssertTrue(text(app, containing: "תנאי שימוש אלה").waitForExistence(timeout: 10), "the terms are in Hebrew")
        snap("13-5 Hebrew: terms of service")
    }

    // A rare alert offer, pinning a chat, and the report confirmation.
    func testPinsReportAndAlertOffer() {
        let app = launch("alertNudge")
        let notNow = app.buttons["nudge.notNow"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 20))
        snap("10-1 Vibe Check alert offer")
        notNow.tap()
        XCTAssertTrue(waitUntilGone(notNow, timeout: 5))

        app.tabBars.buttons["Connections"].tap()
        let hila = app.cells.containing(NSPredicate(format: "label CONTAINS 'Hila'")).firstMatch
        XCTAssertTrue(hila.waitForExistence(timeout: 15))
        // Hold for actions: pin, freeze, unmatch, report.
        hila.press(forDuration: 1.2)
        let pin = app.buttons["Pin"]
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Report or block"].exists)
        snap("10-2a Hold a conversation for actions")
        pin.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label ==[c] 'Pinned'")).firstMatch
            .waitForExistence(timeout: 5))
        pause(1)
        snap("10-2 Pinned to the top")

        app.cells.containing(NSPredicate(format: "label CONTAINS 'Hila'")).firstMatch.tap()
        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        let report = app.buttons["Report or block"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        report.tap()
        let harassment = app.buttons["Harassing, threatening or creepy"]
        XCTAssertTrue(harassment.waitForExistence(timeout: 5))
        harassment.tap()
        app.buttons["Submit"].tap()

        let received = app.descendants(matching: .any)["report.received"]
        XCTAssertTrue(received.waitForExistence(timeout: 10))
        XCTAssertTrue(text(app, containing: "won't see or reach each other").exists)
        snap("10-3 Report received: shield")
        app.buttons["report.done"].tap()
        XCTAssertTrue(waitUntilGone(received, timeout: 5))
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
        // Let scrolling settle, then flip the switch (retry if a tap lands mid-scroll).
        pause(1)
        for _ in 0..<3 where (consent.value as? String) != "1" {
            consent.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            pause(0.8)
        }
        XCTAssertEqual(consent.value as? String, "1")
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
        // 12-second clip time so the checks below never race the auto-advance on
        // a slow simulator (15 s clips still leave a "+3s more").
        app.launchArguments = ["-demo", "-screen", "feed", "-showTips", "-clipSeconds", "12", "-allowCapture"]
        app.launch()

        // The tips show once per install, so a retry of this test won't see them again.
        let gotIt = app.buttons["tips.done"]
        if gotIt.waitForExistence(timeout: 20) {
            snap("7-1 First-time tips")
            gotIt.tap()
        }

        // Tap near the edges: on a linked TikTok/Instagram clip only a 30-pt strip at each
        // side changes clips (the middle belongs to that player).
        let window = app.windows.firstMatch
        XCTAssertTrue(app.buttons["Glimpse"].firstMatch.waitForExistence(timeout: 10))
        let first = currentName(app)
        // Start from her first clip (the clip timer may already have moved on).
        for _ in 0..<4 where clipNumber(app) > 1 {
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.42)).tap()
            pause(0.8)
        }
        let start = clipNumber(app)
        XCTAssertTrue(start == 1 || start == 2)
        snap("7-2 Clip 1 of 3")

        window.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.42)).tap()
        pause(0.8)
        XCTAssertEqual(clipNumber(app), start + 1)
        snap("7-3 Tap right: next clip")

        window.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.42)).tap()
        pause(0.8)
        XCTAssertEqual(clipNumber(app), start)

        // After the clip time the next clip starts by itself.
        let advanced = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Clip \(start + 1) of 3"),
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

        last.press(forDuration: 1.2)
        // Menu items surface as buttons or menu items depending on the iOS version.
        let reply = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Reply'")).firstMatch
        if reply.waitForExistence(timeout: 5) {
            snap("8-3 Hold: react, reply, copy")
            reply.tap()
        } else {
            snap("8-3 Hold: react, reply, copy")
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
            last.swipeRight()
        }

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

        incoming.allElementsBoundByIndex.last!.swipeRight()
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

    // Hold to record, slide up to lock, trash or send; delete for everyone.
    func testVoiceVideoAndDelete() {
        let app = launch("chat")
        let voice = app.buttons["chat.recordVoice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 20))
        snap("10-1 Mic and camera beside the message field")

        // Video note: hold, then slide left to cancel. Nothing is sent.
        let video = app.buttons["chat.recordVideo"]
        let videosBefore = app.descendants(matching: .any).matching(identifier: "bubble.video").count
        video.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 1.5, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.93)))
        pause(1)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "bubble.video").count, videosBefore)
        snap("10-2 Slid left: video cancelled")

        // Voice: hold, slide up to lock, then send hands-free.
        let above = voice.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -3))
        voice.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.0, thenDragTo: above)
        let trash = app.buttons["chat.recordTrash"]
        XCTAssertTrue(trash.waitForExistence(timeout: 5))
        pause(1.5)
        snap("10-3 Locked: recording hands-free")
        app.buttons["chat.send"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["bubble.voice"].waitForExistence(timeout: 15))
        pause(1)
        snap("10-4 Voice message sent")

        // Delete for everyone: the chat shows it as deleted.
        let mine = app.descendants(matching: .any).matching(identifier: "bubble.mine").allElementsBoundByIndex.last!
        mine.press(forDuration: 1.2)
        let delete = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Delete for everyone'")).firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        snap("10-5 Hold: delete for everyone")
        delete.tap()
        XCTAssertTrue(text(app, containing: "Message deleted").waitForExistence(timeout: 5))
        snap("10-6 Deleted (kept privately for the safety team)")
    }
}
