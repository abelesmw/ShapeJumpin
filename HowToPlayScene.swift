import SpriteKit

class HowToPlayScene: SKScene {

    override func didMove(to view: SKView) {
        // Set the background color
        self.backgroundColor = .black

        // Add the title label
        let titleLabel = SKLabelNode(fontNamed: "Avenir-Black")
        titleLabel.text = "How to Play"
        titleLabel.fontSize = 40
        titleLabel.fontColor = .cyan
        titleLabel.position = CGPoint(x: self.frame.midX, y: self.frame.midY + 120)
        self.addChild(titleLabel)

        // Add the back button
        let backButton = SKLabelNode(fontNamed: "Avenir-Black")
        backButton.text = "Back"
        backButton.fontSize = 32
        backButton.fontColor = .white
        backButton.position = CGPoint(x: 80, y: self.size.height - 70)
        backButton.name = "backButton"
        self.addChild(backButton)

        // Add the instructions text
        let instructions = [
            ("Jump:", "Tap to leap over obstacles."),
            ("Double Jump:", "Tap mid-air for a second jump and hold to jump higher."),
            ("Duck:", "Press with two fingers to slide under obstacles."),
            ("Scoring:", "Earn points for survival and how much you clear obstacles by.")
        ]

        for (index, line) in instructions.enumerated() {
            // Add the keyword in cyan and larger font
            let keywordLabel = SKLabelNode(fontNamed: "Avenir-Black")
            keywordLabel.text = line.0
            keywordLabel.fontSize = 22
            keywordLabel.fontColor = .cyan
            keywordLabel.horizontalAlignmentMode = .left
            keywordLabel.position = CGPoint(x: 50, y: self.size.height - 150 - CGFloat(index * 40))
            self.addChild(keywordLabel)

            // Add the description in white and normal font
            let descriptionLabel = SKLabelNode(fontNamed: "Avenir-Black")
            descriptionLabel.text = line.1
            descriptionLabel.fontSize = 20
            descriptionLabel.fontColor = .white
            descriptionLabel.horizontalAlignmentMode = .left
            descriptionLabel.position = CGPoint(x: 50 + keywordLabel.frame.width + 10, y: self.size.height - 150 - CGFloat(index * 40))
            self.addChild(descriptionLabel)
        }
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
}
