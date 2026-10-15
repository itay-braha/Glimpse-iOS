import Foundation
import MetricKit

/// Free, first-party crash and hang reporting: MetricKit delivers diagnostic
/// payloads (crashes, hangs, disk/CPU exceptions) on the next launch and we
/// forward them to the `private.client_diagnostics` table.
final class DiagnosticsReporter: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = DiagnosticsReporter()

    @MainActor static var backend: (any GlimpseBackend)?

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let reports = payloads.map { $0.jsonRepresentation() }
        Task { @MainActor in
            guard let backend = DiagnosticsReporter.backend else { return }
            for report in reports {
                await backend.reportDiagnostic(kind: "metrickit_diagnostic", payload: report, appVersion: version)
            }
        }
    }
}
