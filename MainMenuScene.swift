import SpriteKit
import FirebaseFirestore
import Firebase
import Foundation

// ── Global mute toggle  ─────────────────────────────
struct SoundSettings {
    private static let key = "isMuted"
    static var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
// ────────────────────────────────────────────────────

enum GameMode: Equatable {
    case solo
    case ghost
}

class MainMenuScene: SKScene {
    
    private let db = Firestore.firestore()
    private var isBelowMinimumVersion = false
    private var hasUserBeenWarned = false
    
    let rainbowColors: [SKColor] = [
        .red, .orange, .yellow, .green, .blue, .systemIndigo, .purple
    ]
    
    override func didMove(to view: SKView) {
        
        backgroundColor = .black
        
        let title = SKLabelNode(text: "Shape Jumpin")
        title.fontColor = .cyan
        title.fontSize = 50
        title.fontName = "Avenir-Black"
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.775)
        addChild(title)

        let soloButton = makePlayButton("Play", at: CGPoint(x: size.width / 2, y: size.height * 0.60))
        soloButton.name = "solo"
        soloButton.fontName = "Avenir-Black"
        addChild(soloButton)
        
        let hsButton = makeButton("My High Scores", at: CGPoint(x: size.width / 2, y: size.height * 0.45))
        hsButton.name = "highscores"
        hsButton.fontName = "Avenir-Black"
        addChild(hsButton)
        
        let publicLeaderboard = makeButton("Public Leaderboard", at: CGPoint(x: size.width / 2, y: size.height * 0.36))
        publicLeaderboard.name = "publicLeaderboard"
        publicLeaderboard.fontName = "Avenir-Black"
        addChild(publicLeaderboard)
        
        let userName = makeButton("Username", at: CGPoint(x: size.width / 2, y: size.height * 0.27))
        userName.name = "userName"
        userName.fontName = "Avenir-Black"
        addChild(userName)

        let howToPlay = makeButton("How To Play", at: CGPoint(x: size.width / 2, y: size.height * 0.18))
        howToPlay.name = "howToPlay"
        howToPlay.fontName = "Avenir-Black"
        addChild(howToPlay)
        
        let muteButton = makeButton(SoundSettings.isMuted ? "Sound Off" : "Sound On",
                                    at: CGPoint(x: 35, y: size.height - 50))
        muteButton.horizontalAlignmentMode = .left
        muteButton.name = "mute"
        muteButton.fontName = "Avenir-Black"
        muteButton.fontSize = 18
        muteButton.alpha = 0.75
        addChild(muteButton)
        
        // Spawn random shapes in background
        let spawnSequence = SKAction.sequence([
            SKAction.run { [weak self] in self?.spawnRandomShape() },
            SKAction.wait(forDuration: Double.random(in: 1.5...3.0))
        ])
        run(SKAction.repeatForever(spawnSequence))
        
        // Check Firestore's minimum version
        checkMinimumVersion()
    }

    // MARK: - Version Check
    
    private func checkMinimumVersion() {
        print("checkMinimumVersion called")
        db.collection("minimum_version").document("iOS").getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error getting minimum version: \(error)")
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                print("Document does not exist or snapshot is nil")
                return
            }
            
            guard let data = snapshot.data(),
                  let minVersion = data["version"] as? Int else {
                print("Failed to parse version data")
                return
            }
            
            //print("Fetched minimum version from Firestore: \(minVersion)")
            
            // Read local version (e.g. "1.2.3") from Info.plist
            let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
           // print("Local version string: \(versionString)")
            
            // Convert "1.2.3" -> "123", then into an Int
            let localVersion = Int(versionString.components(separatedBy: ".").joined()) ?? 0
           // print("Parsed local version as integer: \(localVersion)")
            
            // Compare
            if localVersion < minVersion {
                print("Local version is below minimum version")
                self.isBelowMinimumVersion = true
            } else {
                print("Local version meets or exceeds minimum version")
                self.isBelowMinimumVersion = false
            }
        }
    }
    
    class VersionManager {
        static let shared = VersionManager() // Singleton instance
        private init() {} // Prevent external instantiation
        var isBelowMinimumVersion = false
    }
    
    // MARK: - Button Creation

    func makeButton(_ text: String, at pos: CGPoint) -> SKLabelNode {
        let btn = SKLabelNode(text: text)
        btn.fontSize = 25
        btn.fontName = "Helvetica-Bold"
        btn.position = pos
        return btn
    }
    
    func makePlayButton(_ text: String, at pos: CGPoint) -> SKLabelNode {
        let btn = SKLabelNode(text: text)
        btn.fontSize = 34
        btn.fontName = "Helvetica-Bold"
        btn.position = pos
        return btn
    }

    // MARK: - Background Shapes

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
        let spawnPosition = CGPoint(x: randomX, y: randomY)
        mainShape.position = spawnPosition
        glowShape.position = spawnPosition
        
        addChild(glowShape)
        addChild(mainShape)

        let randomDuration = Double.random(in: 15.0...22.0)
        let moveAction = SKAction.moveBy(x: size.width + 80, y: 0, duration: randomDuration)
        let removeAction = SKAction.removeFromParent()
        let sequence = SKAction.sequence([moveAction, removeAction])
        glowShape.run(sequence)
        mainShape.run(sequence)
    }
    
    private func polygonPath(sides: Int, radius: CGFloat) -> CGPath {
        guard sides > 2 else {
            // fallback to a square if sides <= 2
            return CGPath(rect: CGRect(x: -radius, y: -radius, width: radius*2, height: radius*2), transform: nil)
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

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)
        
        for node in tappedNodes {
            if let name = node.name, let label = node as? SKLabelNode {
                
                // If user taps the update label, open the App Store link
                if name == "updateLink" {
                    openAppStore()
                    return
                }
                
                highlightButton(label)
                
                // Handle button after a slight delay to show highlight
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    
                    switch name {
                    case "mute":                                   // ⬅️ NEW
                            SoundSettings.isMuted.toggle()
                            label.text = SoundSettings.isMuted ? "Sound Off" : "Sound On"
                            return   
                    case "solo":
                        // If user is below min version:
                        //  - If not warned yet, show the update warning & block.
                        //  - If already warned, proceed anyway.
                        if self.isBelowMinimumVersion {
                            if !self.hasUserBeenWarned {
                                self.showUpdateWarning()
                                self.hasUserBeenWarned = true
                                return
                            } else {
                                // Already warned, proceed to game
                                //self.playIfUsernameExists()
                            }
                        } else {
                            // Normal path if version is OK
                            self.playIfUsernameExists()
                        }
                    case "howToPlay":
                        self.goToHowToPlay()
                    case "highscores":
                        self.goToHighScores()
                    case "userName":
                        self.goToUserName()
                    case "publicLeaderboard":
                        self.goToPublicLeaderboard()
                    default:
                        break
                    }
                }
            }
        }
    }

    private func playIfUsernameExists() {
        let savedUsername = UserDefaults.standard.string(forKey: "username") ?? ""
        if savedUsername.isEmpty {
            self.showWarning("<- Please create a username to play")
            if let userNameNode = self.childNode(withName: "userName") as? SKLabelNode {
                userNameNode.fontColor = .cyan
            }
        } else {
            self.startGame(mode: .solo)
        }
    }
    
    private func openAppStore() {
        if let url = URL(string: "https://apps.apple.com/us/app/shape-jumpin/id6740543756") {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
    
    func highlightButton(_ button: SKLabelNode) {
        let originalColor = button.fontColor
        button.fontColor = .cyan
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            button.fontColor = originalColor
        }
    }
    
    private func showWarning(_ message: String) {
        let warningLabel = SKLabelNode(text: message)
        warningLabel.fontName = "Avenir-Black"
        warningLabel.fontSize = 19
        warningLabel.fontColor = .yellow
        warningLabel.position = CGPoint(x: size.width / 1.29, y: size.height * 0.27)
        warningLabel.zPosition = 999
        addChild(warningLabel)
        
        let sequence = SKAction.sequence([
            SKAction.wait(forDuration: 10.0),
            SKAction.fadeOut(withDuration: 3),
            SKAction.removeFromParent()
        ])
        warningLabel.run(sequence)
    }

    // MARK: - Show Update Warning
    
    private func showUpdateWarning() {
        // A short message prompting update; dissolve in 5s
        let message = "Please update to the latest version. Tap here to update"
        
        // Create a mutable attributed string for styling
        let attributedString = NSMutableAttributedString(
            string: message,
            attributes: [
                .font: UIFont(name: "Avenir-Black", size: 24.0)!,
                .foregroundColor: UIColor.red
            ]
        )
        
        // Highlight "Tap here to update" in bold blue
        if let tapRange = message.range(of: "Tap here to update") {
            let nsRange = NSRange(tapRange, in: message)
            attributedString.addAttributes(
                [
                    .font: UIFont(name: "Avenir-Black", size: 24.0)!,
                    .foregroundColor: UIColor.systemBlue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ],
                range: nsRange
            )
        }
        
        // Create an SKLabelNode for the attributed text
        let updateLabel = SKLabelNode()
        updateLabel.name = "updateLink"
        updateLabel.attributedText = attributedString
        updateLabel.horizontalAlignmentMode = .center
        updateLabel.verticalAlignmentMode = .center
        updateLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.71) // Lower position
        updateLabel.zPosition = 999
        addChild(updateLabel)
        
        // Animate the label to dissolve after 5 seconds
        let sequence = SKAction.sequence([
            SKAction.wait(forDuration: 10.0),
            SKAction.fadeOut(withDuration: 1.0),
            SKAction.removeFromParent()
        ])
        updateLabel.run(sequence)
    }

    // MARK: - Navigation

    func startGame(mode: GameMode) {
        let scene = GameScene(size: size)
        scene.scaleMode = .aspectFill
        scene.gameMode = mode
        view?.presentScene(scene, transition: .fade(withDuration: 0.5))
    }

    func goToHighScores() {
        let hsScene = HighScoresScene(size: size)
        hsScene.scaleMode = .aspectFill
        view?.presentScene(hsScene, transition: .fade(withDuration: 0.5))
    }
    
    func goToPublicLeaderboard() {
        let plScene = PublicLeaderboardScene(size: size)
        plScene.scaleMode = .aspectFill
        view?.presentScene(plScene, transition: .fade(withDuration: 0.5))
    }
    
    func goToUserName() {
        let userNameScene = UserNameScene(size: size)
        userNameScene.scaleMode = .aspectFill
        view?.presentScene(userNameScene, transition: .fade(withDuration: 0.5))
    }
    
    func goToHowToPlay() {
        let htpScene = HowToPlayScene(size: size)
        htpScene.scaleMode = .aspectFill
        view?.presentScene(htpScene, transition: .fade(withDuration: 0.5))
    }
}
