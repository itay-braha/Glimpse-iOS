import DeviceCheck
import Foundation

/// Produces the Apple DeviceCheck token the `device-check` function uses to read
/// and set this iPhone's persistent ban bit.
enum DeviceAttestation {
    struct Payload: Encodable, Sendable {
        let deviceToken: String?
        let isSimulator: Bool

        enum CodingKeys: String, CodingKey {
            case deviceToken = "device_token"
            case isSimulator = "is_simulator"
        }
    }

    static func payload() async -> Payload {
        #if targetEnvironment(simulator)
        return Payload(deviceToken: nil, isSimulator: true)
        #else
        guard DCDevice.current.isSupported,
              let token = try? await DCDevice.current.generateToken()
        else { return Payload(deviceToken: nil, isSimulator: false) }
        return Payload(deviceToken: token.base64EncodedString(), isSimulator: false)
        #endif
    }
}
