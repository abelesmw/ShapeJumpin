import SpriteKit

class GameOverScene: SKScene {
    var finalScore: Int = 0
    
    // How many times we'll attempt to fetch the updated leaderboard
    private let maxFetchAttempts = 5
    // How long we wait between attempts (in seconds)
    private let fetchRetryDelay: TimeInterval = 0.3
    // To track how many fetch attempts we've done
    private var currentFetchAttempt = 0
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        
        // Layout parameters
        let margin: CGFloat = 40
        let titleSpacing: CGFloat = 70
        let buttonSpacing: CGFloat = 60
        let scoreSpacing: CGFloat = 40
        
        let leftColumnX = size.width * 0.3
        let rightColumnX = size.width * 0.7
        
        // --- Left Column ---
        var currentLeftY = size.height - margin - 50
        
        // "Your Score:" Title
        let scoreTitleLabel = SKLabelNode(text: "Your Score:")
        scoreTitleLabel.fontSize = 45
        scoreTitleLabel.fontName = "Avenir-Black"
        scoreTitleLabel.fontColor = SKColor(red: 0.5, green: 1.0, blue: 0.7, alpha: 1.0)
        scoreTitleLabel.position = CGPoint(x: leftColumnX, y: currentLeftY)
        scoreTitleLabel.horizontalAlignmentMode = .center
        addChild(scoreTitleLabel)
        
        // Final Score Value
        currentLeftY -= titleSpacing
        let finalScoreLabel = SKLabelNode(text: "\(finalScore)")
        finalScoreLabel.fontSize = 45
        finalScoreLabel.fontName = "Avenir-Black"
        finalScoreLabel.fontColor = SKColor(red: 0.5, green: 1.0, blue: 0.7, alpha: 1.0)
        finalScoreLabel.position = CGPoint(x: leftColumnX, y: currentLeftY)
        finalScoreLabel.horizontalAlignmentMode = .center
        addChild(finalScoreLabel)
        
        // Label for "Congrats!" message if top 20
        currentLeftY -= 40
        let leaderboardRankLabel = SKLabelNode(text: "")
        leaderboardRankLabel.fontSize = 18
        leaderboardRankLabel.fontName = "Avenir-Black"
        leaderboardRankLabel.fontColor = .green
        leaderboardRankLabel.position = CGPoint(x: leftColumnX + 15, y: currentLeftY)
        leaderboardRankLabel.horizontalAlignmentMode = .center
        leaderboardRankLabel.alpha = 0.0 // Hidden initially
        addChild(leaderboardRankLabel)
        
        // We'll attempt to fetch the updated leaderboard
        // multiple times if the user doesn't appear immediately
        runFetchSequence(labelToUpdate: leaderboardRankLabel)
        
        // --- Buttons ---
        currentLeftY -= titleSpacing
        let buttonWidth = size.width * 0.3
        
        let playAgainButton = createButton(text: "Play Again", width: buttonWidth)
        playAgainButton.name = "playAgain"
        playAgainButton.position = CGPoint(x: leftColumnX, y: currentLeftY + 20)
        addChild(playAgainButton)
        
        currentLeftY -= buttonSpacing
        let menuButton = createButton(text: "Main Menu", width: buttonWidth)
        menuButton.name = "mainMenu"
        menuButton.position = CGPoint(x: leftColumnX, y: currentLeftY + 20)
        addChild(menuButton)
        
        // --- Right Column ---
        var currentRightY = size.height - margin - 50
        let topScoresTitle = SKLabelNode(text: "Your Top 5")
        topScoresTitle.fontSize = 36
        topScoresTitle.fontName = "Avenir-Black"
        topScoresTitle.fontColor = .white
        topScoresTitle.position = CGPoint(x: rightColumnX, y: currentRightY)
        topScoresTitle.horizontalAlignmentMode = .center
        addChild(topScoresTitle)
        
        currentRightY -= titleSpacing
        
        // Local top 5 from RunDataManager
        let topScores = RunDataManager.shared.topScores
        for (index, score) in topScores.enumerated() {
            let scoreLabel = SKLabelNode(text: "\(index + 1). \(score)")
            scoreLabel.fontSize = 28
            scoreLabel.fontName = "Avenir-Black"
            scoreLabel.fontColor = (score == finalScore) ? .green : .white
            scoreLabel.position = CGPoint(x: rightColumnX, y: currentRightY)
            scoreLabel.horizontalAlignmentMode = .center
            addChild(scoreLabel)
            currentRightY -= scoreSpacing
        }
    }
    
    // MARK: - Leaderboard Fetch Retry Logic
    private func runFetchSequence(labelToUpdate: SKLabelNode) {
        // Attempt to fetch the scoreboard repeatedly until we find
        // the user’s score or we run out of attempts
        let fetchAction = SKAction.run { [weak self] in
            self?.tryFetchTopScores(labelToUpdate: labelToUpdate)
        }
        let waitAction = SKAction.wait(forDuration: fetchRetryDelay)
        
        // We'll do: fetch -> wait -> fetch -> wait -> ... up to maxFetchAttempts times
        var sequenceActions: [SKAction] = []
        
        for _ in 1...maxFetchAttempts {
            sequenceActions.append(fetchAction)
            // We don't wait after the final attempt
            sequenceActions.append(waitAction)
        }
        
        // Remove the last wait so we don't wait unnecessarily after final fetch
        sequenceActions.removeLast()
        
        run(SKAction.sequence(sequenceActions))
    }
    
    private func tryFetchTopScores(labelToUpdate: SKLabelNode) {
        LeaderboardManager.shared.fetchTopScores { [weak self] entries in
            guard let self = self else { return }
            self.currentFetchAttempt += 1
            
            let userID = UserDefaults.standard.string(forKey: "userID") ?? "unknownID"
            
            // Find the first index matching userID & finalScore
            if let idx = entries.firstIndex(where: {
                $0.userID == userID && $0.score == self.finalScore
            }) {
                let rank = idx + 1
                labelToUpdate.text = "Congrats! You got #\(rank) on the public leaderboard!"
                labelToUpdate.alpha = 1.0
                // Once found, we can stop future attempts
                self.removeAllActions()
            } else {
                // Not found yet; if we still have attempts left, we continue
                if self.currentFetchAttempt >= self.maxFetchAttempts {
                    // If we never find the user, do nothing special.
                    // The label remains hidden.
                }
            }
        }
    }
    
    // MARK: - Button Creation
    func createButton(text: String, width: CGFloat) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: 50), cornerRadius: 10)
        button.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        button.strokeColor = .clear
        
        let label = SKLabelNode(text: text)
        label.fontSize = 28
        label.fontName = "Avenir-Black"
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 0)
        label.horizontalAlignmentMode = .center
        label.isUserInteractionEnabled = false
        button.addChild(label)
        
        return button
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)
        
        for node in tappedNodes {
            if let button = node as? SKShapeNode,
               button.name == "playAgain" || button.name == "mainMenu" {
                highlightButton(button)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.unhighlightButton(button)
                    switch button.name {
                    case "playAgain":
                        self.startNewGame()
                    case "mainMenu":
                        self.goToMainMenu()
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private func highlightButton(_ button: SKShapeNode) {
        button.fillColor = .lightGray
    }
    
    private func unhighlightButton(_ button: SKShapeNode) {
        button.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
    }
    
    // MARK: - Navigation
    private func startNewGame() {
        let gameScene = GameScene(size: size)
        gameScene.scaleMode = .aspectFill
        view?.presentScene(gameScene, transition: .fade(withDuration: 0.5))
    }
    
    private func goToMainMenu() {
        let mainMenu = MainMenuScene(size: size)
        mainMenu.scaleMode = .aspectFill
        view?.presentScene(mainMenu, transition: .fade(withDuration: 0.5))
    }
}
