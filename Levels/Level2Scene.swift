import SpriteKit
import UIKit
import AVFoundation

final class Level2Scene: SKScene, SKPhysicsContactDelegate {

    // MARK: – Physics categories
    private let playerCategory:   UInt32 = 0x1 << 0
    private let obstacleCategory: UInt32 = 0x1 << 1

    // MARK: – Config
    private let originalRadius: CGFloat = 25
    private lazy var adjustedRadius = originalRadius * 0.9
    private lazy var hitboxRadius   = adjustedRadius * 0.56
    private let firstJumpVelocity:  CGFloat = 520
    private let baseSecondJumpVelocity: CGFloat = 260
    private let groundSnapTolerance: CGFloat = 95 + 70
    
    //Audio
    var audioPlayer: AVAudioPlayer?
    var preloadedAudioPlayer: AVAudioPlayer? // This would be set externally if level-specific preloading is done
    private var levelCompleteAudioPlayer: AVAudioPlayer?

    // MARK: – State
    private var canFirstJump = true
    private var canSecondJump = false
    private var secondJumpHoldActive = false
    private var secondJumpHoldEnd: TimeInterval = 0
    private var lastFrameTime: TimeInterval = 0
    private var levelCompleteQueued = false
    private var isTransitioningToGameOver = false

    // Timing / pause
    private var startTime: TimeInterval = 0
    private var totalPausedTime: TimeInterval = 0
    private var pauseStartTime: TimeInterval = 0
    private var isGameplayInactive = false // Our new custom flag

    // Invincibility
    private var isInvincible = false
    private var invincibleUntil: TimeInterval = 0

    // Pause UI
    private var isPauseMenuShowing = false
    private var pauseButton: SKNode!
    private var pauseMenu: SKNode?

    // Input
    private var activeTouches = Set<UITouch>()
    private var isDucking = false

    // Nodes
    private var player:       SKSpriteNode!
    private var duckPlayer:   SKSpriteNode!
    private var ground:       SKSpriteNode!
    private var cameraNode:   SKCameraNode!

    // Obstacles
    private var obstacles: [SKSpriteNode] = []

    // UI
    private var hp = 3
    private var score = 0 // Represents bonusScore from margins
    private var baseScore = 0 // Currently reset in update, effectively unused for final score
    private var bonusScore = 0 // Accumulates margin points
    private let scoreLabel = SKLabelNode()
    private let hpLabel    = SKLabelNode()
    
    //vibrate
    private var lightImpactFeedbackGenerator: UIImpactFeedbackGenerator?
    private var heavyImpactFeedbackGenerator: UIImpactFeedbackGenerator?
    
    //score
    private var totalScoreLabelNode: SKLabelNode?
    
    //gameOver
    private var gameOverOverlayNode: SKNode?
    
    //initial position
    private let playerInitialX: CGFloat = -850.0
    private let playerInitialY: CGFloat = -132.717
    private let playerInitialRotation: CGFloat = 0.0

    // MARK: – didMove
    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        physicsWorld.contactDelegate = self
        
        playBackgroundMusic()
        
        lightImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        heavyImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
        
        lightImpactFeedbackGenerator?.prepare()
        heavyImpactFeedbackGenerator?.prepare()

        player  = childNode(withName: "//player")  as? SKSpriteNode
        ground  = childNode(withName: "//ground")  as? SKSpriteNode

        if player.physicsBody == nil {
            player.physicsBody = SKPhysicsBody(circleOfRadius: hitboxRadius)
        }
        configurePlayerBody(player.physicsBody)

        duckPlayer = SKSpriteNode(texture: player.texture)
        duckPlayer.size = CGSize(width: adjustedRadius, height: adjustedRadius)
        duckPlayer.zPosition = player.zPosition
        duckPlayer.position = CGPoint(
            x: player.position.x,
            y: ground.position.y + duckPlayer.size.height / 2
        )
        duckPlayer.name = "duckPlayer"
        duckPlayer.physicsBody = SKPhysicsBody(circleOfRadius: adjustedRadius / 2.4)
        configurePlayerBody(duckPlayer.physicsBody)
        duckPlayer.isHidden = true
        addChild(duckPlayer)

        if ground.physicsBody == nil {
            ground.physicsBody = SKPhysicsBody(rectangleOf: ground.frame.size)
        }
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.categoryBitMask = 0

        // =================== OPTIMIZATION START ===================
        // This loop now checks for both circles and rectangles to create
        // the most efficient physics body possible.
        enumerateChildNodes(withName: "//shape*") { node, _ in
            guard let s = node as? SKSpriteNode else { return }
            
            let hitboxShrinkFactorCircle: CGFloat = 0.625
            let hitboxShrinkFactorRectangle: CGFloat = 0.54
            let hitboxShrinkFactorAlpha: CGFloat = 0.7

            // For nodes named "shapeCircle", use a highly efficient circular body.
            if node.name == "shapeCircle" {
                let hitboxRadius = (s.size.width / 2.0) * hitboxShrinkFactorCircle
                s.physicsBody = SKPhysicsBody(circleOfRadius: hitboxRadius)
            }
            // For nodes named "shapeRectangle", use a highly efficient rectangular body.
            else if node.name == "shapeRectangle" {
                let hitboxSize = CGSize(width: s.size.width * hitboxShrinkFactorRectangle,
                                        height: s.size.height * hitboxShrinkFactorRectangle)
                s.physicsBody = SKPhysicsBody(rectangleOf: hitboxSize)
            }
            // For all other shapes, use the original, more performance-intensive
            // method of generating the body from the texture's alpha mask.
            else {
                if let tex = s.texture {
                    let hitboxSize = CGSize(width: s.size.width * hitboxShrinkFactorAlpha,
                                            height: s.size.height * hitboxShrinkFactorAlpha)
                    s.physicsBody = SKPhysicsBody(texture: tex, size: hitboxSize)
                } else {
                    // Fallback for any shape nodes that might be missing a texture
                    s.physicsBody = SKPhysicsBody(rectangleOf: s.size)
                }
            }
            
            // This configuration is applied to all shapes, regardless of how
            // their physics body was created.
            s.physicsBody?.isDynamic           = false
            s.physicsBody?.categoryBitMask     = self.obstacleCategory
            s.physicsBody?.contactTestBitMask  = self.playerCategory
            s.physicsBody?.collisionBitMask    = 0
            if s.userData == nil { s.userData = [:] }
            self.obstacles.append(s)
        }
        // =================== OPTIMIZATION END =====================
        
        cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.xScale = 0.725
        cameraNode.yScale = 0.725

        setupLabels()
        setupPauseUI()
        
        run(.wait(forDuration: 0)) { [weak self] in
                self?.audioPlayer?.play()
            }
    }

    private func configurePlayerBody(_ body: SKPhysicsBody?) {
        body?.isDynamic           = true
        body?.affectedByGravity   = true
        body?.allowsRotation      = false
        body?.restitution         = 0
        body?.friction            = 0.5
        body?.categoryBitMask     = playerCategory
        body?.contactTestBitMask  = obstacleCategory
        body?.collisionBitMask    = 0
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        // --- 1. Game Over Overlay ---
        if let overlay = gameOverOverlayNode, overlay.alpha > 0, !isTransitioningToGameOver {
            let locationInOverlayNode = touch.location(in: overlay)

            for node in overlay.nodes(at: locationInOverlayNode) {
                if let button = node as? SKShapeNode,
                   (button.name == "gameOverPlayAgain" || button.name == "gameOverMainMenu") {
                    highlightGameOverButton(button)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                        guard let self = self else { return }
                        self.unhighlightGameOverButton(button)
                        switch button.name {
                        case "gameOverPlayAgain":
                            self.resetGameForPlayAgain()
                        case "gameOverMainMenu":
                            self.goToMainMenu()
                        case "levelsButton":        
                            self.goToLevelsMenu()
                        default:
                            break
                        }
                    }
                    return
                }
            }
            let locationInCamera = touch.location(in: cameraNode)
            if overlay.contains(locationInCamera) {
                return
            }
        }

        // --- 2. Pause Menu ---
        if isPauseMenuShowing, let menuNode = self.pauseMenu {
            let locationInMenuNode = touch.location(in: menuNode)

            for node in menuNode.nodes(at: locationInMenuNode) {
                if let labelButton = node as? SKLabelNode {
                    highlightThenAct(labelButton) { [weak self] in
                        guard let self = self else { return }
                        switch labelButton.name {
                        case "resumeButton": self.hidePauseMenu()
                        case "restartButton":
                            self.hidePauseMenu()
                            self.restartLevel()
                        case "mainMenuButton":
                            self.goToMainMenu()
                        case "levelsButton":
                            self.goToLevelsMenu()
                        default: break
                        }
                    }
                    return
                }
            }
            if let pauseOverlayBackground = cameraNode.childNode(withName: "pauseOverlay") {
                let locationInCamera = touch.location(in: cameraNode)
                if pauseOverlayBackground.contains(locationInCamera) {
                    return
                }
            }
        }

        // --- 3. Pause Button ---
        if gameOverOverlayNode == nil && !isPauseMenuShowing   && !levelCompleteQueued {
            let locationForPauseButton = touch.location(in: self.pauseButton.parent ?? self)
            
            if self.pauseButton.contains(locationForPauseButton) {
                 if let label = self.pauseButton.childNode(withName: "pauseLabel") as? SKLabelNode {
                    highlightThenActPause(label) { [weak self] in
                        self?.showPauseMenu()
                    }
                } else {
                    showPauseMenu()
                }
                return
            }
        }

        // --- 4. Game Input (Jumping/Ducking) ---
        if isGameplayInactive {
            return
        }

        activeTouches.formUnion(touches)
        updateInputState(began: touches)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches); updateInputState(began: nil)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches); updateInputState(began: nil)
    }
    
    private func removeGameOverUI() {
        gameOverOverlayNode?.removeFromParent()
        gameOverOverlayNode = nil
        isTransitioningToGameOver = false
    }

    private func resetGameForPlayAgain() {
        removeGameOverUI()

        player.position = CGPoint(x: playerInitialX, y: playerInitialY)
        player.zRotation = playerInitialRotation
        player.physicsBody?.velocity = .zero
        player.physicsBody?.affectedByGravity = true
        player.isHidden = false
        player.colorBlendFactor = 0

        if let groundNode = self.ground {
            duckPlayer.position = CGPoint(x: playerInitialX,
                                          y: groundNode.position.y + duckPlayer.size.height / 2)
            duckPlayer.zRotation = playerInitialRotation
        }
        duckPlayer.physicsBody?.velocity = .zero
        duckPlayer.isHidden = true
        duckPlayer.colorBlendFactor = 0

        hp = 3
        score = 0
        bonusScore = 0
        updateLabels()

        canFirstJump = true
        canSecondJump = false
        secondJumpHoldActive = false
        secondJumpHoldEnd = 0
        isInvincible = false
        invincibleUntil = 0
        
        activeTouches.removeAll()
        isDucking = false
        levelCompleteQueued = false

        for obs in obstacles {
            obs.userData?["collided"] = false
            obs.userData?["scored"] = false
        }

        cameraNode.removeAllActions()
        if let groundNode = self.ground {
            cameraNode.position = CGPoint(x: playerInitialX + 140,
                                          y: groundNode.position.y + 175)
        }
        cameraNode.isPaused = false

        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        audioPlayer?.volume = SoundSettings.isMuted ? 0 : 0.5
        audioPlayer?.play()

        startTime = 0
        totalPausedTime = 0
        lastFrameTime = 0

        let gameplayResumeDelay = SKAction.wait(forDuration: 0.01)
        
        self.run(gameplayResumeDelay) { [weak self] in
            guard let self = self else { return }
            self.isGameplayInactive = false
            self.physicsWorld.speed = 1.0
            print("Gameplay resumed after delay. Player should now be active.")
        }
        print("--- resetGameForPlayAgain() setup complete. Gameplay will resume after delay. ---")
    }

    private func updateInputState(began: Set<UITouch>?) {
        if activeTouches.count >= 2 { enterDuckMode() } else { exitDuckMode() }
        if activeTouches.count == 1, began?.count == 1, !isDucking { doSingleJump() }
    }
    private func doSingleJump() {
        let n = activeNode()
        if canFirstJump {
            n.physicsBody?.velocity = CGVector(dx: 0, dy: firstJumpVelocity)
            canFirstJump = false; canSecondJump = true
        } else if canSecondJump {
            n.physicsBody?.velocity = CGVector(dx: 0, dy: baseSecondJumpVelocity)
            canSecondJump = false
            secondJumpHoldActive = true
            secondJumpHoldEnd = CACurrentMediaTime() + 0.8175
        }
    }
    private func enterDuckMode() {
        guard !isDucking else { return }
        if abs(player.position.y - (ground.position.y + player.size.height/2)) > groundSnapTolerance { return }
        player.position.y = ground.position.y + player.size.height/2
        isDucking = true
        player.isHidden = true
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.velocity = .zero
        let bottom = player.position.y - player.size.height/2
        duckPlayer.position = CGPoint(x: player.position.x, y: bottom + duckPlayer.size.height/2)
        duckPlayer.physicsBody?.affectedByGravity = true
        duckPlayer.physicsBody?.velocity = .zero
        duckPlayer.physicsBody?.restitution = 0
        duckPlayer.isHidden = false
        canFirstJump = true; canSecondJump = false
    }
    private func exitDuckMode() {
        guard isDucking else { return }
        isDucking = false
        let currentDuckVelocity = duckPlayer.physicsBody?.velocity ?? .zero
        let currentDuckPositionX = duckPlayer.position.x
        let currentDuckPositionY = duckPlayer.position.y
        let currentDuckRotation = duckPlayer.zRotation
        player.position.x = currentDuckPositionX
        player.position.y = currentDuckPositionY - (duckPlayer.size.height / 2) + (player.size.height / 2)
        player.zRotation = currentDuckRotation
        player.physicsBody?.velocity = currentDuckVelocity
        duckPlayer.isHidden = true
        duckPlayer.physicsBody?.affectedByGravity = false
        duckPlayer.physicsBody?.velocity = .zero
        player.physicsBody?.affectedByGravity = true
        player.isHidden = false
        canFirstJump = true
        canSecondJump = false
    }
    private func activeNode()   -> SKSpriteNode { isDucking ? duckPlayer : player }
    private func inactiveNode() -> SKSpriteNode { isDucking ? player : duckPlayer }

    override func update(_ currentTime: TimeInterval) {
        if isGameplayInactive {
            return
        }
        if isPaused { return }
        
        let currentPlayerNode = activeNode()
        if !levelCompleteQueued && currentPlayerNode.position.x  >= 6192 { // Assuming level length is same
            levelCompleteQueued = true
            showLevelComplete()
        }

        let dt = lastFrameTime > 0 ? currentTime - lastFrameTime : 0
        lastFrameTime = currentTime

        if startTime == 0 { startTime = currentTime }

        let n = activeNode()
        if n.position.x >= 6192 { // Assuming level length is same
            n.physicsBody?.velocity.dx = 0
        } else {
            n.physicsBody?.velocity.dx = 175
        }
        inactiveNode().physicsBody?.velocity = .zero
        if cameraNode.position.x < 6050 { // Assuming camera max position is same
            cameraNode.position = CGPoint(x: n.position.x + 140,
                                          y: ground.position.y + 245)
        } else {
            cameraNode.position.x = 6050
        }

        let spin = ((2 * .pi) / 1.4) * CGFloat(dt)
        player.zRotation -= spin; duckPlayer.zRotation -= spin

        if secondJumpHoldActive {
            if activeTouches.isEmpty || CACurrentMediaTime() >= secondJumpHoldEnd {
                secondJumpHoldActive = false
            } else { n.physicsBody?.velocity.dy += CGFloat(465 * dt) }
        }
        if isInvincible && CACurrentMediaTime() >= invincibleUntil {
            isInvincible = false
            player.colorBlendFactor = 0; duckPlayer.colorBlendFactor = 0
        }
        updateLabels()
        checkObstacleMargins()
    }
    override func didSimulatePhysics() {
        let n = activeNode()
        let minY = ground.position.y + n.size.height/2 + 145
        if n.position.y < minY {
            n.position.y = minY
            n.physicsBody?.velocity.dy = 0
            canFirstJump = true; canSecondJump = false
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let playerBody: SKPhysicsBody?
        let obsBody: SKPhysicsBody?
        if contact.bodyA.categoryBitMask & playerCategory != 0 &&
           contact.bodyB.categoryBitMask & obstacleCategory != 0 {
            playerBody = contact.bodyA; obsBody = contact.bodyB
        } else if contact.bodyB.categoryBitMask & playerCategory != 0 &&
                  contact.bodyA.categoryBitMask & obstacleCategory != 0 {
            playerBody = contact.bodyB; obsBody = contact.bodyA
        } else { return }

        guard !isInvincible else { return }

        obsBody?.node?.userData?["collided"] = true
        hp -= 1; updateLabels()
        
        if hp > 0 {
            self.lightImpactFeedbackGenerator?.impactOccurred()
        } else {
            self.heavyImpactFeedbackGenerator?.impactOccurred()
        }
        
        isInvincible = true
        invincibleUntil = CACurrentMediaTime() + 0.9

        if let hit = playerBody?.node as? SKSpriteNode {
            hit.colorBlendFactor = 0.8; hit.color = .red
            spawnDamageLabel("-1", at: hit.position)
        }
        if hp <= 0 { endLevel() }
    }
    
    private func showLevelComplete() {
        audioPlayer?.stop()
        pauseButton.isHidden = true

        if let url = Bundle.main.url(forResource: "CONGRATS4", withExtension: "m4a") { // Assuming same congrats sound
            do {
                let volume: Float = SoundSettings.isMuted ? 0 : 0.085
                levelCompleteAudioPlayer = try AVAudioPlayer(contentsOf: url)
                levelCompleteAudioPlayer?.volume = volume
                levelCompleteAudioPlayer?.numberOfLoops = 0
                levelCompleteAudioPlayer?.prepareToPlay()
                levelCompleteAudioPlayer?.play()
            } catch {
                print("Error loading or playing CONGRATS4.m4a: \(error.localizedDescription)")
            }
        } else {
            print("CONGRATS4.m4a sound file not found in bundle.")
        }

        physicsWorld.speed = 0
        player.physicsBody?.velocity = .zero
        player.physicsBody?.affectedByGravity = false

        let hardcodedScenePoint = CGPoint(x: 6192, y: ground.position.y + 95)
        let base = cameraNode.convert(hardcodedScenePoint, from: self)
        let anchorX   = base.x - 450
        let valueX    = anchorX + 200
        var anchorYFromBase = base.y + 250

        let centerX   = (anchorX + valueX) / 2

        let congratsSprite = SKSpriteNode(imageNamed: "CONGRATS!")
        congratsSprite.position = CGPoint(x: centerX, y: anchorYFromBase)
        congratsSprite.setScale(0.0)
        cameraNode.addChild(congratsSprite)

        let popIn = SKAction.sequence([
            .scale(to: 0.45, duration: 0.33),
            .scale(to: 0.37, duration: 0.12),
            .wait(forDuration: 1.3)
        ])

        congratsSprite.run(popIn) { [weak self] in
            guard let self = self else { return }
            self.showLevelCompleteLabels(anchorX: anchorX, valueX: valueX, initialDisplayAnchorY: anchorYFromBase - 80)
        }
    }

    private func showLevelCompleteLabels(anchorX: CGFloat, valueX: CGFloat, initialDisplayAnchorY: CGFloat) {
        var currentDisplayAnchorY = initialDisplayAnchorY

        func makeRow(prefix: String, value: String) -> SKLabelNode {
            let p = SKLabelNode(text: prefix)
            p.fontName = "Avenir-Black"
            p.fontSize = 32
            p.fontColor = .white
            p.horizontalAlignmentMode = .left
            p.position = CGPoint(x: anchorX, y: currentDisplayAnchorY)
            cameraNode.addChild(p)

            let n = SKLabelNode(text: value)
            n.fontName = p.fontName
            n.fontSize = p.fontSize
            n.fontColor = p.fontColor
            n.horizontalAlignmentMode = .right
            n.position = CGPoint(x: valueX, y: p.position.y)
            cameraNode.addChild(n)

            currentDisplayAnchorY -= 40
            return n
        }

        let hpNum       = makeRow(prefix: "HP:", value: "\(hp < 0 ? 0 : hp)")
        let scoreNum    = makeRow(prefix: "Score:", value: "\(self.score)")
        
        let totalNumLocal = makeRow(prefix: "Total:", value: "0")
        self.totalScoreLabelNode = totalNumLocal

        var hpLeft    = self.hp < 0 ? 0 : self.hp
        var scoreLeft = self.score
        var calculatedFinalTotal = 0

        func runHP() {
            if hpLeft > 0 {
                run(.sequence([
                    .wait(forDuration: 1.0),
                    .run {
                        hpLeft        -= 1
                        hpNum.text    = "\(hpLeft)"
                        calculatedFinalTotal += 5
                        totalNumLocal.text  = "\(calculatedFinalTotal)"
                        runHP()
                    }
                ]))
            } else {
                run(.sequence([
                    .wait(forDuration: 1.0),
                    .run { runScore() }
                ]))
            }
        }

        func runScore() {
            guard scoreLeft > 0 else {
                let finalScoreForLevel = calculatedFinalTotal
                let currentLevelID = "level2"

                let previousHighScore = LevelDataManager.shared.getHighScore(forLevel: currentLevelID) ?? 0
                let isNewRecord = finalScoreForLevel > previousHighScore

                if let labelToCircle = self.totalScoreLabelNode {
                    let waitAction = SKAction.wait(forDuration: 1.4)
                    let drawOvalAction = SKAction.run { [weak self] in
                        self?.drawAnimatedOvalAroundTotal(nodeToCircle: labelToCircle, isNewHighScore: isNewRecord)
                    }
                    let sequence = SKAction.sequence([waitAction, drawOvalAction])
                    self.run(sequence)
                } else {
                    print("Error: totalScoreLabelNode is nil. Cannot draw oval.")
                }
                
                LevelDataManager.shared.saveHighScore(forLevel: currentLevelID, score: finalScoreForLevel)
                print("Saved Level 2 local high score: \(finalScoreForLevel)")

                LevelLeaderboardManager.shared.submitScore(levelID: currentLevelID, score: finalScoreForLevel) { error in
                    if let error = error {
                        print("Error submitting Level 2 score to public leaderboard: \(error.localizedDescription)")
                    } else {
                        print("Level 2 score (\(finalScoreForLevel)) submitted successfully to public leaderboard.")
                    }
                }
                
                run(.sequence([
                    .wait(forDuration: 4.5),
                    .run { self.goToLevelsMenu() }
                ]))
                return
            }
            
            scoreLeft        -= 1
            scoreNum.text    = "\(scoreLeft)"
            calculatedFinalTotal += 1
            totalNumLocal.text   = "\(calculatedFinalTotal)"
            
            run(.sequence([
                .wait(forDuration: 0.011),
                .run { runScore() }
            ]))
        }
        runHP()
    }

    private func drawAnimatedOvalAroundTotal(nodeToCircle: SKLabelNode, isNewHighScore: Bool) {
        let ovalWidth: CGFloat = 92
        let ovalHeight: CGFloat = 60

        let shape = SKShapeNode()
        
        if isNewHighScore {
            shape.strokeColor = .green
            
            let newRecordLabel = SKLabelNode(text: "New Record!")
            newRecordLabel.fontName = "Avenir-Black"; newRecordLabel.fontSize = 18
            newRecordLabel.fontColor = .green
            newRecordLabel.position = CGPoint(x: nodeToCircle.position.x - 23, y: nodeToCircle.position.y - (ovalHeight / 2) - 20)
            newRecordLabel.alpha = 0
            newRecordLabel.zPosition = nodeToCircle.zPosition + 1
            cameraNode.addChild(newRecordLabel)
            
            newRecordLabel.run(SKAction.sequence([
                .wait(forDuration: 1.25),
                .fadeIn(withDuration: 0.3),
                .wait(forDuration: 2.0),
                .fadeOut(withDuration: 0.3),
                .removeFromParent()
            ]))
        } else {
            shape.strokeColor = SKColor(white: 0.97, alpha: 1.0)
        }
        
        shape.lineWidth = 8
        shape.lineCap = .round
        shape.glowWidth = 2
        shape.zPosition = nodeToCircle.zPosition - 1
        
        shape.position = CGPoint(x: nodeToCircle.position.x - 26, y: nodeToCircle.position.y + 10)

        shape.path = nil
        cameraNode.addChild(shape)

        let drawDuration: TimeInterval = 0.7
        let startAngle = -CGFloat.pi/2
        let endAngleFull = startAngle + CGFloat.pi * 2

        let drawAction = SKAction.customAction(withDuration: drawDuration) { node, elapsed in
            let percent = max(0, min(1, CGFloat(elapsed / CGFloat(drawDuration))))
            let currentEndAngle = startAngle + (endAngleFull - startAngle) * percent
            
            var partialPath = UIBezierPath(
                arcCenter: .zero,
                radius: ovalWidth / 2,
                startAngle: startAngle,
                endAngle: currentEndAngle,
                clockwise: true
            )
            var t = CGAffineTransform.identity
            t = t.scaledBy(x: 1, y: ovalHeight / ovalWidth)
            partialPath.apply(t)
            
            (node as! SKShapeNode).path = partialPath.cgPath
        }
        shape.run(drawAction)
    }

    // MARK: – Margin scoring
    private func checkObstacleMargins() {
        let n = activeNode()
        for obs in obstacles {
            if obs.userData?["scored"] as? Bool == true { continue }
            if obs.userData?["collided"] as? Bool == true { continue }
            if obs.position.x + obs.frame.width/2 < n.position.x - n.size.width/2 {
                obs.userData?["scored"] = true
                let dx = n.position.x - obs.position.x
                let dy = n.position.y - obs.position.y
                let dist = hypot(dx, dy)
                let margin = dist - (n.size.width/2 + obs.frame.width/2)
                awardMarginPoints(margin, obstacle: obs)
            }
        }
    }
    private func awardMarginPoints(_ margin: CGFloat, obstacle: SKSpriteNode) {
        let bonus: Int
        switch margin {
        case ..<10:  bonus = 1
        case ..<25:  bonus = 2
        case ..<45:  bonus = 3
        case ..<60:  bonus = 4
        default:     bonus = 5
        }
        bonusScore += bonus
        self.score = bonusScore
        spawnMarginLabel("+\(bonus)", at: obstacle.position, bonus: bonus)
    }

    // MARK: – Labels
    private func setupLabels() {
        scoreLabel.fontSize = 32; scoreLabel.fontName = "Avenir-Black"
        scoreLabel.fontColor = .white; scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: -size.width/2 + 70,
                                      y:  size.height/2 - 50)
        cameraNode.addChild(scoreLabel)

        hpLabel.fontSize = 32; hpLabel.fontName = "Avenir-Black"
        hpLabel.fontColor = .white; hpLabel.horizontalAlignmentMode = .left
        hpLabel.position = CGPoint(x: -size.width/2 + 280,
                                   y:  size.height/2 - 50)
        cameraNode.addChild(hpLabel)
        updateLabels()
    }
    private func updateLabels() {
        scoreLabel.text = "Score: \(self.score)"
        hpLabel.text    = "HP: \(hp < 0 ? 0 : hp)"
    }
    private func spawnMarginLabel(_ text: String, at pos: CGPoint, bonus: Int) {
        let lbl = SKLabelNode(text: text)
        lbl.fontName = "Avenir-Black"; lbl.fontSize = 32
        lbl.fontColor = (bonus <= 2) ? .yellow : .green
        lbl.position = pos; lbl.alpha = 0
        addChild(lbl)
        lbl.run(.sequence([
            .fadeIn(withDuration: 0.2),
            .group([
                .moveBy(x: 0, y: 40, duration: 1.1),
                .fadeOut(withDuration: 1.1)
            ]),
            .removeFromParent()
        ]))
    }
    private func spawnDamageLabel(_ text: String, at pos: CGPoint) {
        let lbl = SKLabelNode(text: text)
        lbl.fontName = "Avenir-Black"; lbl.fontSize = 32; lbl.fontColor = .red
        lbl.position = pos; addChild(lbl)
        lbl.run(.sequence([
            .fadeIn(withDuration: 0.2),
            .group([
                .moveBy(x: 0, y: 40, duration: 1.1),
                .fadeOut(withDuration: 1.1)
            ]),
            .removeFromParent()
        ]))
    }
    
    private func playBackgroundMusic() {
        /*do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("Audio session error: \(error.localizedDescription)") }*/

        if let player = preloadedAudioPlayer {
            self.audioPlayer = player
            print("Using preloaded audio player for Level 2.")
        } else {
            print("Preloaded audio player not available for Level 2, loading now.")
            guard let url = Bundle.main.url(forResource: "orange_dream", withExtension: "m4a") else {
                print("orange_dream.m4a not found in bundle")
                return
            }
            do { audioPlayer = try AVAudioPlayer(contentsOf: url) } catch {
                print("Audio player error: \(error.localizedDescription)"); return
            }
        }
        audioPlayer?.volume = SoundSettings.isMuted ? 0 : 0.5
        audioPlayer?.numberOfLoops = -1
        audioPlayer?.prepareToPlay()
        //audioPlayer?.play()
    }

    // MARK: – Pause UI
    private func setupPauseUI() {
        pauseButton = createPauseButton()
        pauseButton.position = CGPoint(x: size.width/2 - 60, y: size.height/2 - 60)
        cameraNode.addChild(pauseButton)

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    private func createPauseButton() -> SKNode {
        let p = SKNode(); p.name = "pauseButton"
        let hit = SKShapeNode(circleOfRadius: 65)
        hit.fillColor = .clear; hit.strokeColor = .clear; hit.name = "pauseButton"
        p.addChild(hit)
        let label = SKLabelNode(text: "II")
        label.fontName = "Avenir-Black"; label.fontSize = 45
        label.fontColor = .white; label.verticalAlignmentMode = .center
        label.name = "pauseLabel"
        p.addChild(label)
        return p
    }
    private func highlightThenAct(_ l: SKLabelNode, completion: @escaping () -> Void) {
        let orig = l.fontColor; l.fontColor = .cyan
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { l.fontColor = orig; completion() }
    }
    private func highlightThenActPause(_ l: SKLabelNode, completion: @escaping () -> Void) {
        let orig = l.fontColor; l.fontColor = .cyan
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { l.fontColor = orig; completion() }
    }
    func showPauseMenu() {
        isPaused = true; isPauseMenuShowing = true; pauseStartTime = CACurrentMediaTime()
        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = SKColor.black.withAlphaComponent(0.6)
        overlay.zPosition = 10; overlay.name = "pauseOverlay"; overlay.strokeColor = .clear
        cameraNode.addChild(overlay)
        let menu = SKNode(); menu.zPosition = 11; menu.name = "pauseMenu"
        menu.addChild(createMenuButton("Resume",     name: "resumeButton",   y:  55))
        menu.addChild(createMenuButton("Start Over", name: "restartButton",  y:  5))
        menu.addChild(createMenuButton("Main Menu",  name: "mainMenuButton", y: -45))
        menu.addChild(createMenuButton("Levels",     name: "levelsButton",   y: -95)) // New button
        cameraNode.addChild(menu); pauseMenu = menu
        pauseButton.isHidden = true
    }
    func hidePauseMenu() {
        isPaused = false; isPauseMenuShowing = false
        totalPausedTime += CACurrentMediaTime() - pauseStartTime
        pauseMenu?.removeFromParent()
        cameraNode.childNode(withName: "pauseOverlay")?.removeFromParent()
        pauseButton.isHidden = false
    }
    private func createMenuButton(_ t: String, name: String, y: CGFloat) -> SKLabelNode {
        let b = SKLabelNode(text: t)
        b.fontName = "Avenir-Black"; b.fontSize = 32; b.fontColor = .white
        b.position = CGPoint(x: 0, y: y); b.name = name
        return b
    }
    @objc private func appDidEnterBackground() { if !isPauseMenuShowing { showPauseMenu() } }
    @objc private func appWillResignActive()   { if !isPauseMenuShowing { showPauseMenu() } }
    @objc private func appDidBecomeActive()    { if isPauseMenuShowing { isPaused = true } }

    // MARK: – Scene transitions
    private func restartLevel() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        resetGameForPlayAgain()
    }
    private func goToMainMenu() {
        guard let view = self.view else {
            print("Error: Scene is not currently in a view.")
            return
        }
        let mainMenuScene = MainMenuScene(size: view.bounds.size)
        mainMenuScene.scaleMode = .aspectFill
        view.presentScene(mainMenuScene, transition: .fade(withDuration: 0.5))
    }
    private func goToLevelsMenu() {
        guard let view = self.view else {
            print("Error: Scene is not currently in a view.")
            return
        }
        let levelsMenuScene = LevelsMenuScene(size: view.bounds.size)
        levelsMenuScene.scaleMode = .aspectFill
        view.presentScene(levelsMenuScene, transition: .fade(withDuration: 0.5))
    }
    
    private func makeGameOverButton(text: String, name: String) -> SKShapeNode {
        let widthMultiplier: CGFloat = 0.22
        let baseHeight: CGFloat = 50
        let baseFontSize: CGFloat = 24

        let width: CGFloat = (view?.bounds.width ?? size.width) * widthMultiplier * (1 / cameraNode.xScale)
        let height: CGFloat = baseHeight * (1 / cameraNode.yScale)
        let btn = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8 * (1 / cameraNode.xScale))
        btn.name = name
        btn.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        btn.strokeColor = .clear

        let label = SKLabelNode(text: text)
        label.fontName = "Avenir-Black"
        label.fontSize = baseFontSize * (1 / cameraNode.yScale)
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        btn.addChild(label)
        return btn
    }

    private func highlightGameOverButton(_ btn: SKShapeNode) { btn.fillColor = .darkGray }
    private func unhighlightGameOverButton(_ btn: SKShapeNode) { btn.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1) }

    private func displayGameOverUI() {
        if gameOverOverlayNode != nil {
            gameOverOverlayNode?.removeFromParent()
            gameOverOverlayNode = nil
        }

        gameOverOverlayNode = SKNode()
        gameOverOverlayNode!.zPosition = 200
        gameOverOverlayNode!.isPaused = false
        gameOverOverlayNode!.alpha = 0.0

        cameraNode.addChild(gameOverOverlayNode!)

        let overlayBackground = SKShapeNode(rectOf: CGSize(width: size.width / cameraNode.xScale, height: size.height / cameraNode.yScale))
        overlayBackground.fillColor = SKColor.black
        overlayBackground.strokeColor = .clear
        overlayBackground.zPosition = -1
        gameOverOverlayNode!.addChild(overlayBackground)

        let viewWidthInCamera = (self.view?.bounds.width ?? self.size.width) / cameraNode.xScale
        let viewHeightInCamera = (self.view?.bounds.height ?? self.size.height) / cameraNode.yScale
        let uiGroupXPosition = (viewWidthInCamera * 0.25) - (20 / cameraNode.xScale)

        let finalScore = self.score
        let scoreLabel = SKLabelNode(text: "Score: \(finalScore)")
        scoreLabel.fontName = "Avenir-Black"
        scoreLabel.fontSize = 34 * (1 / cameraNode.yScale)
        scoreLabel.fontColor = SKColor(red: 0.5, green: 1.0, blue: 0.7, alpha: 1.0)
        scoreLabel.position = CGPoint(x: uiGroupXPosition, y: viewHeightInCamera * 0.22)
        gameOverOverlayNode!.addChild(scoreLabel)

        let playAgain = makeGameOverButton(text: "Play Again", name: "gameOverPlayAgain")
        playAgain.position = CGPoint(x: uiGroupXPosition, y: viewHeightInCamera * 0.05)
        gameOverOverlayNode!.addChild(playAgain)

        let menu = makeGameOverButton(text: "Main Menu", name: "gameOverMainMenu")
        let buttonVerticalSpacing = playAgain.frame.height * 0.2
        menu.position = CGPoint(x: uiGroupXPosition, y: playAgain.position.y - playAgain.frame.height - buttonVerticalSpacing)
        gameOverOverlayNode!.addChild(menu)
        
        let levelLength: CGFloat = 5700
        let distanceTravelled = min(player.position.x, levelLength)

        let bar = SKSpriteNode(imageNamed: "start_finish")
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        guard let barTexture = bar.texture else {
            print("Error: Bar texture 'start_finish' is missing or nil.")
            return
        }
        let barWidthInCamera = viewWidthInCamera * 0.38
        let barScaleValue = barWidthInCamera / barTexture.size().width
        bar.setScale(barScaleValue)
        let originalBarX = -viewWidthInCamera * 0.45
        let totalBarXOffset = 70 / cameraNode.xScale
        bar.position = CGPoint(x: originalBarX + totalBarXOffset, y: viewHeightInCamera * 0.05)
        gameOverOverlayNode!.addChild(bar)
        
        let capInset = bar.size.height * 0.5
        let lineStartX = bar.position.x + capInset
        let lineEndX = bar.position.x + bar.size.width - capInset
        let progressW = lineEndX - lineStartX
                
        let marker = SKSpriteNode(imageNamed: "felt_ball2")
        guard marker.texture != nil else {
            print("Error: Marker texture 'felt_ball2' is missing or nil.")
            return
        }
        marker.setScale(0.03 * (1 / cameraNode.xScale))
        marker.position = CGPoint(x: lineStartX, y: bar.position.y)
        marker.isPaused = false
        gameOverOverlayNode!.addChild(marker)
        
        let pct = max(0, min(1, distanceTravelled / levelLength))
        let tgtX = lineStartX + progressW * pct
        let moveActionForMarker = SKAction.moveTo(x: tgtX, duration: 2)
        moveActionForMarker.timingMode = .easeOut
        let spinsForMarker: CGFloat = 6
        let spinAngleForMarker = -CGFloat.pi * 0.8 * spinsForMarker
        let spinActionForMarker = SKAction.rotate(byAngle: spinAngleForMarker, duration: 2)
        spinActionForMarker.timingMode = .easeOut

        let fadeInAction = SKAction.fadeIn(withDuration: 0.45)
        gameOverOverlayNode!.run(fadeInAction) { [weak self] in
            guard let self = self else { return }
            
            self.isTransitioningToGameOver = false
            print("Game Over UI fade-in complete. UI is now interactive.")

            if progressW > 0 {
                 marker.run(.group([moveActionForMarker, spinActionForMarker])) {
                    print("Marker animation group COMPLETED (after fade-in). Final marker X: \(marker.position.x)")
                }
            } else {
                print("Marker animation skipped: progressW (\(progressW)) is not positive. Check bar size and capInset.")
            }
        }
    }
    // MARK: – End level stub
    private func endLevel() {
        isGameplayInactive = true
        physicsWorld.speed = 0
        audioPlayer?.pause()
        self.cameraNode.isPaused = false
        player.physicsBody?.velocity = .zero
        player.removeAllActions()
        duckPlayer.physicsBody?.velocity = .zero
        duckPlayer.removeAllActions()
        isTransitioningToGameOver = true
        displayGameOverUI()
    }
}
