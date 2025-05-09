import Foundation
import FirebaseFirestore
import Firebase

struct LeaderboardEntry {
    let id: String
    let score: Int
    let username: String
    let userID: String
    let timestamp: TimeInterval
}

class LeaderboardManager {
    static let shared = LeaderboardManager()
    
    private let db = Firestore.firestore()
    private let collectionName = "leaderboard"
    private let userScoreLimit = 1 // Changed to 1
    private let globalScoreLimit = 20
    private let userNameKey = "username"
    
    /// Submits a new score (max 1 per userID; replaces the existing if new score is higher).
    func submitScore(_ newScore: Int, completion: ((Error?) -> Void)? = nil) {
        
        // Ensure we have a userID
        let userDefaults = UserDefaults.standard
        if userDefaults.string(forKey: "userID") == nil {
            userDefaults.set(UUID().uuidString, forKey: "userID")
        }
        let userID = userDefaults.string(forKey: "userID") ?? "unknownID"
        
        // Always ensure there's a username (yo#### if none set)
        let username = ensureUsernameExists()
        
        // Fetch existing documents for this userID
        db.collection(collectionName)
            .whereField("userID", isEqualTo: userID)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    completion?(error)
                    return
                }
                
                let docs = snapshot?.documents ?? []
                // Sort by descending score (highest first)
                let sortedDocs = docs.sorted {
                    let scoreA = ($0.data()["score"] as? Int) ?? 0
                    let scoreB = ($1.data()["score"] as? Int) ?? 0
                    return scoreA > scoreB
                }
                
                // If none exist, just add the new score
                if sortedDocs.isEmpty {
                    self.addScore(newScore, username: username, userID: userID, completion: completion)
                    return
                }
                
                // Otherwise, check if newScore is higher than the existing
                if let doc = sortedDocs.first,
                   let currentScore = doc.data()["score"] as? Int,
                   newScore > currentScore {
                    doc.reference.delete { delErr in
                        if let delErr = delErr {
                            completion?(delErr)
                            return
                        }
                        self.addScore(newScore, username: username, userID: userID, completion: completion)
                    }
                } else {
                    // Not higher than the existing, do nothing
                    completion?(nil)
                }
            }
    }
    
    /// Helper to add a score document
    private func addScore(_ score: Int,
                          username: String,
                          userID: String,
                          completion: ((Error?) -> Void)?) {
        db.collection(collectionName).addDocument(data: [
            "score": score,
            "username": username,
            "userID": userID,
            "timestamp": Date().timeIntervalSince1970
        ]) { error in
            completion?(error)
        }
    }
    
    /// Ensures a username exists; if not, assigns "yo####".
    func ensureUsernameExists() -> String {
        let userDefaults = UserDefaults.standard
        if let existingName = userDefaults.string(forKey: userNameKey), !existingName.isEmpty {
            return existingName
        }
        
        // If no username is set, generate one
        let randomNum = Int.random(in: 1000...9999)
        let defaultName = "yo\(randomNum)"
        userDefaults.set(defaultName, forKey: userNameKey)
        return defaultName
    }
    
    /// Fetches up to 20 top scores globally (sorted descending in-memory).
    func fetchTopScores(completion: @escaping ([LeaderboardEntry]) -> Void) {
        db.collection(collectionName).getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching leaderboard: \(error)")
                completion([])
                return
            }
            guard let docs = snapshot?.documents else {
                completion([])
                return
            }
            
            let allEntries = docs.compactMap { doc -> LeaderboardEntry? in
                let data = doc.data()
                guard let score = data["score"] as? Int,
                      let username = data["username"] as? String,
                      let userID = data["userID"] as? String,
                      let timestamp = data["timestamp"] as? Double else {
                    return nil
                }
                return LeaderboardEntry(
                    id: doc.documentID,
                    score: score,
                    username: username,
                    userID: userID,
                    timestamp: timestamp
                )
            }
            
            // Sort descending, take top 20
            let topEntries = allEntries.sorted { $0.score > $1.score }
                                      .prefix(self.globalScoreLimit)
            completion(Array(topEntries))
        }
    }
}
