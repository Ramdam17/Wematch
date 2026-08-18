import Foundation
import OSLog

/// The phone's ear on the Watch. Split from `RoomViewModel.swift` to keep that
/// file under the length limit, the same way the dashboard recording is.
extension RoomViewModel {

    /// Consumes the Watch's message stream through the injected protocol — no
    /// singleton, no downcast. `receivedMessages` already existed on
    /// `WatchConnectivityServiceProtocol` and nothing read it, which is why the
    /// Watch could report a dead heart-rate feed that the phone never heard.
    func startObservingWatchMessages() {
        watchMessageTask = Task { [weak self] in
            guard let stream = self?.watchService.receivedMessages else { return }

            for await message in stream {
                guard !Task.isCancelled else { break }
                guard let type = message["type"] as? String, type == "heartRateStatus" else {
                    continue
                }
                guard let raw = message["status"] as? String,
                      let status = WatchHeartRateStatus(rawValue: raw) else {
                    Log.watchConnectivity.error("Unrecognised heart rate status payload")
                    continue
                }
                self?.watchHeartRateStatus = status
                if status.needsAttention {
                    Log.rooms.error("Watch heart rate unavailable: \(status.rawValue, privacy: .public)")
                }
            }
        }
    }
}
