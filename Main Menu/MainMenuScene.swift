import SpriteKit
import FirebaseFirestore
import Firebase
import Foundation
import AVFoundation

struct SoundSettings {
    private static let key = "isMuted"
    static var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

enum GameMode: Equatable {
    case solo
    case ghost
}

class MainMenuScene: SKScene {

    private let db = Firestore.firestore()
    private var isBelowMinimumVersion = false
    private var hasUserBeenWarned = false

    private var preloadedLevel1: Level1Scene?
    private var preloadedAudioPlayer: AVAudioPlayer?

    let rainbowColors: [SKColor] = [
        .red, .orange, .yellow, .green, .blue, .systemIndigo, .purple
    ]

    private var classicButton: SKLabelNode!
    private var classicBackgroundNode: SKShapeNode!
    private var levelsButton: SKLabelNode!
    private var levelsBackgroundNode: SKShapeNode!
    private var highScoresButton: SKLabelNode!
    private var highScoresBackgroundNode: SKShapeNode!
    private var leaderboardButton: SKLabelNode!
    private var leaderboardBackgroundNode: SKShapeNode!
    private var usernameButton: SKLabelNode!
    private var usernameBackgroundNode: SKShapeNode!
    private var howToPlayButton: SKLabelNode!
    private var howToPlayBackgroundNode: SKShapeNode!

    override func didMove(to view: SKView) {
        
        let midDarkGrayBlack = UIColor(red: 0.1667, green: 0.1667, blue: 0.1667, alpha: 1.0)
        backgroundColor = midDarkGrayBlack
        
        do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Audio session setup error: \(error.localizedDescription)")
            }

        let leftColumnX = (size.width * 0.25) + 10 + 15 + 5
        let rightColumnX = (size.width * 0.75) - 50 + 15 + 5
        
        let SHAPE_title = SKSpriteNode(imageNamed: "SHAPE_title.png")
        SHAPE_title.position = CGPoint(x: (size.width / 2) - 105, y: (size.height / 2) + 132)
        SHAPE_title.zPosition = 0
        SHAPE_title.xScale = 0.18
        SHAPE_title.yScale = 0.16
        SHAPE_title.alpha = 0.75
        addChild(SHAPE_title)
        
        let JUMPIN_title = SKSpriteNode(imageNamed: "JUMPIN_title.png")
        JUMPIN_title.position = CGPoint(x: (size.width / 2) + 105, y: (size.height / 2) + 133)
        JUMPIN_title.zPosition = 0
        JUMPIN_title.xScale = 0.2
        JUMPIN_title.yScale = 0.18
        JUMPIN_title.alpha = 0.75
        addChild(JUMPIN_title)
        
        let red_square_cartoon = SKSpriteNode(imageNamed: "red_square_cartoon_.png")
        red_square_cartoon.position = CGPoint(x: leftColumnX, y: (size.height / 2) - 41)
        red_square_cartoon.zPosition = -1
        red_square_cartoon.xScale = 0.35
        red_square_cartoon.yScale = 0.35
        red_square_cartoon.alpha = 0.25
        addChild(red_square_cartoon)
        
        let green_square_cartoon = SKSpriteNode(imageNamed: "green_square_cartoon.png")
        green_square_cartoon.position = CGPoint(x: rightColumnX, y: (size.height / 2) - 41)
        green_square_cartoon.zPosition = -1
        green_square_cartoon.xScale = 0.35
        green_square_cartoon.yScale = 0.35
        green_square_cartoon.alpha = 0.25
        addChild(green_square_cartoon)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let scene = Level1Scene(fileNamed: "Level1Scene") else { return }
            scene.scaleMode = .aspectFill
            self.preloadedLevel1 = scene
            
            let atlas = SKTextureAtlas(named: "Images")
            atlas.preload { }

            /*if let url = Bundle.main.url(forResource: "orchid_sky", withExtension: "m4a") {
                do {
                    let audioPlayer = try AVAudioPlayer(contentsOf: url)
                    self.preloadedAudioPlayer = audioPlayer
                } catch { }
            }*/
        }

        let menuVerticalOffset: CGFloat = -20
        let headerFontSize: CGFloat = 34
        let interElementSpacing: CGFloat = 10

        let playHeaderY = (size.height * 0.6) + menuVerticalOffset + 5

        let playHeader = SKLabelNode(text: "Play")
        playHeader.fontName = "Avenir-Black"
        playHeader.fontSize = headerFontSize
        playHeader.fontColor = SKColor(white: 0.825, alpha: 1.0)
        playHeader.position = CGPoint(x: leftColumnX, y: playHeaderY)
        playHeader.horizontalAlignmentMode = .center
        addChild(playHeader)

        let classicLevelsTextFontSize: CGFloat = 28
        let classicLevelsButtonVerticalPadding: CGFloat = 8
        let classicLevelsButtonHeight: CGFloat = classicLevelsTextFontSize + (2 * classicLevelsButtonVerticalPadding)
        let classicLevelsButtonWidth: CGFloat = 130
        let buttonCornerRadius: CGFloat = 8
        let buttonTextColor: SKColor = .black

        let classicButtonYOffset = playHeaderY - (headerFontSize / 2) - (classicLevelsButtonHeight / 2) - interElementSpacing
        classicBackgroundNode = SKShapeNode(rectOf: CGSize(width: classicLevelsButtonWidth, height: classicLevelsButtonHeight), cornerRadius: buttonCornerRadius)
        classicBackgroundNode.fillColor = .lightGray
        classicBackgroundNode.strokeColor = .clear
        classicBackgroundNode.position = CGPoint(x: leftColumnX, y: classicButtonYOffset)
        classicBackgroundNode.name = "solo"
        addChild(classicBackgroundNode)

        classicButton = SKLabelNode(text: "Classic")
        classicButton.fontName = "Avenir-Black"
        classicButton.fontSize = classicLevelsTextFontSize
        classicButton.fontColor = buttonTextColor
        classicButton.name = "solo"
        classicButton.position = CGPoint(x: classicBackgroundNode.position.x, y: classicBackgroundNode.position.y)
        classicButton.horizontalAlignmentMode = .center
        classicButton.verticalAlignmentMode = .center
        addChild(classicButton)

        let levelsButtonYOffset = classicButtonYOffset - classicLevelsButtonHeight - interElementSpacing
        levelsBackgroundNode = SKShapeNode(rectOf: CGSize(width: classicLevelsButtonWidth, height: classicLevelsButtonHeight), cornerRadius: buttonCornerRadius)
        levelsBackgroundNode.fillColor = .lightGray
        levelsBackgroundNode.strokeColor = .clear
        levelsBackgroundNode.position = CGPoint(x: leftColumnX, y: levelsButtonYOffset)
        levelsBackgroundNode.name = "levelMode"
        addChild(levelsBackgroundNode)

        levelsButton = SKLabelNode(text: "Levels")
        levelsButton.fontName = "Avenir-Black"
        levelsButton.fontSize = classicLevelsTextFontSize
        levelsButton.fontColor = buttonTextColor
        levelsButton.name = "levelMode"
        levelsButton.position = CGPoint(x: levelsBackgroundNode.position.x, y: levelsBackgroundNode.position.y)
        levelsButton.horizontalAlignmentMode = .center
        levelsButton.verticalAlignmentMode = .center
        addChild(levelsButton)

        let menuHeaderY = playHeaderY

        let menuHeader = SKLabelNode(text: "Menu")
        menuHeader.fontName = "Avenir-Black"
        menuHeader.fontSize = headerFontSize
        menuHeader.fontColor = SKColor(white: 0.825, alpha: 1.0)
        menuHeader.position = CGPoint(x: rightColumnX, y: menuHeaderY)
        menuHeader.horizontalAlignmentMode = .center
        addChild(menuHeader)

        let menuItemsTextFontSize: CGFloat = 18
        let menuItemsButtonVerticalPadding: CGFloat = 5
        let menuItemsButtonHeight: CGFloat = menuItemsTextFontSize + (2 * menuItemsButtonVerticalPadding)
        let menuItemsButtonWidth: CGFloat = 155

        let rightColumnButtonYStart = menuHeaderY - (headerFontSize / 2) - (menuItemsButtonHeight / 2) - interElementSpacing + 7
        let rightColumnVerticalSpacing = menuItemsButtonHeight + interElementSpacing - 1

        highScoresBackgroundNode = SKShapeNode(rectOf: CGSize(width: menuItemsButtonWidth, height: menuItemsButtonHeight), cornerRadius: buttonCornerRadius)
        highScoresBackgroundNode.fillColor = .lightGray
        highScoresBackgroundNode.strokeColor = .clear
        highScoresBackgroundNode.position = CGPoint(x: rightColumnX, y: rightColumnButtonYStart)
        highScoresBackgroundNode.name = "highscores"
        addChild(highScoresBackgroundNode)

        highScoresButton = SKLabelNode(text: "My High Scores")
        highScoresButton.fontName = "Avenir-Black"
        highScoresButton.fontSize = menuItemsTextFontSize
        highScoresButton.fontColor = buttonTextColor
        highScoresButton.name = "highscores"
        highScoresButton.position = CGPoint(x: highScoresBackgroundNode.position.x, y: highScoresBackgroundNode.position.y)
        highScoresButton.horizontalAlignmentMode = .center
        highScoresButton.verticalAlignmentMode = .center
        addChild(highScoresButton)

        leaderboardBackgroundNode = SKShapeNode(rectOf: CGSize(width: menuItemsButtonWidth, height: menuItemsButtonHeight), cornerRadius: buttonCornerRadius)
        leaderboardBackgroundNode.fillColor = .lightGray
        leaderboardBackgroundNode.strokeColor = .clear
        leaderboardBackgroundNode.position = CGPoint(x: rightColumnX, y: rightColumnButtonYStart - rightColumnVerticalSpacing)
        leaderboardBackgroundNode.name = "leaderboard"
        addChild(leaderboardBackgroundNode)

        leaderboardButton = SKLabelNode(text: "Leaderboard")
        leaderboardButton.fontName = "Avenir-Black"
        leaderboardButton.fontSize = menuItemsTextFontSize
        leaderboardButton.fontColor = buttonTextColor
        leaderboardButton.name = "leaderboard"
        leaderboardButton.position = CGPoint(x: leaderboardBackgroundNode.position.x, y: leaderboardBackgroundNode.position.y)
        leaderboardButton.horizontalAlignmentMode = .center
        leaderboardButton.verticalAlignmentMode = .center
        addChild(leaderboardButton)

        usernameBackgroundNode = SKShapeNode(rectOf: CGSize(width: menuItemsButtonWidth, height: menuItemsButtonHeight), cornerRadius: buttonCornerRadius)
        usernameBackgroundNode.fillColor = .lightGray
        usernameBackgroundNode.strokeColor = .clear
        usernameBackgroundNode.position = CGPoint(x: rightColumnX, y: rightColumnButtonYStart - (rightColumnVerticalSpacing * 2))
        usernameBackgroundNode.name = "userName"
        addChild(usernameBackgroundNode)

        usernameButton = SKLabelNode(text: "Username")
        usernameButton.fontName = "Avenir-Black"
        usernameButton.fontSize = menuItemsTextFontSize
        usernameButton.fontColor = buttonTextColor
        usernameButton.name = "userName"
        usernameButton.position = CGPoint(x: usernameBackgroundNode.position.x, y: usernameBackgroundNode.position.y)
        usernameButton.horizontalAlignmentMode = .center
        usernameButton.verticalAlignmentMode = .center
        addChild(usernameButton)

        howToPlayBackgroundNode = SKShapeNode(rectOf: CGSize(width: menuItemsButtonWidth, height: menuItemsButtonHeight), cornerRadius: buttonCornerRadius)
        howToPlayBackgroundNode.fillColor = .lightGray
        howToPlayBackgroundNode.strokeColor = .clear
        howToPlayBackgroundNode.position = CGPoint(x: rightColumnX, y: rightColumnButtonYStart - (rightColumnVerticalSpacing * 3))
        howToPlayBackgroundNode.name = "howToPlay"
        addChild(howToPlayBackgroundNode)

        howToPlayButton = SKLabelNode(text: "How To Play")
        howToPlayButton.fontName = "Avenir-Black"
        howToPlayButton.fontSize = menuItemsTextFontSize
        howToPlayButton.fontColor = buttonTextColor
        howToPlayButton.name = "howToPlay"
        howToPlayButton.position = CGPoint(x: howToPlayBackgroundNode.position.x, y: howToPlayBackgroundNode.position.y)
        howToPlayButton.horizontalAlignmentMode = .center
        howToPlayButton.verticalAlignmentMode = .center
        addChild(howToPlayButton)

        let muteButtonVisual = SKLabelNode(text: SoundSettings.isMuted ? "Sound Off" : "Sound On")
        muteButtonVisual.fontName = "Avenir-Black"; muteButtonVisual.fontSize = 18
        muteButtonVisual.alpha = 0.75; muteButtonVisual.horizontalAlignmentMode = .left
        muteButtonVisual.position = CGPoint(x: 35, y: size.height - 50)
        muteButtonVisual.name = "muteButtonVisual"; addChild(muteButtonVisual)

        let muteButtonTapArea = SKSpriteNode(); muteButtonTapArea.name = "mute"
        let tapPadding: CGFloat = 30.0
        let tempLabelForSizing = SKLabelNode(text: "Sound Off"); tempLabelForSizing.fontName = "Avenir-Black"; tempLabelForSizing.fontSize = 18
        let visualLabelSize = tempLabelForSizing.calculateAccumulatedFrame().size
        muteButtonTapArea.size = CGSize(width: visualLabelSize.width + tapPadding * 2, height: visualLabelSize.height + tapPadding * 2)
        muteButtonTapArea.position = CGPoint(x: muteButtonVisual.position.x + visualLabelSize.width / 2, y: muteButtonVisual.position.y)
        muteButtonTapArea.alpha = 0.001; addChild(muteButtonTapArea)

        let spawnSequence = SKAction.sequence([SKAction.run { [weak self] in self?.spawnRandomShape() }, SKAction.wait(forDuration: Double.random(in: 1.5...3.0))])
        run(SKAction.repeatForever(spawnSequence))
        checkMinimumVersion()
    }

    private func checkMinimumVersion() {
        db.collection("minimum_version").document("iOS").getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("Error fetching minimum version: \(error.localizedDescription)")
                self.isBelowMinimumVersion = false
                return
            }
            guard let snapshot = snapshot, snapshot.exists else {
                print("Minimum version document does not exist.")
                self.isBelowMinimumVersion = false
                return
            }
            guard let data = snapshot.data() else {
                print("Minimum version document data is nil.")
                self.isBelowMinimumVersion = false
                return
            }

            let appVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

            if let minVersionString = data["version"] as? String {
                let minVersionComponents = minVersionString.split(separator: ".").compactMap { Int($0) }
                let appVersionComponents = appVersionString.split(separator: ".").compactMap { Int($0) }

                self.isBelowMinimumVersion = false
                let componentCount = max(minVersionComponents.count, appVersionComponents.count)

                if componentCount == 0 && !minVersionString.isEmpty {
                        print("Invalid version string format from Firestore: \(minVersionString)")
                        self.isBelowMinimumVersion = false
                } else {
                    for i in 0..<componentCount {
                        let minComp = i < minVersionComponents.count ? minVersionComponents[i] : 0
                        let appComp = i < appVersionComponents.count ? appVersionComponents[i] : 0

                        if appComp < minComp {
                            self.isBelowMinimumVersion = true
                            break
                        }
                        if appComp > minComp {
                            self.isBelowMinimumVersion = false
                            break
                        }
                        if i == componentCount - 1 {
                            self.isBelowMinimumVersion = false
                        }
                    }
                }
                print("Fetched min version (String): \"\(minVersionString)\", App version: \"\(appVersionString)\", IsBelow: \(self.isBelowMinimumVersion)")
            }
            else if let minVersionInt = data["version"] as? Int {
                let localVersionIntString = appVersionString.components(separatedBy: ".").joined()
                let localVersionInt = Int(localVersionIntString) ?? 0
                
                self.isBelowMinimumVersion = localVersionInt < minVersionInt
                print("Fetched min version (Int): \(minVersionInt), App version (Int from \(appVersionString)): \(localVersionInt), IsBelow: \(self.isBelowMinimumVersion)")
            }
            else {
                print("Minimum version 'version' field is missing or not a String/Int in data: \(data)")
                self.isBelowMinimumVersion = false
            }
        }
    }
    
    class VersionManager {
        static let shared = VersionManager()
        private init() {}
        var isBelowMinimumVersion = false
    }

    private func spawnRandomShape() {
        let possibleSides = [3, 4, 6]; let sides = possibleSides.randomElement() ?? 3
        let mainShape = SKShapeNode(path: polygonPath(sides: sides, radius: 8))
        mainShape.fillColor = rainbowColors.randomElement() ?? .white; mainShape.strokeColor = .clear
        mainShape.alpha = 0.1; mainShape.zPosition = -1
        let glowShape = SKShapeNode(path: polygonPath(sides: sides, radius: 12))
        glowShape.fillColor = mainShape.fillColor.withAlphaComponent(0.4); glowShape.strokeColor = .clear
        glowShape.alpha = 0.5; glowShape.zPosition = -2
        let randomY = CGFloat.random(in: 0...size.height); let randomX = CGFloat.random(in: -60 ... -30)
        let spawnPosition = CGPoint(x: randomX, y: randomY)
        mainShape.position = spawnPosition; glowShape.position = spawnPosition
        addChild(glowShape); addChild(mainShape)
        let randomDuration = Double.random(in: 15.0...22.0)
        let moveAction = SKAction.moveBy(x: size.width + 80, y: 0, duration: randomDuration)
        let removeAction = SKAction.removeFromParent()
        let sequence = SKAction.sequence([moveAction, removeAction])
        glowShape.run(sequence); mainShape.run(sequence)
    }
    
    private func polygonPath(sides: Int, radius: CGFloat) -> CGPath {
        guard sides > 2 else { return CGPath(rect: CGRect(x: -radius, y: -radius, width: radius*2, height: radius*2), transform: nil) }
        let path = CGMutablePath(); let angle = (2.0 * CGFloat.pi) / CGFloat(sides)
        path.move(to: CGPoint(x: radius, y: 0.0))
        for i in 1..<sides { path.addLine(to: CGPoint(x: radius * cos(angle * CGFloat(i)), y: radius * sin(angle * CGFloat(i)))) }
        path.closeSubpath(); return path
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        var tappedNode: SKNode?

        for node in nodes(at: location) {
            if node.name == "updateLink" {
                tappedNode = node
                break
            }
            if node.name == "mute" {
                tappedNode = node
                break
            }
        }
        
        if tappedNode == nil {
            for node in nodes(at: location) {
                if node is SKLabelNode && node.name != nil {
                        if node.name == "muteButtonVisual" {
                            if let muteArea = self.childNode(withName: "mute") { tappedNode = muteArea; break }
                        } else {
                            tappedNode = node; break
                        }
                    } else if node is SKShapeNode && node.name != nil {
                        if tappedNode == nil { tappedNode = node }
                    }
            }
        }

        guard let finalTappedNode = tappedNode, let name = finalTappedNode.name else { return }

        if name == "updateLink" {
            openAppStore()
            self.childNode(withName: "styledUpdateWarningNode")?.removeFromParent()
            return
        }
        
        if name == "mute" {
            if let visualLabel = self.childNode(withName: "muteButtonVisual") as? SKLabelNode {
                highlightButton(visualLabel, originalColor: .white, highlightColor: .cyan)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    SoundSettings.isMuted.toggle()
                    visualLabel.text = SoundSettings.isMuted ? "Sound Off" : "Sound On"
                }
            }
            return
        }
        
        var targetLabelNode: SKLabelNode?
        var targetBackgroundNode: SKShapeNode?
        var actionToPerform: (() -> Void)?

        switch name {
        case "solo":
            targetLabelNode = classicButton
            targetBackgroundNode = classicBackgroundNode
            actionToPerform = {
                if self.isBelowMinimumVersion {
                    self.displayStyledUpdateWarning(over: self.classicBackgroundNode)
                } else {
                    self.handleUsernameCheckAndProceed(
                        actionIfUsernameExists: { self.startGame(mode: .solo) },
                        buttonNodeForWarningMessage: self.classicBackgroundNode
                    )
                }
            }
        case "levelMode":
            targetLabelNode = levelsButton
            targetBackgroundNode = levelsBackgroundNode
            actionToPerform = {
                if self.isBelowMinimumVersion {
                    self.displayStyledUpdateWarning(over: self.levelsBackgroundNode)
                } else {
                    self.handleUsernameCheckAndProceed(
                        actionIfUsernameExists: { self.goToLevelsMenu() },
                        buttonNodeForWarningMessage: self.levelsBackgroundNode
                    )
                }
            }
        case "highscores":
            targetLabelNode = highScoresButton
            targetBackgroundNode = highScoresBackgroundNode
            actionToPerform = { self.goToHighScores() }
        case "leaderboard":
            targetLabelNode = leaderboardButton
            targetBackgroundNode = leaderboardBackgroundNode
            actionToPerform = { self.goToPublicLeaderboard() }
        case "userName":
            targetLabelNode = usernameButton
            targetBackgroundNode = usernameBackgroundNode
            actionToPerform = { self.goToUserName() }
        case "howToPlay":
            targetLabelNode = howToPlayButton
            targetBackgroundNode = howToPlayBackgroundNode
            actionToPerform = { self.goToHowToPlay() }
        default:
            actionToPerform = nil
        }

        if let label = targetLabelNode, let background = targetBackgroundNode, let action = actionToPerform {
            animateButtonPress(labelNode: label, backgroundNode: background, action: action)
        }
    }

    func animateButtonPress(labelNode: SKLabelNode, backgroundNode: SKShapeNode, action: @escaping () -> Void) {
        let pressDuration: TimeInterval = 0.1
        let originalBackgroundColor = backgroundNode.fillColor
        let originalLabelColor = labelNode.fontColor ?? SKColor.black
        let pressedBackgroundColor = SKColor.darkGray
        let pressedLabelColor = SKColor.lightGray

        let applyPressedState = SKAction.run {
            backgroundNode.fillColor = pressedBackgroundColor
            labelNode.fontColor = pressedLabelColor
        }
        let applyOriginalState = SKAction.run {
            backgroundNode.fillColor = originalBackgroundColor
            labelNode.fontColor = originalLabelColor
        }
        let wait = SKAction.wait(forDuration: pressDuration)
        let performAction = SKAction.run(action)
        let sequence = SKAction.sequence([applyPressedState, wait, applyOriginalState, performAction])
        backgroundNode.run(sequence)
    }

    func highlightButton(_ button: SKLabelNode, originalColor: SKColor, highlightColor: SKColor) {
        button.fontColor = highlightColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { button.fontColor = originalColor }
    }
    
    private func handleUsernameCheckAndProceed(
        actionIfUsernameExists: @escaping () -> Void,
        buttonNodeForWarningMessage: SKShapeNode
    ) {
        let savedUsername = UserDefaults.standard.string(forKey: "username") ?? ""
        if savedUsername.isEmpty {
            let highlightDuration: TimeInterval = 7
            let highlightColor = SKColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 1.0)
            let warningMessageText = "Please create a username"

            if let userBgNode = self.usernameBackgroundNode {
                let originalColor = userBgNode.fillColor
                userBgNode.fillColor = highlightColor
                DispatchQueue.main.asyncAfter(deadline: .now() + highlightDuration) {
                    userBgNode.fillColor = originalColor
                }
            }

            let warningLabel = SKLabelNode(text: warningMessageText)
            warningLabel.fontName = "Avenir-Black"
            warningLabel.fontSize = 22
            warningLabel.fontColor = .black
            warningLabel.horizontalAlignmentMode = .center
            warningLabel.verticalAlignmentMode = .center
            warningLabel.zPosition = 1

            let labelSize = warningLabel.calculateAccumulatedFrame().size
            let padding: CGFloat = 12
            let backgroundSize = CGSize(width: labelSize.width + padding * 2, height: labelSize.height + padding * 2)

            let textBackground = SKShapeNode(rectOf: backgroundSize, cornerRadius: 5)
            textBackground.fillColor = highlightColor
            textBackground.strokeColor = .clear
            textBackground.position = buttonNodeForWarningMessage.position
            textBackground.zPosition = 1000

            textBackground.addChild(warningLabel)
            self.addChild(textBackground)

            let fadeOutAction = SKAction.fadeOut(withDuration: 0.3)
            let removeAction = SKAction.removeFromParent()
            let sequenceAction = SKAction.sequence([SKAction.wait(forDuration: highlightDuration - 0.3), fadeOutAction, removeAction])
            textBackground.run(sequenceAction)
        } else {
            actionIfUsernameExists()
        }
    }

    private func displayStyledUpdateWarning(over tappedButtonBackground: SKShapeNode) {
        self.childNode(withName: "styledUpdateWarningNode")?.removeFromParent()

        let message = "Please update to the latest version. Tap here to update"
        let mainAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Avenir-Black", size: 18)!,
            .foregroundColor: UIColor.black
        ]
        let linkAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Avenir-Black", size: 18)!,
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let attributedString = NSMutableAttributedString(string: message, attributes: mainAttributes)
        if let tapRange = message.range(of: "Tap here to update") {
            let nsRange = NSRange(tapRange, in: message)
            attributedString.addAttributes(linkAttributes, range: nsRange)
        }

        let updateLabel = SKLabelNode()
        updateLabel.attributedText = attributedString
        updateLabel.name = "updateLink"
        updateLabel.horizontalAlignmentMode = .center
        updateLabel.verticalAlignmentMode = .center
        updateLabel.zPosition = 1

        let labelSize = updateLabel.calculateAccumulatedFrame().size
        let padding: CGFloat = 12
        let minWidth = tappedButtonBackground.frame.width * 0.9
        let backgroundWidth = max(labelSize.width + padding * 2, minWidth)
        let backgroundHeight = labelSize.height + padding * 2
        let backgroundSize = CGSize(width: backgroundWidth, height: backgroundHeight)

        let textBackground = SKShapeNode(rectOf: backgroundSize, cornerRadius: 5)
        textBackground.fillColor = .white
        textBackground.strokeColor = SKColor.lightGray
        textBackground.position = CGPoint(x: tappedButtonBackground.position.x + 75, y: tappedButtonBackground.position.y)
        textBackground.zPosition = 1100
        textBackground.name = "styledUpdateWarningNode"

        textBackground.addChild(updateLabel)
        self.addChild(textBackground)

        let displayDuration: TimeInterval = 10.0
        let fadeOutDuration: TimeInterval = 1.0
        let sequence = SKAction.sequence([
            SKAction.wait(forDuration: displayDuration),
            SKAction.fadeOut(withDuration: fadeOutDuration),
            SKAction.removeFromParent()
        ])
        textBackground.run(sequence)
    }

    private func openAppStore() {
        if let url = URL(string: "https://apps.apple.com/us/app/shape-jumpin/id6740543756") {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
    
    func startGame(mode: GameMode) {
        let scene = GameScene(size: size); scene.scaleMode = .aspectFill
        scene.gameMode = mode; view?.presentScene(scene, transition: .fade(withDuration: 0.5))
    }
    
    func goToHighScores() {
        let hsScene = HighScoresScene(size: size); hsScene.scaleMode = .aspectFill
        view?.presentScene(hsScene, transition: .fade(withDuration: 0.5))
    }
    
    func goToPublicLeaderboard() {
        let plScene = PublicLeaderboardScene(size: size); plScene.scaleMode = .aspectFill
        view?.presentScene(plScene, transition: .fade(withDuration: 0.5))
    }
    
    func goToUserName() {
        let userNameScene = UserNameScene(size: size); userNameScene.scaleMode = .aspectFill
        view?.presentScene(userNameScene, transition: .fade(withDuration: 0.5))
    }
    
    func goToHowToPlay() {
        let htpScene = HowToPlayScene(size: size); htpScene.scaleMode = .aspectFill
        view?.presentScene(htpScene, transition: .fade(withDuration: 0.5))
    }
    
    func goToLevel1() {
        if let scene = preloadedLevel1 {
            scene.preloadedAudioPlayer = self.preloadedAudioPlayer
            view?.presentScene(scene, transition: .fade(withDuration: 0.5))
        } else if let s = Level1Scene(fileNamed: "Level1Scene") {
            s.scaleMode = .aspectFill
            view?.presentScene(s, transition: .fade(withDuration: 0.5))
        }
    }
    
    func goToLevelsMenu() {
        let levelsMenu = LevelsMenuScene(size: self.size); levelsMenu.scaleMode = .aspectFill
        view?.presentScene(levelsMenu, transition: .fade(withDuration: 0.5))
    }
}
