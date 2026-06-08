import Foundation

struct TerminationEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var keyword: String
    var appName: String
}

class TerminationSettings: ObservableObject {
    static let shared = TerminationSettings()

    @Published var entries: [TerminationEntry] {
        didSet { save() }
    }

    private let key = "terminationEntries"

    private init() {
        if let data = UserDefaults.standard.data(forKey: "terminationEntries"),
           let decoded = try? JSONDecoder().decode([TerminationEntry].self, from: data) {
            entries = decoded
        } else {
            entries = [
                .init(keyword: "크롬",    appName: "Google Chrome"),
                .init(keyword: "파이어폭스", appName: "Firefox"),
                .init(keyword: "파폭",    appName: "Firefox"),
                .init(keyword: "클로드",  appName: "Claude"),
                .init(keyword: "슬랙",    appName: "Slack"),
                .init(keyword: "디스코드", appName: "Discord"),
                .init(keyword: "노션",    appName: "Notion"),
                .init(keyword: "인텔리제이", appName: "IntelliJ IDEA"),
                .init(keyword: "도커",    appName: "Docker Desktop"),
                .init(keyword: "스포티파이", appName: "Spotify"),
            ]
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
