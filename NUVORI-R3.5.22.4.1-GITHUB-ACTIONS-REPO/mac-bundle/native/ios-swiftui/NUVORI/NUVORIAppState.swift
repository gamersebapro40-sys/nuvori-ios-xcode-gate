import Foundation

@MainActor
final class NUVORIAppState: ObservableObject {
    @Published var query = ""
    @Published var results: [FoodResult] = []
    @Published var status = ""
    let api: NUVORIAPIClient

    init() {
        // R3.5.22.3.1 — one APIClient, injected environment + Keychain credential provider.
        api = NUVORIAPIClient(
            baseURL: NUVORIEnvironment.apiBaseURL,
            credentialStore: NUVORIKeychainStore.shared
        )
    }

    func search(_ text: String) async {
        query = text
        do { results = try await api.searchFoods(text); status = "" }
        catch { status = error.localizedDescription }
    }
}

struct FoodResult: Codable, Identifiable {
    let id: String
    let name: String
    let brand: String?
}
