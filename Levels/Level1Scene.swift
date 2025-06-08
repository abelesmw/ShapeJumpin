import SpriteKit
import UIKit
import AVFoundation

final class Level1Scene: SKScene, SKPhysicsContactDelegate {

    // MARK: – Physics categories
    private let playerCategory:   UInt32 = 0x1 << 0
    private let obstacleCategory: UInt32 = 0x1 << 1

    // MARK: – Config
    private let originalRadius: CGFloat = 25
    private lazy var adjustedRadius = originalRadius * 0.9
    private lazy var hitboxRadius   = adjustedRadius * 0.56
    private let firstJumpVelocity:  CGFloat = 520
    private let baseSecondJumpVelocity: CGFloat = 260
    private let groundSnapTolerance: CGFloat = 95
    
    //Audio
    var audioPlayer: AVAudioPlayer?
    var preloadedAudioPlayer: AVAudioPlayer?
    private var levelCompleteAudioPlayer: AVAudioPlayer?

    // MARK: – Cloud config
    private let cloudTextures = [
        SKTexture(imageNamed: "newcloud1"),
        SKTexture(imageNamed: "newcloud2"),
        SKTexture(imageNamed: "newcloud3"),
        SKTexture(imageNamed: "newcloud4")
    ]
    private let cloudScale: CGFloat = 1.0 / 10
    private var lastCloudIndex: Int?

    // New properties for cloud pooling
    private var cloudPool: [SKSpriteNode] = []
    private var currentCloudPoolIndex = 0
    private let numCloudsToPool = 8

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
    private var player:     SKSpriteNode!
    private var duckPlayer: SKSpriteNode!
    private var ground:     SKSpriteNode!
    private var cameraNode: SKCameraNode!

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
        
        for i in 0..<numCloudsToPool {
            let initialTexture = cloudTextures[i % cloudTextures.count]
            let cloud = SKSpriteNode(texture: initialTexture)
            cloud.setScale(cloudScale)
            cloud.alpha = 0
            cloud.zPosition = -5
            cloud.position = CGPoint(x: -10000, y: -10000)
            self.addChild(cloud)
            cloudPool.append(cloud)
        }

        cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.xScale = 0.725
        cameraNode.yScale = 0.725

        setupLabels()
        setupPauseUI()
        scheduleNextCloud()
        
        run(.wait(forDuration: 0)) { [weak self] in
                self?.audioPlayer?.play()
            }
    }

    private func configurePlayerBody(_ body: SKPhysicsBody?) {
        body?.isDynamic          = true
        body?.affectedByGravity  = true
        body?.allowsRotation     = false
        body?.restitution        = 0
        body?.friction           = 0.5
        body?.categoryBitMask    = playerCategory
        body?.contactTestBitMask = obstacleCategory
        body?.collisionBitMask   = 0
    }

    private func scheduleNextCloud() {
        let delay = Double.random(in: 2...4)
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in self?.spawnCloud() }
        ]), withKey: "scheduleNextCloudAction")
    }

    private func spawnCloud() {
        guard !cloudPool.isEmpty else {
            scheduleNextCloud()
            return
        }
        let cloud = cloudPool[currentCloudPoolIndex]
        currentCloudPoolIndex = (currentCloudPoolIndex + 1) % numCloudsToPool
        cloud.removeAllActions()
        let textureIndex: Int
        if let last = lastCloudIndex {
            var pick = [0,1,2,3]; pick.removeAll { $0 == last }
            textureIndex = pick.randomElement() ?? 0
        } else {
            textureIndex = Int.random(in: 0..<cloudTextures.count)
        }
        lastCloudIndex = textureIndex
        cloud.texture = cloudTextures[textureIndex]
        cloud.alpha = CGFloat.random(in: 0.6...0.8)
        let randomYOffset = CGFloat.random(in: ground.position.y + 240 ... ground.position.y + 300)
        let viewWidthInSceneCoords = (self.view?.bounds.width ?? self.size.width) / cameraNode.xScale
        let rightEdgeOfView = cameraNode.position.x + (viewWidthInSceneCoords / 2)
        let spawnX = rightEdgeOfView + (cloud.size.width / 2) + 20
        cloud.position = CGPoint(x: spawnX, y: randomYOffset)
        let distanceToMove = viewWidthInSceneCoords + cloud.size.width + 40
        let speed: CGFloat = CGFloat.random(in: 15...25)
        let duration = TimeInterval(distanceToMove / speed)
        cloud.run(SKAction.sequence([
            .moveBy(x: -distanceToMove, y: 0, duration: duration),
            .run { cloud.alpha = 0 }
        ]))
        scheduleNextCloud()
    }
    // In Level1Scene.swift

    // In Level1Scene.swift

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        // --- 1. Game Over Overlay ---
        // If the game over overlay is visible, it should handle touches exclusively.
        if let overlay = gameOverOverlayNode, overlay.alpha > 0, !isTransitioningToGameOver {
            let locationInOverlayNode = touch.location(in: overlay) // Touches relative to the overlay SKNode

            for node in overlay.nodes(at: locationInOverlayNode) {
                // Check if the touched node is one of our SKShapeNode buttons by name
                if let button = node as? SKShapeNode,
                   (button.name == "gameOverPlayAgain" || button.name == "gameOverMainMenu") {

                    highlightGameOverButton(button) // Highlight the button immediately

                    // Use DispatchQueue to delay unhighlighting and action execution
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                        guard let self = self else { return }

                        self.unhighlightGameOverButton(button) // Unhighlight before action

                        // Perform the button's action
                        switch button.name {
                        case "gameOverPlayAgain":
                            self.resetGameForPlayAgain()
                        case "gameOverMainMenu":
                            //self.removeGameOverUI() // Clean up UI before transitioning
                            self.goToMainMenu()
                        default:
                            // This case should ideally not be reached if the name check is exhaustive
                            break
                        }
                    }
                    return // Touch handled by a Game Over button
                }
            }
            // If the touch was within the general bounds of the overlay background
            // (e.g., on its SKShapeNode background, not a specific button)
            // consume the touch to prevent fall-through.
            let locationInCamera = touch.location(in: cameraNode) // gameOverOverlayNode is child of cameraNode
            if overlay.contains(locationInCamera) { // Check if touch is within the overlay's bounds
                return // Consume touch for Game Over overlay background
            }
        }

        // --- 2. Pause Menu ---
        // If the pause menu is showing (and game over is not), it handles touches.
        if isPauseMenuShowing, let menuNode = self.pauseMenu {
            let locationInMenuNode = touch.location(in: menuNode) // Pause menu buttons are children of menuNode

            for node in menuNode.nodes(at: locationInMenuNode) {
                if let labelButton = node as? SKLabelNode { // Pause menu buttons are SKLabelNodes
                    // Using existing highlightThenAct for pause menu buttons
                    highlightThenAct(labelButton) { [weak self] in
                        guard let self = self else { return }
                        switch labelButton.name {
                        case "resumeButton": self.hidePauseMenu()
                        case "restartButton":
                            self.hidePauseMenu()
                            self.restartLevel()
                        case "mainMenuButton":
                            self.goToMainMenu()
                        case "levelsButton":         // New case
                            self.goToLevelsMenu()
                        default: break
                        }
                    }
                    return // Touch handled by a Pause Menu button
                }
            }
            // If the touch was on the pause menu's background overlay, consume it.
            if let pauseOverlayBackground = cameraNode.childNode(withName: "pauseOverlay") {
                let locationInCamera = touch.location(in: cameraNode)
                if pauseOverlayBackground.contains(locationInCamera) {
                    return // Consume touch for Pause Menu overlay background
                }
            }
        }

        // --- 3. Pause Button ---
        // Interact with the pause button ONLY if no game over screen is up AND not already in the pause menu.
        if gameOverOverlayNode == nil && !isPauseMenuShowing  && !levelCompleteQueued {
            // The pauseButton (SKNode) is a child of cameraNode. Its interactive part might be a child of pauseButton.
            let locationForPauseButton = touch.location(in: self.pauseButton.parent ?? self) // Location relative to pauseButton's parent
            
            if self.pauseButton.contains(locationForPauseButton) { // Check if touch is on the pauseButton SKNode or its children
                 if let label = self.pauseButton.childNode(withName: "pauseLabel") as? SKLabelNode {
                    // Using existing highlightThenActPause for the pause button label
                    highlightThenActPause(label) { [weak self] in
                        self?.showPauseMenu()
                    }
                } else {
                    // Fallback if the label isn't found but a part of the button assembly was hit
                    showPauseMenu()
                }
                return // Touch handled by the Pause Button
            }
        }

        // --- 4. Game Input (Jumping/Ducking) ---
        // This section should ONLY execute if:
        // - No Game Over overlay is active (checked by `gameOverOverlayNode == nil` or `!overlay.isHidden` at the top).
        // - The Pause Menu is not active (checked by `!isPauseMenuShowing` at the top).
        // - The Pause Button itself wasn't the interaction point (checked above).
        // - AND gameplay is not inactive (e.g., due to game over).
        if isGameplayInactive {
            return // If gameplay is inactive (game over state), don't process game input
        }

        // If none of the UI elements above handled the touch, and gameplay is active, process game actions:
        activeTouches.formUnion(touches)
        updateInputState(began: touches) // This handles jump/duck logic
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches); updateInputState(began: nil)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches); updateInputState(began: nil)
    }
    
    // In Level1Scene.swift
    private func removeGameOverUI() {
        gameOverOverlayNode?.removeFromParent()
        gameOverOverlayNode = nil
        isTransitioningToGameOver = false
    }

    // In Level1Scene.swift

    private func resetGameForPlayAgain() {
        removeGameOverUI() // Removes the game over overlay

        // --- Perform all visual and state resets immediately ---
        // --- Player, DuckPlayer, Game Variables, Obstacles, Camera, Clouds, Music, Timers ---

        // Reset Player Visual and Physics State (player will be visible but static)
        player.position = CGPoint(x: playerInitialX, y: playerInitialY)
        player.zRotation = playerInitialRotation
        
        player.physicsBody?.velocity = .zero
        player.physicsBody?.affectedByGravity = true // Gravity will apply, but horizontal movement is via update()
        player.isHidden = false
        player.colorBlendFactor = 0

        // Reset duckPlayer
        if let groundNode = self.ground {
            duckPlayer.position = CGPoint(x: playerInitialX,
                                          y: groundNode.position.y + duckPlayer.size.height / 2)
            duckPlayer.zRotation = playerInitialRotation
        }
        duckPlayer.physicsBody?.velocity = .zero
        duckPlayer.isHidden = true
        duckPlayer.colorBlendFactor = 0

        // Reset Game Variables
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

        // Reset Obstacles
        for obs in obstacles {
            obs.userData?["collided"] = false
            obs.userData?["scored"] = false
        }

        // Reset Camera
        cameraNode.removeAllActions()
        if let groundNode = self.ground {
            cameraNode.position = CGPoint(x: playerInitialX + 140,
                                          y: groundNode.position.y + 175)
        }
        cameraNode.isPaused = false // Ensure camera itself isn't paused

        // Restart Clouds
        self.removeAction(forKey: "scheduleNextCloudAction")
        for cloud in cloudPool {
            cloud.removeAllActions()
            cloud.alpha = 0
            cloud.position = CGPoint(x: -10000, y: -10000)
        }
        currentCloudPoolIndex = 0
        lastCloudIndex = nil
        scheduleNextCloud()

        // Restart Music
        // Music will start playing, but actual game sounds tied to actions might wait
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        audioPlayer?.volume = SoundSettings.isMuted ? 0 : 0.6
        audioPlayer?.play()

        // Reset Timers
        startTime = 0
        totalPausedTime = 0 // If you use this for the main pause menu
        lastFrameTime = 0

        // --- End of immediate visual & state resets ---

        
        let gameplayResumeDelay = SKAction.wait(forDuration: 0.01)
        
        // Run the delay action on the scene itself.
        self.run(gameplayResumeDelay) { [weak self] in
            guard let self = self else { return }

            self.isGameplayInactive = false // NOW allow game logic in update() and input
            self.physicsWorld.speed = 1.0   // NOW restore physics simulation speed

            // Player should start moving horizontally now via logic in your update() method
            // and jump will be enabled via touchesBegan logic.
            print("Gameplay resumed after 0.25s delay. Player should now be active.")
        }

        print("--- resetGameForPlayAgain() setup complete. Gameplay will resume after 0.25s delay. ---")
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
        
        if isGameplayInactive { // If gameplay is inactive, skip all game logic updates
                // We might still want to update specific UI elements here if needed,
                // but SKActions should run independently if the scene isn't paused.
                return
            }
        
        if isPaused { return }
        
        let currentPlayerNode = activeNode()
        if !levelCompleteQueued && currentPlayerNode.position.x  >= 6192 {
            levelCompleteQueued = true
            showLevelComplete()
        }

        let dt = lastFrameTime > 0 ? currentTime - lastFrameTime : 0
        lastFrameTime = currentTime

        if startTime == 0 { startTime = currentTime }
        // let elapsed = (currentTime - totalPausedTime) - startTime // This 'elapsed' is not used further in this function

        let n = activeNode()
        if n.position.x >= 6192 {
            n.physicsBody?.velocity.dx = 0
        } else {
            n.physicsBody?.velocity.dx = 175
        }
        inactiveNode().physicsBody?.velocity = .zero
        if cameraNode.position.x < 6050 {
            cameraNode.position = CGPoint(x: n.position.x + 140,
                                          y: ground.position.y + 175)
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

        // baseScore = 0 // Resetting baseScore here means 'score' will only reflect 'bonusScore'
        // score = baseScore + bonusScore // Effectively score = bonusScore
        // The 'score' property of the class is updated in awardMarginPoints
        updateLabels()
        checkObstacleMargins()
    }
    override func didSimulatePhysics() {
        let n = activeNode()
        let minY = ground.position.y + n.size.height/2 + 75 // This might make player float, adjust if needed
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
        if hp <= 0 { endLevel() } // Removed one of the duplicate calls
    }
    
    private func showLevelComplete() {
        // 1. Stop existing background music
        audioPlayer?.stop()
        // Consider if you want to release the main audioPlayer instance:
        // audioPlayer = nil // This is optional
        
        pauseButton.isHidden = true

        // 2. Load and play "CONGRATS!.m4a"
        if let url = Bundle.main.url(forResource: "CONGRATS4", withExtension: "m4a") {
            do {
                let volume: Float = SoundSettings.isMuted ? 0 : 0.085
                
                levelCompleteAudioPlayer = try AVAudioPlayer(contentsOf: url)
                levelCompleteAudioPlayer?.volume = volume
                levelCompleteAudioPlayer?.numberOfLoops = 0 // Play once
                levelCompleteAudioPlayer?.prepareToPlay()
                levelCompleteAudioPlayer?.play()
            } catch {
                print("Error loading or playing CONGRATS!.m4a: \(error.localizedDescription)")
            }
        } else {
            print("CONGRATS!.m4a sound file not found in bundle.")
        }

        // --- Original visual logic from your provided code ---
        physicsWorld.speed = 0
        player.physicsBody?.velocity = .zero
        player.physicsBody?.affectedByGravity = false

        let hardcodedScenePoint = CGPoint(x: 6192, y: ground.position.y + 95) //
        let base = cameraNode.convert(hardcodedScenePoint, from: self) //
        let anchorX   = base.x - 450 //
        let valueX    = anchorX + 200 //
        var anchorYFromBase = base.y + 150 //

        let centerX   = (anchorX + valueX) / 2 //

        let congratsSprite = SKSpriteNode(imageNamed: "CONGRATS!") // This was 'congrats' in your code, renamed for clarity
        congratsSprite.position = CGPoint(x: centerX, y: anchorYFromBase) //
        congratsSprite.setScale(0.0) //
        cameraNode.addChild(congratsSprite) //

        let popIn = SKAction.sequence([
            .scale(to: 0.45, duration: 0.33), //
            .scale(to: 0.37, duration: 0.12), //
            .wait(forDuration: 1.3) //
        ])

        congratsSprite.run(popIn) { [weak self] in //
            guard let self = self else { return }
            // Pass the calculated anchorY for labels
            self.showLevelCompleteLabels(anchorX: anchorX, valueX: valueX, initialDisplayAnchorY: anchorYFromBase - 80) //
        }
    }

    // STEP 1: Modify the parameter name for clarity if it conflicts with the local variable 'anchorY' inside.
    // Using 'initialDisplayAnchorY' for the parameter.
    private func showLevelCompleteLabels(anchorX: CGFloat, valueX: CGFloat, initialDisplayAnchorY: CGFloat) {
        var currentDisplayAnchorY = initialDisplayAnchorY // Use a mutable copy for positioning rows

        // Row builder for left prefix + right-aligned number label
        func makeRow(prefix: String, value: String) -> SKLabelNode {
            let p = SKLabelNode(text: prefix)
            p.fontName = "Avenir-Black"
            p.fontSize = 32
            p.fontColor = .white
            p.horizontalAlignmentMode = .left
            p.position = CGPoint(x: anchorX, y: currentDisplayAnchorY) // Use currentDisplayAnchorY
            cameraNode.addChild(p)

            let n = SKLabelNode(text: value)
            n.fontName = p.fontName
            n.fontSize = p.fontSize
            n.fontColor = p.fontColor
            n.horizontalAlignmentMode = .right
            n.position = CGPoint(x: valueX, y: p.position.y)
            cameraNode.addChild(n)

            currentDisplayAnchorY -= 40 // Decrement for the next row
            return n // Return the label node that displays the value (e.g., "0")
        }

        // HP above Score, then Total
        let hpNum       = makeRow(prefix: "HP:", value: "\(hp < 0 ? 0 : hp)") // Ensure HP isn't negative
        let scoreNum    = makeRow(prefix: "Score:", value: "\(self.score)") // Use self.score (which is bonusScore)
        
        // STEP 2: Assign the "Total:" label node to the class property self.totalScoreLabelNode
        // You already have 'let totalNum = makeRow(...)' in your code.
        // We also need to store this specific node in the class property.
        let totalNumLocal = makeRow(prefix: "Total:", value: "0") // This is your existing 'totalNum'
        self.totalScoreLabelNode = totalNumLocal // Store the reference
        // IMPORTANT: From now on, for text updates during countdown, use 'totalNumLocal'.
        // For passing to drawAnimatedOvalAroundTotal, use 'self.totalScoreLabelNode'.

        // Counters
        var hpLeft    = self.hp < 0 ? 0 : self.hp // Use capped HP
        var scoreLeft = self.score // This is your bonusScore
        var calculatedFinalTotal = 0 // This will be the final score after tallying

        func runHP() {
            if hpLeft > 0 {
                run(.sequence([
                    .wait(forDuration: 1.0),
                    .run {
                        hpLeft        -= 1
                        hpNum.text     = "\(hpLeft)"
                        calculatedFinalTotal += 5 // HP bonus points
                        totalNumLocal.text  = "\(calculatedFinalTotal)" // Update text of the local 'totalNumLocal'
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

        // STEP 3: Modify the nested runScore() function
        func runScore() {
            guard scoreLeft > 0 else { // Score countdown finished
                // ----> NEW LOGIC STARTS HERE <----
                let finalScoreForLevel = calculatedFinalTotal // This is the true final score
                let currentLevelID = "level1" // Assuming this scene is always for "level1"

                // 1. Check if this is a new high score
                let previousHighScore = LevelDataManager.shared.getHighScore(forLevel: currentLevelID) ?? 0
                let isNewRecord = finalScoreForLevel > previousHighScore

                // 2. Call drawAnimatedOvalAroundTotal with the flag after a delay
                if let labelToCircle = self.totalScoreLabelNode {
                    // Create a wait action
                    let waitAction = SKAction.wait(forDuration: 1.4)
                    // Create an action to run your drawing function
                    let drawOvalAction = SKAction.run { [weak self] in // Use weak self to avoid retain cycles
                        self?.drawAnimatedOvalAroundTotal(nodeToCircle: labelToCircle, isNewHighScore: isNewRecord)
                    }
                    // Create a sequence: wait, then draw
                    let sequence = SKAction.sequence([waitAction, drawOvalAction])
                    // Run the sequence on the scene or a relevant node
                    self.run(sequence) // Or labelToCircle.run(sequence) if 'self' is not an SKNode
                } else {
                    print("Error: totalScoreLabelNode is nil. Cannot draw oval.")
                }
                // ----> NEW LOGIC ENDS HERE <----
                
                // Your existing score saving logic (using finalScoreForLevel)
                LevelDataManager.shared.saveHighScore(forLevel: currentLevelID, score: finalScoreForLevel)
                print("Saved Level 1 local high score: \(finalScoreForLevel)")

                LevelLeaderboardManager.shared.submitScore(levelID: currentLevelID, score: finalScoreForLevel) { error in
                    if let error = error {
                        print("Error submitting Level 1 score to public leaderboard: \(error.localizedDescription)")
                    } else {
                        print("Level 1 score (\(finalScoreForLevel)) submitted successfully to public leaderboard.")
                    }
                }
                
                // Navigate after delay
                run(.sequence([
                    .wait(forDuration: 4.5), // Wait for animations
                    .run { self.goToLevelsMenu() } // Or goToMainMenu()
                ]))
                return // Exit runScore
            }
            
            // Continue score countdown
            scoreLeft        -= 1
            scoreNum.text     = "\(scoreLeft)"
            calculatedFinalTotal += 1 // Score points (from bonusScore)
            totalNumLocal.text  = "\(calculatedFinalTotal)" // Update text of the local 'totalNumLocal'
            
            run(.sequence([
                .wait(forDuration: 0.011),
                .run { runScore() }
            ]))
        }
        // END OF STEP 3 (runScore modification)

        // Start HP/score animation
        runHP()
    } // END OF showLevelCompleteLabels

    // STEP 4: Modify the drawAnimatedOvalAroundTotal function signature and logic
    // Change from: func drawAnimatedOvalAroundTotal()
    // To:          func drawAnimatedOvalAroundTotal(nodeToCircle: SKLabelNode, isNewHighScore: Bool)
    private func drawAnimatedOvalAroundTotal(nodeToCircle: SKLabelNode, isNewHighScore: Bool) {
        // let numberNode = totalNum // OLD: We now use nodeToCircle passed as parameter
        let ovalWidth: CGFloat = 92
        let ovalHeight: CGFloat = 60

        // let ovalPath = UIBezierPath(...) // Path is drawn dynamically in the action

        let shape = SKShapeNode()
        
        // ----> NEW: Set strokeColor based on isNewHighScore <----
        if isNewHighScore {
            shape.strokeColor = .green // New high score color!
            
            // Optional: Add a "New Record!" label
            let newRecordLabel = SKLabelNode(text: "New Record!")
            newRecordLabel.fontName = "Avenir-Black"; newRecordLabel.fontSize = 18 // Smaller font
            newRecordLabel.fontColor = .green
            // Position it relative to the circled node (e.g., below it)
            newRecordLabel.position = CGPoint(x: nodeToCircle.position.x - 23, y: nodeToCircle.position.y - (ovalHeight / 2) - 20) // Adjust Y as needed
            newRecordLabel.alpha = 0 // Start invisible
            newRecordLabel.zPosition = nodeToCircle.zPosition + 1 // Ensure it's visible above oval if needed
            cameraNode.addChild(newRecordLabel)
            
            // Animate the "New Record!" label
            newRecordLabel.run(SKAction.sequence([
                .wait(forDuration: 1.25), // Wait for oval to draw
                .fadeIn(withDuration: 0.3),
                .wait(forDuration: 2.0), // Display duration
                .fadeOut(withDuration: 0.3),
                .removeFromParent()
            ]))
        } else {
            shape.strokeColor = SKColor(white: 0.97, alpha: 1.0) // Default off-white
        }
        // ----> END NEW COLOR LOGIC <----
        
        shape.lineWidth = 8
        shape.lineCap = .round
        shape.glowWidth = 2
        shape.zPosition = nodeToCircle.zPosition - 1 // Behind the number
        
        shape.position = CGPoint(x: nodeToCircle.position.x - 26, y: nodeToCircle.position.y + 10)

        shape.path = nil // Path will be set by the custom action
        cameraNode.addChild(shape)

        let drawDuration: TimeInterval = 0.7
        let startAngle = -CGFloat.pi/2 // Start drawing from the top
        let endAngleFull = startAngle + CGFloat.pi * 2

        let drawAction = SKAction.customAction(withDuration: drawDuration) { node, elapsed in
            let percent = max(0, min(1, CGFloat(elapsed / CGFloat(drawDuration))))
            let currentEndAngle = startAngle + (endAngleFull - startAngle) * percent
            
            // Create the arc path around (0,0) because the SKShapeNode's position is already set
            var partialPath = UIBezierPath(
                arcCenter: .zero,
                radius: ovalWidth / 2, // Base radius on the wider dimension
                startAngle: startAngle,
                endAngle: currentEndAngle,
                clockwise: true
            )
            // Apply a transform to squash the circle into an oval
            var t = CGAffineTransform.identity
            t = t.scaledBy(x: 1, y: ovalHeight / ovalWidth) // Scale Y relative to X
            partialPath.apply(t)
            
            (node as! SKShapeNode).path = partialPath.cgPath
        }
        shape.run(drawAction)
    }
    // END OF STEP 4

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
        self.score = bonusScore // Update the class 'score' property here
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
        scoreLabel.text = "Score: \(self.score)" // Display the updated self.score
        hpLabel.text    = "HP: \(hp < 0 ? 0 : hp)" // Prevent negative HP display
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
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("Audio session error: \(error.localizedDescription)") }

        if let player = preloadedAudioPlayer {
            self.audioPlayer = player
            print("Using preloaded audio player for Level 1.")
        } else {
            print("Preloaded audio player not available for Level 1, loading now.")
            guard let url = Bundle.main.url(forResource: "orchid_sky", withExtension: "m4a") else {
                print("orchid_sky.m4a not found in bundle")
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
        pauseButton.position = CGPoint(x: size.width/2 - 60, y: size.height/2 - 60) // This position might need to be relative to cameraNode if UI moves with camera
        cameraNode.addChild(pauseButton) // Ensure UI elements are added to cameraNode if they should stay fixed relative to view

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
    // In Level1Scene.swift

    private func restartLevel() {
        // 1. Stop and reset the current level's background music.
        //    resetGameForPlayAgain() will handle starting it again from the beginning.
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0

        // 2. Call the comprehensive reset function.
        //    This function already handles setting isGameplayInactive = false,
        //    physicsWorld.speed = 1.0, resetting player, UI, etc.
        resetGameForPlayAgain()
    }
    private func goToMainMenu() {
        // Safely unwrap the view
        guard let view = self.view else {
            print("Error: Scene is not currently in a view.")
            return
        }

        // Now that view is unwrapped, you can safely access view.bounds.size
        let mainMenuScene = MainMenuScene(size: view.bounds.size)
        mainMenuScene.scaleMode = .aspectFill // SKSceneScaleMode.aspectFill is often inferred as .aspectFill
        
        // Present the scene
        view.presentScene(mainMenuScene, transition: .fade(withDuration: 0.5))
    }
    private func goToLevelsMenu() {
        guard let view = self.view else {
            print("Error: Scene is not currently in a view.")
            return
        }

        let levelsMenuScene = LevelsMenuScene(size: view.bounds.size) // Ensure LevelsMenuScene is defined and use view.bounds.size
        levelsMenuScene.scaleMode = .aspectFill
        
        view.presentScene(levelsMenuScene, transition: .fade(withDuration: 0.5)) // Make sure to present using the unwrapped view
    }
    
    private func makeGameOverButton(text: String, name: String) -> SKShapeNode {
        // Adjusted width multiplier and base height for smaller buttons
        let widthMultiplier: CGFloat = 0.22 // Reduced from 0.3
        let baseHeight: CGFloat = 50       // Reduced from 60
        let baseFontSize: CGFloat = 24     // Reduced from 30

        let width: CGFloat = (view?.bounds.width ?? size.width) * widthMultiplier * (1 / cameraNode.xScale)
        let height: CGFloat = baseHeight * (1 / cameraNode.yScale)
        let btn = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8 * (1 / cameraNode.xScale)) // Slightly smaller cornerRadius
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


    // In Level1Scene.swift

    // In Level1Scene.swift

    private func displayGameOverUI() {
        // Remove any existing overlay first
        if gameOverOverlayNode != nil {
            gameOverOverlayNode?.removeFromParent()
            // It's also good to nullify it if you're recreating it
            gameOverOverlayNode = nil
        }

        gameOverOverlayNode = SKNode()
        gameOverOverlayNode!.zPosition = 200 // Ensure it's on top of other game elements
        gameOverOverlayNode!.isPaused = false // Ensure UI actions can run
        gameOverOverlayNode!.alpha = 0.0      // << START FULLY TRANSPARENT FOR FADE-IN

        // Add the overlay to the camera so it's fixed on screen
        cameraNode.addChild(gameOverOverlayNode!)

        // --- Add all visual elements to gameOverOverlayNode ---

        // Background for the overlay (this will also fade in)
        let overlayBackground = SKShapeNode(rectOf: CGSize(width: size.width / cameraNode.xScale, height: size.height / cameraNode.yScale))
        overlayBackground.fillColor = SKColor.black // Solid black, will fade with parent
        overlayBackground.strokeColor = .clear
        overlayBackground.zPosition = -1 // Behind other elements within gameOverOverlayNode
        gameOverOverlayNode!.addChild(overlayBackground)

        // Calculate view dimensions in camera coordinates for positioning UI elements
        let viewWidthInCamera = (self.view?.bounds.width ?? self.size.width) / cameraNode.xScale
        let viewHeightInCamera = (self.view?.bounds.height ?? self.size.height) / cameraNode.yScale
        let uiGroupXPosition = (viewWidthInCamera * 0.25) - (20 / cameraNode.xScale)

        // Score Label
        let finalScore = self.score
        let scoreLabel = SKLabelNode(text: "Score: \(finalScore)")
        scoreLabel.fontName = "Avenir-Black"
        scoreLabel.fontSize = 34 * (1 / cameraNode.yScale)
        scoreLabel.fontColor = SKColor(red: 0.5, green: 1.0, blue: 0.7, alpha: 1.0)
        scoreLabel.position = CGPoint(x: uiGroupXPosition, y: viewHeightInCamera * 0.22)
        gameOverOverlayNode!.addChild(scoreLabel)

        // Buttons
        let playAgain = makeGameOverButton(text: "Play Again", name: "gameOverPlayAgain")
        playAgain.position = CGPoint(x: uiGroupXPosition, y: viewHeightInCamera * 0.05)
        gameOverOverlayNode!.addChild(playAgain)

        let menu = makeGameOverButton(text: "Main Menu", name: "gameOverMainMenu")
        let buttonVerticalSpacing = playAgain.frame.height * 0.2
        menu.position = CGPoint(x: uiGroupXPosition, y: playAgain.position.y - playAgain.frame.height - buttonVerticalSpacing)
        gameOverOverlayNode!.addChild(menu)
        
        // --- Setup Progress Bar & Marker (they will also fade in as children of gameOverOverlayNode) ---
        let levelLength: CGFloat = 5700
        let distanceTravelled = min(player.position.x, levelLength)

        let bar = SKSpriteNode(imageNamed: "start_finish")
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        guard let barTexture = bar.texture else {
            print("Error: Bar texture 'start_finish' is missing or nil.")
            // Potentially return or handle this error to avoid a crash
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
            // Potentially return or handle this error
            return
        }
        marker.setScale(0.03 * (1 / cameraNode.xScale))
        marker.position = CGPoint(x: lineStartX, y: bar.position.y)
        marker.isPaused = false // Ensure marker can animate
        gameOverOverlayNode!.addChild(marker) // Add marker so it fades in with the overlay
        
        // Prepare marker animation actions (these will be run after the overlay fades in)
        let pct = max(0, min(1, distanceTravelled / levelLength))
        let tgtX = lineStartX + progressW * pct
        let moveActionForMarker = SKAction.moveTo(x: tgtX, duration: 2)
        moveActionForMarker.timingMode = .easeOut
        let spinsForMarker: CGFloat = 6
        let spinAngleForMarker = -CGFloat.pi * 0.8 * spinsForMarker
        let spinActionForMarker = SKAction.rotate(byAngle: spinAngleForMarker, duration: 2)
        spinActionForMarker.timingMode = .easeOut

        // --- Fade-in the entire gameOverOverlayNode ---
        let fadeInAction = SKAction.fadeIn(withDuration: 0.45)
        gameOverOverlayNode!.run(fadeInAction) { [weak self] in
            guard let self = self else { return }
            
            self.isTransitioningToGameOver = false // Transition complete, UI is now active for touches
            print("Game Over UI fade-in complete. UI is now interactive.")

            // Now that the overlay (and marker) are visible, start the marker's animation
            // Check if progressW is valid before running animation to prevent issues
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

    private func endLevel() { // Called when HP <= 0
        // 1. Activate our custom gameplay pause flag
        isGameplayInactive = true

        // 2. Stop physics and audio
        physicsWorld.speed = 0
        audioPlayer?.pause()

        // 3. Ensure camera is not paused (it should be false by default if scene isn't paused)
        //    It's good practice to ensure UI-hosting nodes are explicitly not paused.
        self.cameraNode.isPaused = false
        //    self.gameOverOverlayNode and self.marker will also have isPaused = false set in displayGameOverUI

        // 4. Stop player's physical movement
        player.physicsBody?.velocity = .zero
        player.removeAllActions()
        duckPlayer.physicsBody?.velocity = .zero
        duckPlayer.removeAllActions()
        
        isTransitioningToGameOver = true

        // 5. Display the Game Over UI
        //    Since self.isPaused is NOT true, actions should run if this theory holds.
        displayGameOverUI()
    }
}
