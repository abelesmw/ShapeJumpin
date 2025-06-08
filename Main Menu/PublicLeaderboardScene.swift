import SpriteKit

class PublicLeaderboardScene: SKScene {
    
    let rainbowColors: [SKColor] = [
        .red, .orange, .yellow, .green, .blue, .systemIndigo, .purple
    ]
    
    private let labelSpacing: CGFloat = 28
    private let rankXOffset: CGFloat = -210
    private let usernameXOffset: CGFloat = -180
    private let scoreXOffset: CGFloat = -40
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        
        // Title
        let titleLabel = SKLabelNode(text: "Public Leaderboard")
        titleLabel.fontSize = 36
        titleLabel.fontName = "Avenir-Black"
        titleLabel.fontColor = .cyan
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.85)
        addChild(titleLabel)
        
        // Back button
        let backButton = SKLabelNode(text: "Back")
        backButton.fontName = "Avenir-Black"
        backButton.fontSize = 28
        backButton.fontColor = .white
        backButton.position = CGPoint(x: 60, y: size.height - 50)
        backButton.name = "backButton"
        addChild(backButton)
        
        // Identify current user's userID to color their scores in cyan
        let currentUserID = UserDefaults.standard.string(forKey: "userID") ?? "unknownID"
        
        // Fetch top scores, place in two columns
        LeaderboardManager.shared.fetchTopScores { [weak self] entries in
            guard let self = self else { return }
            if entries.isEmpty {
                print("No entries found in leaderboard!")
            }
            
            let topY = self.size.height * 0.75
            
            // Left column: ranks 1..10
            for (i, entry) in entries.prefix(10).enumerated() {
                let rank = i + 1
                
                // Rank label
                let rankLabel = SKLabelNode(text: "\(rank)")
                rankLabel.fontSize = 20
                rankLabel.fontName = "Avenir-Black"
                rankLabel.horizontalAlignmentMode = .left
                rankLabel.fontColor = (entry.userID == currentUserID) ? .green : .white
                rankLabel.position = CGPoint(x: (self.size.width / 2) + self.rankXOffset, y: topY - (CGFloat(i) * self.labelSpacing))
                self.addChild(rankLabel)
                
                // Username label
                let usernameLabel = SKLabelNode(text: "\(entry.username)")
                usernameLabel.fontSize = 20
                usernameLabel.fontName = "Avenir-Black"
                usernameLabel.horizontalAlignmentMode = .left
                usernameLabel.fontColor = (entry.userID == currentUserID) ? .green : .white
                usernameLabel.position = CGPoint(x: (self.size.width / 2) + self.usernameXOffset, y: topY - (CGFloat(i) * self.labelSpacing))
                self.addChild(usernameLabel)
                
                // Score label
                let scoreLabel = SKLabelNode(text: "\(entry.score)")
                scoreLabel.fontSize = 20
                scoreLabel.fontName = "Avenir-Black"
                scoreLabel.horizontalAlignmentMode = .right
                scoreLabel.fontColor = (entry.userID == currentUserID) ? .green : .white
                scoreLabel.position = CGPoint(x: (self.size.width / 2) + self.scoreXOffset - 5, y: topY - (CGFloat(i) * self.labelSpacing))
                self.addChild(scoreLabel)
            }
            
            // Right column: ranks 11..20
            for (i, entry) in entries.dropFirst(10).prefix(10).enumerated() {
                let rank = i + 11
                
                // Rank label
                let rankLabel = SKLabelNode(text: "\(rank)")
                rankLabel.fontSize = 20
                rankLabel.fontName = "Avenir-Black"
                rankLabel.horizontalAlignmentMode = .left
                rankLabel.fontColor = (entry.userID == currentUserID) ? .green : .white
                rankLabel.position = CGPoint(x: (self.size.width / 2) + self.rankXOffset + 250, y: topY - (CGFloat(i) * self.labelSpacing))
                self.addChild(rankLabel)
                
                // Username label
                let usernameLabel = SKLabelNode(text: "\(entry.username)")
                usernameLabel.fontSize = 20
                usernameLabel.fontName = "Avenir-Black"
                usernameLabel.horizontalAlignmentMode = .left
                usernameLabel.fontColor = (entry.userID == currentUserID) ? .cyan : .white
                usernameLabel.position = CGPoint(x: (self.size.width / 2) + self.usernameXOffset + 255, y: topY - (CGFloat(i) * self.labelSpacing))
                self.addChild(usernameLabel)
                
                // Score label
                let scoreLabel = SKLabelNode(text: "\(entry.score)")
                scoreLabel.fontSize = 20
                scoreLabel.fontName = "Avenir-Black"
                scoreLabel.horizontalAlignmentMode = .right
                scoreLabel.fontColor = (entry.userID == currentUserID) ? .cyan : .white
                scoreLabel.position = CGPoint(x: (self.size.width / 2) + self.scoreXOffset + 252, y: topY - (CGFloat(i) * self.labelSpacing))
                self.addChild(scoreLabel)
            }
        }
        
        // Decorative shapes
        let spawn = SKAction.run { [weak self] in
            self?.spawnRandomShape()
        }
        let wait = SKAction.wait(forDuration: 1.0)
        run(SKAction.repeatForever(SKAction.sequence([spawn, wait])))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        let tappedNodes = nodes(at: location)
        for node in tappedNodes {
                if node.name == "backButton", let labelNode = node as? SKLabelNode {
                    // Highlight
                    let originalColor = labelNode.fontColor
                    labelNode.fontColor = .cyan
                    
                    // Delay 0.25s to show highlight before transitioning
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        labelNode.fontColor = originalColor
                        let menu = MainMenuScene(size: self.size)
                        menu.scaleMode = .aspectFill
                        self.view?.presentScene(menu, transition: .fade(withDuration: 0.5))
                    }
                }
            }
    }
    
    // Spawns shapes in the background
    private func spawnRandomShape() {
        let possibleSides = [3, 4, 6]
        let sides = possibleSides.randomElement() ?? 3
        
        let mainShape = SKShapeNode(path: polygonPath(sides: sides, radius: 8))
        mainShape.fillColor = rainbowColors.randomElement() ?? .white
        mainShape.strokeColor = .clear
        mainShape.alpha = 0.1
        mainShape.zPosition = -1
        
        let glowShape = SKShapeNode(path: polygonPath(sides: sides, radius: 12))
        glowShape.fillColor = mainShape.fillColor.withAlphaComponent(0.4)
        glowShape.strokeColor = .clear
        glowShape.alpha = 0.5
        glowShape.zPosition = -2
        
        let randomY = CGFloat.random(in: 0...size.height)
        let randomX = CGFloat.random(in: -60 ... -30)
        mainShape.position = CGPoint(x: randomX, y: randomY)
        glowShape.position = CGPoint(x: randomX, y: randomY)
        
        addChild(glowShape)
        addChild(mainShape)
        
        let randomDuration = Double.random(in: 15.0...22.0)
        let moveAction = SKAction.moveBy(x: size.width + 80, y: 0, duration: randomDuration)
        let removeAction = SKAction.removeFromParent()
        glowShape.run(SKAction.sequence([moveAction, removeAction]))
        mainShape.run(SKAction.sequence([moveAction, removeAction]))
    }
    
    private func polygonPath(sides: Int, radius: CGFloat) -> CGPath {
        guard sides > 2 else {
            return CGPath(rect: CGRect(x: -radius, y: -radius,
                                       width: radius * 2, height: radius * 2),
                          transform: nil)
        }
        
        let path = CGMutablePath()
        let angle = (2.0 * CGFloat.pi) / CGFloat(sides)
        path.move(to: CGPoint(x: radius, y: 0.0))
        for i in 1..<sides {
            let x = radius * cos(angle * CGFloat(i))
            let y = radius * sin(angle * CGFloat(i))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.closeSubpath()
        return path
    }
}
