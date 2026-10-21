import Foundation
@testable import Glimpse
import Testing

/// Everyone does a selfie check while signing up; a person approves it.
struct SelfieCheckTests {
    @Test func theServerTellsTheAppWhetherTheCheckIsDone() throws {
        let asked = try JSONDecoder().decode(AccountState.self, from: Data(#"{"status":"active","selfie_cleared":false}"#.utf8))
        #expect(asked.selfieCleared == false)
        // An older server that doesn't say: don't block anyone.
        let older = try JSONDecoder().decode(AccountState.self, from: Data(#"{"status":"active"}"#.utf8))
        #expect(older.selfieCleared == nil)
    }

    @Test func demoMembersAreNotAskedUnlessTheCheckIsSwitchedOn() async throws {
        let backend = DemoBackend(seeded: true)
        #expect(try await backend.accountState().selfieCleared == true)
    }

    @Test func theCheckOpensTheAppOnceApproved() async throws {
        let backend = DemoBackend(seeded: true, requireSelfie: true)
        #expect(try await backend.accountState().selfieCleared == false)

        let challenge = try await backend.startVerification()
        let clip = RecordedClip(fileURL: URL(fileURLWithPath: "/tmp/selfie.mp4"), durationSeconds: 5, thumbnailJPEG: nil)
        try await backend.submitVerification(challenge, clip: clip)
        #expect(try await backend.fetchMyProfile()?.verificationStatus == "pending")
        #expect(try await backend.accountState().selfieCleared == false, "waiting for a person")

        try await Task.sleep(for: .seconds(3))
        #expect(try await backend.accountState().selfieCleared == true)
        #expect(try await backend.fetchMyProfile()?.isVerified == true)
    }
}
