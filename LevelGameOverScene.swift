import SpriteKit

/// A stripped‑down Game‑Over screen just for Level 1 runs.
class LevelGameOverScene: SKScene {

    // Public so Level1Scene can inject the score before presenting.
    var finalScore: Int = 0
    var distanceTravelled: CGFloat = 0
    private let levelLength: CGFloat = 5700

    // MARK: – didMove
    override func didMove(to view: SKView) {
        backgroundColor = .black

        // --- Score label ---
        let scoreLabel = SKLabelNode(text: "Score: \(finalScore)")
        scoreLabel.fontName = "Avenir-Black"
        scoreLabel.fontSize = 48
        scoreLabel.fontColor = SKColor(red: 0.5, green: 1.0, blue: 0.7, alpha: 1.0)
        scoreLabel.position = CGPoint(x: size.width/2 + 200, y: size.height * 0.7)
        addChild(scoreLabel)

        // --- Buttons ---
        let playAgain = makeButton(text: "Play Again")
        playAgain.name = "playAgain"
        playAgain.position = CGPoint(x: size.width/2 + 200, y: size.height * 0.45)
        addChild(playAgain)

        let menu = makeButton(text: "Main Menu")
        menu.name = "mainMenu"
        menu.position = CGPoint(x: size.width/2 + 200, y: size.height * 0.27)
        addChild(menu)
        
        let bar = SKSpriteNode(imageNamed: "start_finish")
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        bar.position     = CGPoint(x: size.width*0.05, y: size.height*0.5)
        let barScale = (size.width * 0.5) / bar.size.width
        bar.setScale(barScale)
        addChild(bar)
        
        // --- line geometry (cap‑to‑cap) ---
        let capInset = bar.size.height * 0.5          // radius of the end caps
        let lineStartX = bar.position.x + capInset
        let lineEndX   = bar.position.x + bar.size.width - capInset
        let progressW  = lineEndX - lineStartX
        
        // --- marker (felt ball) ---
        let marker = SKSpriteNode(imageNamed: "felt_ball2")
        marker.setScale(0.03)
        marker.position = CGPoint(x: lineStartX, y: bar.position.y)
        addChild(marker)
        
        // --- compute where we got to ---
        let pct   = max(0, min(1, distanceTravelled / levelLength))
        let tgtX = lineStartX + progressW * pct

        let move  = SKAction.moveTo(x: tgtX, duration: 2)
        move.timingMode = .easeOut
        let spins: CGFloat = 6            // ~6 full turns feels right
        let spin  = SKAction.rotate(byAngle: -.pi * 0.8 * spins, duration: 2)
        spin.timingMode = .easeOut
        marker.run(.group([move, spin]))
    }

    // MARK: – Touch handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let nodesAtPoint = nodes(at: touch.location(in: self))

        for n in nodesAtPoint {
            guard let button = n as? SKShapeNode else { continue }
            highlight(button)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                self?.unhighlight(button)
                switch button.name {
                case "playAgain": self?.goToLevel1()
                case "mainMenu":  self?.goToMainMenu()
                default: break
                }
            }
        }
    }

    // MARK: – Navigation helpers
    private func goToLevel1() {
        if let level1 = Level1Scene(fileNamed: "Level1Scene") {
            level1.scaleMode = .aspectFill
            view?.presentScene(level1, transition: .fade(withDuration: 0.5))
        } else {
            print("Error: Could not load Level1Scene.sks")
        }
    }

    private func goToMainMenu() {
        let menu = MainMenuScene(size: size)
        menu.scaleMode = .aspectFill
        view?.presentScene(menu, transition: .fade(withDuration: 0.5))
    }

    // MARK: – Button factory / effects
    private func makeButton(text: String) -> SKShapeNode {
        let width: CGFloat = size.width * 0.3
        let btn = SKShapeNode(rectOf: CGSize(width: width, height: 60), cornerRadius: 10)
        btn.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        btn.strokeColor = .clear

        let label = SKLabelNode(text: text)
        label.fontName = "Avenir-Black"
        label.fontSize = 30
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        btn.addChild(label)
        return btn
    }

    private func highlight(_ btn: SKShapeNode)  { btn.fillColor = .darkGray }
    private func unhighlight(_ btn: SKShapeNode){ btn.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1) }
}
