import Foundation
import Observation

@MainActor
@Observable
final class AuthFlowModel {
    enum Step {
        case welcome
        case phone
        case code
    }

    var step: Step = .welcome
    var dialCode = DialCode.current
    var nationalNumber = ""
    var code = ""
    private(set) var isWorking = false
    var errorMessage: String?

    private(set) var e164: String?

    var canSendCode: Bool {
        PhoneNumber.e164(dialCode: dialCode.code, national: nationalNumber) != nil && !isWorking
    }

    func sendCode(using backend: any GlimpseBackend) async {
        guard let number = PhoneNumber.e164(dialCode: dialCode.code, national: nationalNumber) else {
            errorMessage = GlimpseError.invalidPhoneNumber.errorDescription
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await backend.sendCode(to: number)
            e164 = number
            code = ""
            errorMessage = nil
            step = .code
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    /// Returns true once the code is accepted.
    func verify(using backend: any GlimpseBackend) async -> Bool {
        guard let e164, code.count == 6, !isWorking else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await backend.verifyCode(code, phone: e164)
            errorMessage = nil
            return true
        } catch {
            code = ""
            errorMessage = GlimpseError.describe(error)
            return false
        }
    }
}
