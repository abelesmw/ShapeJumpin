import SpriteKit

class HighScoresScene: SKScene {
    
    let rainbowColors: [SKColor] = [
        .red, .orange, .yellow, .green, .blue, .systemIndigo, .purple
    ]
    
    override func didMove(to view: SKView) {
        backgroundColor = .black

        let title = SKLabelNode(text: "My High Scores")
        title.fontSize = 36
        title.fontName = "Avenir-Black"
        title.fontColor = .cyan
        title.position = CGPoint(x: size.width/2, y: size.height*0.8)
        addChild(title)

        let scores = RunDataManager.shared.topScores // now top 5
        for (i, sc) in scores.enumerated() {
            let lbl = SKLabelNode(text: "\(i+1). \(sc)")
            lbl.fontSize = 28
            lbl.fontName = "Avenir-Black"
            lbl.position = CGPoint(
                x: size.width/2,
                y: size.height*0.7 - CGFloat(i*40)
            )
            addChild(lbl)
        }

        let tapLabel = SKLabelNode(text: "Tap to Return")
        tapLabel.fontSize = 20
        tapLabel.fontName = "Avenir-Black"
        tapLabel.position = CGPoint(x: size.width/2, y: size.height*0.1)
        addChild(tapLabel)
        
        let spawn = SKAction.run { [weak self] in
                self?.spawnRandomShape()
            }
            let wait = SKAction.wait(forDuration: 1.0) // Adjust the duration between spawns
            let sequence = SKAction.sequence([spawn, wait])
            let repeatForever = SKAction.repeatForever(sequence)
            run(repeatForever)
    }
    
    // MARK: - Spawn Random Shape
    private func spawnRandomShape() {
        
        // Choose a random shape type (triangle, square, hexagon, etc.)
        let possibleSides = [3, 4, 6]
        let sides = possibleSides.randomElement() ?? 3

        // Create the main shape
        let mainShape = SKShapeNode(path: polygonPath(sides: sides, radius: 8))
        mainShape.fillColor = rainbowColors.randomElement() ?? .white
        mainShape.strokeColor = .clear
        mainShape.alpha = 0.1
        mainShape.zPosition = -1

        // Create the glow effect as a larger, blurred shape
        let glowShape = SKShapeNode(path: polygonPath(sides: sides, radius: 12)) // Slightly larger radius
        glowShape.fillColor = mainShape.fillColor.withAlphaComponent(0.4) // Softer glow color
        glowShape.strokeColor = .clear
        glowShape.alpha = 0.5
        glowShape.zPosition = -2

        // Random starting position
        let randomY = CGFloat.random(in: 0...size.height)
        let randomX = CGFloat.random(in: (-60)...(-30)) // Vary the X so they don't all start at -30
        let spawnPosition = CGPoint(x: randomX, y: randomY)
        mainShape.position = spawnPosition
        glowShape.position = spawnPosition
        
        // Add to scene
        addChild(glowShape)
        addChild(mainShape)

        // Randomize the travel duration (move slower or faster)
        let randomDuration = Double.random(in: 15.0...22.0)
        let moveAction = SKAction.moveBy(x: size.width + 80, y: 0, duration: randomDuration)
        let removeAction = SKAction.removeFromParent()
        let sequence = SKAction.sequence([moveAction, removeAction])

        glowShape.run(sequence)
        mainShape.run(sequence)
    }
    
    // A helper function to create a CGPath for a polygon with given sides
    private func polygonPath(sides: Int, radius: CGFloat) -> CGPath {
        guard sides > 2 else {
            return CGPath(rect: CGRect(x: -radius, y: -radius,
                                       width: radius * 2, height: radius * 2),
                          transform: nil)
        }
        
        let path = CGMutablePath()
        let angle = (2.0 * CGFloat.pi) / CGFloat(sides)
        // Move to first point
        path.move(to: CGPoint(x: radius, y: 0.0))
        
        // Create the polygon
        for i in 1..<sides {
            let x = radius * cos(angle * CGFloat(i))
            let y = radius * sin(angle * CGFloat(i))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.closeSubpath()
        return path
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let menu = MainMenuScene(size: size)
        menu.scaleMode = .aspectFill
        view?.presentScene(menu, transition: .fade(withDuration: 0.5))
    }
}
