import Foundation
import AgentPetCore

/// Pushes per-pet care stats to the community site so the user's web profile
/// shows their companions' levels. Linked once via a short pairing code from
/// the profile page; afterwards stats sync in the background (debounced after
/// each feeding, and on launch).
@MainActor
final class CareSyncController: ObservableObject {
    static let shared = CareSyncController()

    /// True when a device token is stored (the app is linked to a profile).
    @Published private(set) var linked: Bool
    /// Last sync result, for the Care tab's status caption.
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var lastError: String?

    private static let tokenKey = "agentpet.care.syncToken"
    private static let base = URL(string: "https://agentpet.thenightwatcher.online")!

    private var debounce: Timer?

    init() {
        linked = UserDefaults.standard.string(forKey: Self.tokenKey) != nil
    }

    func start() {
        guard linked else { return }
        scheduleSync(after: 5)
    }

    // MARK: - Pairing

    /// Exchanges a profile pairing code for a device token.
    func pair(code: String) async -> Bool {
        struct Response: Decodable { let token: String }
        var request = URLRequest(url: Self.base.appendingPathComponent("api/care/pair"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        ])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                lastError = NSLocalizedString("Code not recognized. Codes expire after 10 minutes.", comment: "")
                return false
            }
            let token = try JSONDecoder().decode(Response.self, from: data).token
            UserDefaults.standard.set(token, forKey: Self.tokenKey)
            linked = true
            lastError = nil
            scheduleSync(after: 1)
            return true
        } catch {
            lastError = NSLocalizedString("Could not reach the server.", comment: "")
            return false
        }
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: Self.tokenKey)
        linked = false
        lastSyncAt = nil
        lastError = nil
    }

    // MARK: - Sync

    /// Debounced push — call freely after every feeding.
    func scheduleSync(after seconds: TimeInterval = 30) {
        guard linked else { return }
        debounce?.invalidate()
        debounce = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
            Task { @MainActor [weak self] in await self?.push() }
        }
    }

    func push() async {
        guard let token = UserDefaults.standard.string(forKey: Self.tokenKey) else { return }
        let states = PetCareController.shared.states
        guard !states.isEmpty else { return }

        let pets: [[String: Any]] = states.map { id, s in
            let name = ImagePetStore.shared.pack(id: id)?.displayName ?? id
            return [
                "id": id,
                "name": name,
                "xp": s.xp,
                "tokens": s.totalTokens,
                "meals": s.totalMeals,
                "streak": s.streakDays,
                "lastFedAt": s.lastFedAt.map { Int($0.timeIntervalSince1970) } as Any,
            ]
        }

        var request = URLRequest(url: Self.base.appendingPathComponent("api/care/sync"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["pets": pets])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 {
                lastSyncAt = Date()
                lastError = nil
            } else if status == 401 {
                // Token revoked from the web side: unlink quietly.
                disconnect()
            } else {
                lastError = NSLocalizedString("Sync failed, will retry.", comment: "")
                scheduleSync(after: 300)
            }
        } catch {
            lastError = NSLocalizedString("Sync failed, will retry.", comment: "")
            scheduleSync(after: 300)
        }
    }
}
