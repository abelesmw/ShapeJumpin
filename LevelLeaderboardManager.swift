import Foundation
import FirebaseFirestore
import Firebase

struct LevelLeaderboardEntry: Identifiable { // Added Identifiable for potential SwiftUI use
    let id: String // Document ID
    let score: Int
    let username: String
    let userID: String
    let timestamp: TimeInterval
    let levelID: String // Specific to level entries
}

class LevelLeaderboardManager {
    static let shared = LevelLeaderboardManager()
    private let db = Firestore.firestore()
    private let collectionName = "levelLeaderboards" // Dedicated collection for level scores
    private let scoreDisplayLimit = 10 // Max scores to show on a level's leaderboard
    private let userNameKey = "username" // UserDefaults key for username
    private let userIDKey = "userID"     // UserDefaults key for userID

    private init() {}

    // MARK: - User Identification and Username
    
    /// Retrieves or creates a unique userID for the player.
    private func getPlayerUserID() -> String {
        let userDefaults = UserDefaults.standard
        if let existingUserID = userDefaults.string(forKey: userIDKey) {
            return existingUserID
        } else {
            let newUserID = UUID().uuidString
            userDefaults.set(newUserID, forKey: userIDKey)
            return newUserID
        }
    }

    /// Ensures a username exists in UserDefaults; if not, assigns a default "yo####" name.
    /// This can be called by UI elements when a username is needed.
    func ensureUsernameExists() -> String {
        let userDefaults = UserDefaults.standard
        if let existingName = userDefaults.string(forKey: userNameKey), !existingName.isEmpty {
            return existingName
        }
        
        let randomNum = Int.random(in: 1000...9999)
        let defaultName = "yo\(randomNum)"
        userDefaults.set(defaultName, forKey: userNameKey)
        // Note: This doesn't save to Firestore's "usernames" collection.
        // That logic is typically in UserNameScene.swift for explicit username creation/validation.
        return defaultName
    }
    
    /// Gets the current username from UserDefaults.
    private func getCurrentUsername() -> String {
        return UserDefaults.standard.string(forKey: userNameKey) ?? ensureUsernameExists()
    }

    // MARK: - Score Submission

    /// Submits a new score for a specific level.
    /// It will only store one score per user per level – the highest one.
    /// - Parameters:
    ///   - levelID: The identifier for the level (e.g., "level1", "desertZone").
    ///   - newScore: The score achieved by the player.
    ///   - completion: An optional closure called with an error if one occurs.
    func submitScore(levelID: String, score newScore: Int, completion: ((Error?) -> Void)? = nil) {
        let userID = getPlayerUserID()
        let username = getCurrentUsername() // Get current username

        // Query for an existing score by this user for this specific level
        db.collection(collectionName)
            .whereField("userID", isEqualTo: userID)
            .whereField("levelID", isEqualTo: levelID)
            .limit(to: 1) // Should only be one, but limit just in case
            .getDocuments { [weak self] (querySnapshot, error) in
                guard let self = self else { return }

                if let error = error {
                    print("Error fetching existing score for level \(levelID): \(error.localizedDescription)")
                    completion?(error)
                    return
                }

                if let existingDocument = querySnapshot?.documents.first {
                    // User has an existing score for this level
                    let currentScore = existingDocument.data()["score"] as? Int ?? 0
                    if newScore > currentScore {
                        // New score is higher, update the existing document
                        existingDocument.reference.updateData([
                            "score": newScore,
                            "username": username, // Update username in case it changed
                            "timestamp": FieldValue.serverTimestamp() // Use server timestamp
                        ]) { err in
                            if let err = err {
                                print("Error updating score for level \(levelID): \(err.localizedDescription)")
                            } else {
                                print("Score updated for user \(userID) on level \(levelID) to \(newScore)")
                            }
                            completion?(err)
                        }
                    } else {
                        // New score is not higher, do nothing
                        print("New score (\(newScore)) is not higher than current (\(currentScore)) for level \(levelID). No update.")
                        completion?(nil)
                    }
                } else {
                    // No existing score for this user on this level, add a new document
                    var data: [String: Any] = [
                        "userID": userID,
                        "username": username,
                        "score": newScore,
                        "levelID": levelID,
                        "timestamp": FieldValue.serverTimestamp() // Use server timestamp
                    ]
                    
                    self.db.collection(self.collectionName).addDocument(data: data) { err in
                        if let err = err {
                            print("Error adding new score for level \(levelID): \(err.localizedDescription)")
                        } else {
                            print("New score added for user \(userID) on level \(levelID): \(newScore)")
                        }
                        completion?(err)
                    }
                }
            }
    }

    // MARK: - Score Fetching

    /// Fetches the top scores for a specific level.
    /// - Parameters:
    ///   - levelID: The identifier of the level.
    ///   - completion: A closure called with an array of `LeaderboardEntry` objects.
    func fetchTopScores(forLevel levelID: String, completion: @escaping ([LevelLeaderboardEntry]) -> Void) {
        db.collection(collectionName)
            .whereField("levelID", isEqualTo: levelID) // Filter by the specific level
            .order(by: "score", descending: true)    // Highest scores first
            .limit(to: scoreDisplayLimit)             // Limit the number of results
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching top scores for level \(levelID): \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    print("No documents found for level \(levelID).")
                    completion([])
                    return
                }

                let entries: [LevelLeaderboardEntry] = documents.compactMap { doc -> LevelLeaderboardEntry? in
                    let data = doc.data()
                    guard
                        let score = data["score"] as? Int,
                        let username = data["username"] as? String,
                        let userID = data["userID"] as? String,
                        // Firestore timestamp can be fetched as Timestamp, then converted
                        let firestoreTimestamp = data["timestamp"] as? Timestamp,
                        let levelIDFromDoc = data["levelID"] as? String // Ensure levelID is present
                    else {
                        print("Failed to parse document data: \(doc.documentID)")
                        return nil
                    }
                    
                    // Defensive check, though query should ensure this
                    if levelIDFromDoc != levelID {
                         print("Mismatch levelID in document \(doc.documentID). Expected \(levelID), got \(levelIDFromDoc)")
                        return nil
                    }

                    return LevelLeaderboardEntry(
                        id: doc.documentID,
                        score: score,
                        username: username,
                        userID: userID,
                        timestamp: firestoreTimestamp.dateValue().timeIntervalSince1970, // Convert to TimeInterval
                        levelID: levelIDFromDoc
                    )
                }
                completion(entries)
            }
    }
}
