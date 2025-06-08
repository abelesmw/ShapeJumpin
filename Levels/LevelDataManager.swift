import Foundation

class LevelDataManager {
    static let shared = LevelDataManager()
    private let userDefaults = UserDefaults.standard

    private init() {}

    /// Saves a new high score for a specific level, if it's better than the existing one.
    func saveHighScore(forLevel levelID: String, score: Int) {
        let currentHighScore = getHighScore(forLevel: levelID) ?? 0
        if score > currentHighScore {
            userDefaults.set(score, forKey: "highScore_\(levelID)")
            print("New high score for \(levelID): \(score) saved locally.")
        }
    }

    /// Retrieves the locally stored high score for a specific level.
    /// Returns nil if no score is stored or if the score is 0 (assuming 0 isn't a valid score).
    func getHighScore(forLevel levelID: String) -> Int? {
        let score = userDefaults.integer(forKey: "highScore_\(levelID)")
        return score == 0 ? nil : score // Adjust if 0 is a valid high score
    }
}
