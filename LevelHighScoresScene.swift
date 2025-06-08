import SpriteKit

class LevelHighScoresScene: SKScene {

    private let levelID: String
    private let currentUserID: String = UserDefaults.standard.string(forKey: "userID") ?? "unknownUserID"

    // Layout constants
    private let titleYPosition: CGFloat = 0.90       // Original ratio for title
    private let backButtonYPosition: CGFloat = 0.90 // Adjusted for top position
    private let backButtonXPosition: CGFloat = 0.1 // Adjusted for left position
    private let scoresStartYPosition: CGFloat = 0.80 // Original ratio for start of scores
    private let scoreEntryVerticalSpacing: CGFloat = 25
    private let rankXPositionRatio: CGFloat = 0.38
    private let usernameXPositionRatio: CGFloat = 0.43
    private let scoreXPositionRatio: CGFloat = 0.62
    private let scoreFontSize: CGFloat = 19 // New font size for scores

    // Pixel adjustment value
    private let yPixelAdjustment: CGFloat = 20.0

    init(size: CGSize, levelID: String) {
        self.levelID = levelID
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor.black

        setupStaticUI()
        fetchAndDisplayScores()
    }

    func setupStaticUI() {
        var formattedLevelID = levelID.capitalized
        if let range = formattedLevelID.range(of: "Level") {
            if range.upperBound < formattedLevelID.endIndex {
                let characterAfterLevel = formattedLevelID[range.upperBound]
                if characterAfterLevel.isNumber {
                    formattedLevelID.insert(" ", at: range.upperBound)
                }
            }
        }

        let titleText = "Leaderboard - \(formattedLevelID)"
        let titleLabel = SKLabelNode(text: titleText)
        titleLabel.fontSize = 32; titleLabel.fontName = "Avenir-Black"; titleLabel.fontColor = .cyan
        // Adjusted Y position for title
        titleLabel.position = CGPoint(x: size.width / 2, y: (size.height * titleYPosition) - yPixelAdjustment)
        addChild(titleLabel)

        let backButton = SKLabelNode(text: "Back") // Changed text
        backButton.fontSize = 24; backButton.fontName = "Avenir-Black"; backButton.fontColor = .white
        // Positioned to top left
        backButton.horizontalAlignmentMode = .left
        backButton.position = CGPoint(x: size.width * backButtonXPosition, y: (size.height * backButtonYPosition) - yPixelAdjustment)
        backButton.name = "backToLevelsMenuButton"
        addChild(backButton)
    }

    func fetchAndDisplayScores() {
        LevelLeaderboardManager.shared.fetchTopScores(forLevel: self.levelID) { [weak self] entries in
            guard let self = self else { return }

            if entries.isEmpty {
                let noScoresLabel = SKLabelNode(text: "No scores yet for this level!")
                noScoresLabel.fontSize = 20; noScoresLabel.fontName = "Avenir-Black"; noScoresLabel.fontColor = .gray
                // Adjust noScoresLabel position if it should also move relative to the title/scores area
                noScoresLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.5 - self.yPixelAdjustment)
                self.addChild(noScoresLabel)
                return
            }

            // Base Y position for the first score entry, adjusted down
            let initialScoresY = (self.size.height * self.scoresStartYPosition) - self.yPixelAdjustment - 10

            for (index, entry) in entries.enumerated() {
                // Adjusted Y position for each score entry
                let yPosition = initialScoresY - (CGFloat(index) * self.scoreEntryVerticalSpacing)
                let isCurrentUserEntry = entry.userID == self.currentUserID
                let entryColor: SKColor = isCurrentUserEntry ? .green : .white

                let rankLabel = SKLabelNode(text: "\(index + 1).")
                rankLabel.fontSize = self.scoreFontSize; rankLabel.fontName = "Avenir-Black"; rankLabel.fontColor = entryColor // Adjusted font size
                rankLabel.horizontalAlignmentMode = .right
                rankLabel.position = CGPoint(x: self.size.width * self.rankXPositionRatio, y: yPosition)
                self.addChild(rankLabel)

                let usernameLabel = SKLabelNode(text: entry.username)
                usernameLabel.fontSize = self.scoreFontSize; usernameLabel.fontName = "Avenir-Black"; usernameLabel.fontColor = entryColor // Adjusted font size
                usernameLabel.horizontalAlignmentMode = .left
                usernameLabel.position = CGPoint(x: self.size.width * self.usernameXPositionRatio, y: yPosition)
                self.addChild(usernameLabel)

                let scoreLabel = SKLabelNode(text: "\(entry.score)")
                scoreLabel.fontSize = self.scoreFontSize; scoreLabel.fontName = "Avenir-Black"; scoreLabel.fontColor = entryColor // Adjusted font size
                scoreLabel.horizontalAlignmentMode = .right
                scoreLabel.position = CGPoint(x: self.size.width * self.scoreXPositionRatio, y: yPosition)
                self.addChild(scoreLabel)
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let locationInScene = touch.location(in: self)

        if let tappedNode = atPoint(locationInScene) as? SKLabelNode, tappedNode.name == "backToLevelsMenuButton" {
            let originalColor = tappedNode.fontColor
            tappedNode.fontColor = SKColor.cyan.withAlphaComponent(0.7)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                tappedNode.fontColor = originalColor
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let levelsMenuScene = LevelsMenuScene(size: self.size)
                levelsMenuScene.scaleMode = .aspectFill
                self.view?.presentScene(levelsMenuScene, transition: .fade(withDuration: 0.5))
            }
        }
    }
}
