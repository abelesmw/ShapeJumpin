import SpriteKit
import AVFoundation

class GameScene: SKScene, SKPhysicsContactDelegate {
    // MARK: - Config
    let originalRadius: CGFloat = 25
    lazy var adjustedRadius: CGFloat = originalRadius * 0.9
    lazy var hitboxRadius:   CGFloat = adjustedRadius * 0.56
    let groundHeight: CGFloat = 50
    let groundOffset: CGFloat = 4
    let duckOffset: CGFloat = 2
    var isApplyingDuckingOffset = false
    let firstJumpVelocity: CGFloat = 550
    let baseSecondJumpVelocity: CGFloat = 275
    
    var audioPlayer: AVAudioPlayer?
    var jumpSoundPlayer: AVAudioPlayer?

    // Pause
    var pauseButton: SKNode!
    var pauseMenu: SKNode?
    var isPauseMenuShowing = false
    
    // Spin
    var baseSpinSpeed: CGFloat = (2 * .pi) / 1.4 // Roughly one rotation in 1.4s

    // For second jump hold
    var secondJumpHoldActive = false
    var secondJumpHoldEnd: TimeInterval = 0.0

    // We'll track all touches for the hold logic
    var lastFrameTime: TimeInterval = 0

    // Invincibility
    var isInvincible = false
    var invincibleUntil: TimeInterval = 0.0

    // MARK: Game State
    var gameMode: GameMode = .solo
    var score: Int = 0
    var baseScore: Int = 0
    var bonusScore: Int = 0
    var hp: Int = 3
    var canFirstJump = true
    var canSecondJump = false
    var difficultyFactor: CGFloat = 1.0

    var startTime: TimeInterval = 0
    var lastSpawnTime: TimeInterval = 0
    var currentSpawnInterval: TimeInterval = 1.0
    let baseSpawnInterval: TimeInterval = 2.0
    var totalPausedTime: TimeInterval = 0
    var pauseStartTime: TimeInterval = 0

    var isDucking = false
    var activeTouches = Set<UITouch>()

    var lastObstacleSpawnTime: TimeInterval = 0

    // MARK: - Nodes
    var player = SKSpriteNode(imageNamed: "ball3.png")
    var duckPlayer = SKSpriteNode(imageNamed: "ball3.png")

    var floor = SKNode()

    var scoreLabel = SKLabelNode()
    var hpLabel    = SKLabelNode()

    // Ghost scoreboard
    var ghostScoreLabel = SKLabelNode()
    var scoreDiffLabel  = SKLabelNode()
    var ghostNode       = SKShapeNode(circleOfRadius: 25)
    var ghostScore: Int = 0

    var obstacles: [SKShapeNode] = []

    // Replays
    var playerPositions: [(time: TimeInterval, x: CGFloat, y: CGFloat, score: Int)] = []
    var jumpTimestamps: [TimeInterval] = []
    var bestRunPositions: [(time: TimeInterval, x: CGFloat, y: CGFloat, score: Int)] = []
    var bestRunDuration: TimeInterval = 0

    // MARK: - didMove
    override func didMove(to view: SKView) {
        backgroundColor = .black
        createStarBackground()

        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        physicsWorld.contactDelegate = self
        playBackgroundMusic()
        // loadJumpSound()

        setupFloor()
        setupPlayer()
        setupDuckPlayer()
        setupLabels()
        setupGhostNode()
       // loadGhostDataIfNeeded()

        lastFrameTime = 0
        lastObstacleSpawnTime = 0
        
        // Pause button with larger hitbox
        pauseButton = createPauseButton()
        pauseButton.position = CGPoint(x: size.width - 60, y: size.height - 60)
        addChild(pauseButton)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    // MARK: - Create Pause Button with Hitbox
    private func createPauseButton() -> SKNode {
        // Container node
        let container = SKNode()
        container.name = "pauseButton"
        
        // Invisible shape for larger hitbox
        let hitbox = SKShapeNode(circleOfRadius: 65)
        hitbox.fillColor = .clear
        hitbox.strokeColor = .clear
        hitbox.name = "pauseButton"
        container.addChild(hitbox)
        
        // Label for the pause symbol
        let label = SKLabelNode(text: "II")
        label.fontName = "Avenir-Black"
        label.fontSize = 45
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = "pauseLabel" // distinct name for label
        container.addChild(label)
        
        return container
    }
    
    // MARK: - Touches
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)

        for node in tappedNodes {
            guard let nodeName = node.name else { continue }
            
            // Check for pause button container or hitbox
            if nodeName == "pauseButton" {
                // We want to highlight the label, then show the menu
                // so let's find that label inside the container
                if let labelNode = node.childNode(withName: "pauseLabel") as? SKLabelNode {
                    // If tapped node was the container, we found label as child
                    highlightThenActPause(labelNode) {
                        self.showPauseMenu()
                    }
                }
                else if let parent = node.parent,
                        let labelNode = parent.childNode(withName: "pauseLabel") as? SKLabelNode {
                    // If tapped node was the shape, label is a sibling
                    highlightThenAct(labelNode) {
                        self.showPauseMenu()
                    }
                }
                else {
                    // Fallback if no label found
                    showPauseMenu()
                }
                return
            }
            
            // Check for pause menu interactions
            if nodeName == "resumeButton",
               let labelNode = node as? SKLabelNode {
                highlightThenAct(labelNode) {
                    self.hidePauseMenu()
                }
                return
            }
            else if nodeName == "mainMenuButton",
                    let labelNode = node as? SKLabelNode {
                highlightThenAct(labelNode) {
                    self.goToMainMenu()
                }
                return
            }
            else if nodeName == "restartButton",
                    let labelNode = node as? SKLabelNode {
                highlightThenAct(labelNode) {
                    self.restartGame()
                }
                return
            }
        }

        // Existing game input handling
        for t in touches {
            activeTouches.insert(t)
        }
        updateInputState(began: touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            activeTouches.remove(t)
        }
        updateInputState(began: nil)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            activeTouches.remove(t)
        }
        updateInputState(began: nil)
    }
    
    // Quickly highlight label to .cyan, wait 0.25s, revert, then run completion
    private func highlightThenAct(_ labelNode: SKLabelNode, completion: @escaping () -> Void) {
        let originalColor = labelNode.fontColor
        labelNode.fontColor = .cyan
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            labelNode.fontColor = originalColor
            completion()
        }
    }
    
    private func highlightThenActPause(_ labelNode: SKLabelNode, completion: @escaping () -> Void) {
        let originalColor = labelNode.fontColor
        labelNode.fontColor = .cyan
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            labelNode.fontColor = originalColor
            completion()
        }
    }

    // MARK: - Pause Logic
    func swipePause() {
        pauseStartTime = CACurrentMediaTime()
        isPaused = true
        physicsWorld.speed = 0
        view?.isPaused = true
    }

    func swipeReturn() {
        totalPausedTime += CACurrentMediaTime() - pauseStartTime
        isPaused = false
        physicsWorld.speed = 1
        view?.isPaused = false
    }

    func showPauseMenu() {
        isPaused = true
        isPauseMenuShowing = true
        pauseStartTime = CACurrentMediaTime()

        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = SKColor.black.withAlphaComponent(0.6)
        overlay.strokeColor = .clear
        overlay.zPosition = 10
        overlay.name = "pauseOverlay"
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // Menu container
        let menu = SKNode()
        menu.zPosition = 11
        menu.name = "pauseMenu"

        // Resume button
        let resumeButton = createButton(text: "Resume", name: "resumeButton", position: CGPoint(x: 0, y: 30))
        menu.addChild(resumeButton)
        
        // Restart button
        let restartButton = createButton(text: "Start Over", name: "restartButton", position: CGPoint(x: 0, y: -20))
        menu.addChild(restartButton)

        // Main Menu button
        let mainMenuButton = createButton(text: "Main Menu", name: "mainMenuButton", position: CGPoint(x: 0, y: -70))
        menu.addChild(mainMenuButton)

        menu.position = CGPoint(x: size.width / 2, y: size.height / 2)

        pauseMenu = menu
        addChild(overlay)
        addChild(menu)
        
        // Hide the pause "II" button while paused
        pauseButton.isHidden = true
    }

    func hidePauseMenu() {
        isPaused = false
        isPauseMenuShowing = false
        totalPausedTime += CACurrentMediaTime() - pauseStartTime
        pauseMenu?.removeFromParent()
        childNode(withName: "pauseOverlay")?.removeFromParent()
        
        // Unhide the pause "II" button
        pauseButton.isHidden = false
    }
    
    @objc func appDidEnterBackground() {
        if !isPauseMenuShowing {
            showPauseMenu()
        }
    }
    
    @objc func appDidBecomeActive() {
        if isPauseMenuShowing {
            isPaused = true
        } else {
            swipeReturn()
        }
    }
    
    @objc func appWillResignActive() {
        if !isPauseMenuShowing {
            showPauseMenu()
        }
    }

    func goToMainMenu() {
        let mainMenu = MainMenuScene(size: size)
        mainMenu.scaleMode = .aspectFill
        view?.presentScene(mainMenu, transition: .fade(withDuration: 0.5))
    }

    func restartGame() {
        let gameScene = GameScene(size: size)
        gameScene.scaleMode = .aspectFill
        view?.presentScene(gameScene, transition: .fade(withDuration: 0.5))
    }

    func createButton(text: String, name: String, position: CGPoint) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.fontName = "Avenir-Black"
        button.fontSize = 32
        button.fontColor = .white
        button.position = position
        button.name = name
        return button
    }

    // MARK: - Starry BG
    func createStarBackground() {
        let initialStarsCount = 50
        for _ in 0..<initialStarsCount {
            spawnStar(startOnScreen: true)
        }
        
        let spawnAction = SKAction.run { [weak self] in
            self?.spawnStar(startOnScreen: false)
        }
        let waitAction = SKAction.wait(forDuration: Double.random(in: 1.0...3.0))
        let spawnSequence = SKAction.sequence([spawnAction, waitAction])
        run(.repeatForever(spawnSequence))
    }

    private func spawnStar(startOnScreen: Bool) {
        let star = SKShapeNode(circleOfRadius: 1.4)
        star.fillColor = SKColor(white: 1.0, alpha: 0.3)
        star.strokeColor = .clear
        star.zPosition = -1
        
        if startOnScreen {
            star.position = CGPoint(
                x: CGFloat.random(in: 0..<size.width),
                y: CGFloat.random(in: 0..<size.height)
            )
        } else {
            star.position = CGPoint(
                x: size.width + star.frame.width,
                y: CGFloat.random(in: 0..<size.height)
            )
        }
        
        addChild(star)
        
        let moveDuration = 80.0
        let moveLeft = SKAction.moveBy(x: -(size.width + star.frame.width * 2),
                                       y: 0,
                                       duration: moveDuration)
        let remove = SKAction.removeFromParent()
        let sequence = SKAction.sequence([moveLeft, remove])
        star.run(sequence)
    }

    // MARK: - Floor
    func setupFloor() {
        let floorShape = SKShapeNode(rectOf: CGSize(width: size.width, height: groundHeight))
        floorShape.fillColor = .brown
        floorShape.position = CGPoint(x: size.width/2, y: groundHeight/2)
        addChild(floorShape)

        floor.position = floorShape.position
        floor.physicsBody = SKPhysicsBody(rectangleOf: floorShape.frame.size)
        floor.physicsBody?.isDynamic = false
        addChild(floor)
    }

    // MARK: - Player
    func setupPlayer() {
        let diam = Int(adjustedRadius*2)
        let tex  = makeAntialiasedBlueWhiteCircleTexture(diameter: diam)

        player.size = CGSize(width: adjustedRadius * 2, height: adjustedRadius * 2)
        player.position = CGPoint(x: size.width * 0.2,
                                  y: groundHeight + (adjustedRadius - groundOffset))
        player.name = "player"

        let body = SKPhysicsBody(circleOfRadius: hitboxRadius)
        body.isDynamic = true
        body.affectedByGravity = true
        body.allowsRotation = false
        body.categoryBitMask = 0x1 << 0
        body.collisionBitMask = 0
        body.contactTestBitMask = 0x1 << 1
        player.physicsBody = body
        addChild(player)
    }

    func setupDuckPlayer() {
        let halfRad = adjustedRadius*0.5
        let diam = Int(halfRad*2)
        // let tex  = makeAntialiasedBlueWhiteCircleTexture(diameter: diam)

        duckPlayer.size = CGSize(width: adjustedRadius, height: adjustedRadius)
        duckPlayer.position = CGPoint(x: size.width*0.2, y: groundHeight + halfRad + duckOffset)
        duckPlayer.name = "duckPlayer"

        let body = SKPhysicsBody(circleOfRadius: adjustedRadius / 2.4)
        body.isDynamic = true
        body.affectedByGravity = true
        body.allowsRotation = false
        body.categoryBitMask = 0x1 << 0
        body.collisionBitMask = 0
        body.contactTestBitMask = 0x1 << 1
        duckPlayer.physicsBody = body

        addChild(duckPlayer)
        duckPlayer.isHidden = true
    }

    // MARK: - Score & HP
    func setupLabels() {
        scoreLabel.fontSize = 31
        scoreLabel.fontName = "Avenir-Black"
        scoreLabel.position = CGPoint(x: size.width*0.1, y: size.height*0.85)
        scoreLabel.horizontalAlignmentMode = .left
        addChild(scoreLabel)

        hpLabel.fontSize = 31
        hpLabel.fontName = "Avenir-Black"
        hpLabel.position = CGPoint(x: size.width*0.36, y: size.height*0.85)
        hpLabel.horizontalAlignmentMode = .left
        addChild(hpLabel)

        ghostScoreLabel.fontSize = 20
        ghostScoreLabel.position = CGPoint(x: size.width*0.1, y: size.height*0.75)
        ghostScoreLabel.fontColor = .cyan
        ghostScoreLabel.horizontalAlignmentMode = .left
        ghostScoreLabel.alpha = 0.0
        addChild(ghostScoreLabel)

        scoreDiffLabel.fontSize = 20
        scoreDiffLabel.position = CGPoint(x: size.width*0.1, y: size.height*0.70)
        scoreDiffLabel.horizontalAlignmentMode = .left
        scoreDiffLabel.alpha = 0.0
        addChild(scoreDiffLabel)

        updateLabels()
    }

    func updateLabels() {
        scoreLabel.text = "Score: \(score)"
        hpLabel.text    = "HP: \(hp)"
    }

    // MARK: - Ghost
    func setupGhostNode() {
        ghostNode.fillColor = .green
        ghostNode.alpha = (gameMode == .ghost) ? 0.5 : 0.0
        ghostNode.position = CGPoint(x: size.width*0.2, y: groundHeight + adjustedRadius)
        ghostNode.physicsBody = SKPhysicsBody(circleOfRadius: hitboxRadius)
        ghostNode.physicsBody?.isDynamic = false
        addChild(ghostNode)
    }

    /*func loadGhostDataIfNeeded() {
        guard gameMode == .ghost else { return }
        bestRunPositions = RunDataManager.shared.bestRunPositions
        bestRunDuration  = RunDataManager.shared.bestRunDuration
        ghostScoreLabel.alpha = 1.0
        scoreDiffLabel.alpha  = 1.0
    }*/

    // MARK: - Update
    override func update(_ currentTime: TimeInterval) {
        if isPaused {
            return
        }
        
        let dt = (lastFrameTime > 0) ? (currentTime - lastFrameTime) : 0
        lastFrameTime = currentTime

        if startTime == 0 {
            startTime = currentTime
        }
        
        let adjustedCurrentTime = currentTime - totalPausedTime
        let elapsed = adjustedCurrentTime - startTime

        // Print difficulty factor periodically
        if Int(elapsed) % 5 == 0 {
            if elapsed.truncatingRemainder(dividingBy: 1) < dt {
                print("Time: \(Int(elapsed))s, Difficulty Factor: \(String(format: "%.2f", difficultyFactor))")
            }
        }

        // Ramp difficulty up to ~90s
        if elapsed < 90 {
            if elapsed < 10 {
                difficultyFactor = 1.0 + CGFloat(elapsed * 0.02)
            } else if elapsed <= 20 {
                difficultyFactor = 1.0 + CGFloat(10 * 0.0175 + (elapsed - 10) * 0.0125)
            } else if elapsed <= 30 {
                difficultyFactor = 1.0 + CGFloat(10 * 0.0175 + 10 * 0.0125 + (elapsed - 20) * 0.0075)
            } else if elapsed <= 40 {
                difficultyFactor = 1.4 + CGFloat((elapsed - 30) * 0.0025)
            } else if elapsed <= 50 {
                difficultyFactor = 1.5 + CGFloat((elapsed - 40) * 0.0025)
            } else if elapsed <= 60 {
                difficultyFactor = 1.6 + CGFloat((elapsed - 50) * 0.0025)
            } else if elapsed <= 70 {
                difficultyFactor = 1.7 + CGFloat((elapsed - 50) * 0.0025)
            } else if elapsed < 80 {
                difficultyFactor = 1.8 + CGFloat((elapsed - 50) * 0.0025)
            } else {
                difficultyFactor = 1.9 + CGFloat((elapsed - 50) * 0.0025)
            }
        } else {
            difficultyFactor = 2.0
        }

        // Invincible check
        if isInvincible && currentTime >= invincibleUntil {
            isInvincible = false
            player.color = .white
            player.colorBlendFactor = 0
            duckPlayer.color = .white
            duckPlayer.colorBlendFactor = 0
        }

        // Pin horizontally
        if isDucking {
            duckPlayer.position.x = size.width * 0.2
        } else {
            player.position.x = size.width * 0.2
        }

        updateGhost(elapsed)

        // Obstacle spawn timing
        if elapsed - lastSpawnTime > currentSpawnInterval {
            lastSpawnTime = elapsed
            spawnObstacle(elapsed)
            let base = max(0.8, baseSpawnInterval - Double(elapsed/30.0))
            let randDelta = Double.random(in: -0.3...0.3)
            currentSpawnInterval = max(0.45, base + randDelta)
        }

        // Score
        baseScore = Int(elapsed)
        score = baseScore + bonusScore
        updateLabels()
        
        // Simple spin bump after 35s
        let spinMultiplier: CGFloat = (elapsed >= 35.0) ? 1.4 : 1.0
        let angleThisFrame = baseSpinSpeed * spinMultiplier * CGFloat(dt)
        player.zRotation -= angleThisFrame
        duckPlayer.zRotation -= angleThisFrame

        // Save player motion
        let activeNode = isDucking ? duckPlayer : player
        playerPositions.append((elapsed, activeNode.position.x, activeNode.position.y, score))

        // Second jump hold
        applySecondJumpHold(dt: dt, currentTime: currentTime, node: activeNode)

        // Check margins for obstacle scoring
        checkObstacleMargins()

        // Ghost scoreboard
        updateGhostScoreboard(elapsed)
    }

    // MARK: Second Jump Hold
    func applySecondJumpHold(dt: TimeInterval, currentTime: TimeInterval, node: SKSpriteNode) {
        if secondJumpHoldActive {
            if activeTouches.isEmpty || (currentTime >= secondJumpHoldEnd) {
                secondJumpHoldActive = false
                return
            }
            if let body = node.physicsBody {
                body.velocity.dy += CGFloat(465 * dt)
            }
        }
    }

    func updateGhost(_ elapsed: TimeInterval) {
        guard gameMode == .ghost, !bestRunPositions.isEmpty else { return }
        let finalScore = interpolateGhostPositions(elapsed)
        ghostScore = finalScore
    }

    func interpolateGhostPositions(_ elapsed: TimeInterval) -> Int {
        if elapsed > bestRunDuration {
            ghostNode.removeFromParent()
            return 0
        }
        var prev = bestRunPositions.first!
        for i in 1..<bestRunPositions.count {
            let curr = bestRunPositions[i]
            if curr.time >= elapsed {
                let ratio = CGFloat((elapsed - prev.time) / (curr.time - prev.time))
                let newX = prev.x + (curr.x - prev.x) * ratio
                let newY = prev.y + (curr.y - prev.y) * ratio
                ghostNode.position = CGPoint(x: newX, y: newY)
                let newScore = CGFloat(prev.score) + (CGFloat(curr.score)-CGFloat(prev.score)) * ratio
                return Int(newScore)
            }
            prev = curr
        }
        ghostNode.position = CGPoint(x: bestRunPositions.last!.x, y: bestRunPositions.last!.y)
        return bestRunPositions.last!.score
    }

    func updateGhostScoreboard(_ elapsed: TimeInterval) {
        guard gameMode == .ghost else { return }
        ghostScoreLabel.text = "Ghost: \(ghostScore)"
        let diff = score - ghostScore
        if diff >= 0 {
            scoreDiffLabel.fontColor = .green
            scoreDiffLabel.text = "Lead: +\(diff)"
        } else {
            scoreDiffLabel.fontColor = .red
            scoreDiffLabel.text = "Lead: \(diff)"
        }
    }

    // MARK: - Input State
    func updateInputState(began: Set<UITouch>?) {
        if activeTouches.count >= 2 {
            enterDuckMode()
        } else {
            exitDuckMode()
        }

        if activeTouches.count == 1, let began = began, began.count == 1 {
            if !isDucking {
                doSingleJump()
            }
        }
    }
    
    func loadJumpSound() {
        if let soundURL = Bundle.main.url(forResource: "soccer-ball-kick-37625", withExtension: "mp3") {
            do {
                jumpSoundPlayer = try AVAudioPlayer(contentsOf: soundURL)
                jumpSoundPlayer?.volume = 0.1
                jumpSoundPlayer?.prepareToPlay()
            } catch {
                print("Error loading sound: \(error.localizedDescription)")
            }
        }
    }

    func doSingleJump() {
        let now = CACurrentMediaTime() - startTime
        let activeNode = isDucking ? duckPlayer : player

        if canFirstJump {
            activeNode.physicsBody?.velocity = CGVector(dx: 0, dy: firstJumpVelocity)
            canFirstJump = false
            canSecondJump = true
            jumpTimestamps.append(now)
        } else if canSecondJump {
            activeNode.physicsBody?.velocity = CGVector(dx: 0, dy: baseSecondJumpVelocity)
            canSecondJump = false
            jumpTimestamps.append(now)
            secondJumpHoldActive = true
            secondJumpHoldEnd = CACurrentMediaTime() + 0.8
        }
    }

    // MARK: - Duck
    func enterDuckMode() {
        guard !isDucking else { return }

        let groundY = groundHeight + player.size.height / 2
        let threshold: CGFloat = 35
        if abs(player.position.y - groundY) > threshold {
            return
        }

        isDucking = true
        player.isHidden = true
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.velocity = .zero

        let halfRad = duckPlayer.size.width * 0.5
        duckPlayer.position = CGPoint(x: size.width * 0.2, y: groundHeight + halfRad)
        duckPlayer.physicsBody?.affectedByGravity = true
        duckPlayer.physicsBody?.velocity = .zero
        duckPlayer.isHidden = false

        isApplyingDuckingOffset = true
        canFirstJump = true
        canSecondJump = false
    }

    func exitDuckMode() {
        guard isDucking else { return }
        isDucking = false

        duckPlayer.isHidden = true
        duckPlayer.physicsBody?.affectedByGravity = false
        duckPlayer.physicsBody?.velocity = .zero

        player.position = CGPoint(x: size.width*0.2, y: groundHeight + (adjustedRadius - groundOffset))
        player.physicsBody?.affectedByGravity = true
        player.physicsBody?.velocity = .zero
        player.isHidden = false

        isApplyingDuckingOffset = false
        canFirstJump = true
        canSecondJump = false
    }

    // MARK: - Spawning Obstacles
    func spawnObstacle(_ elapsed: TimeInterval) {
        let effectiveElapsed = min(elapsed, 40)
        let lockedFactor = 1.0 + CGFloat((effectiveElapsed/5.0)*0.01)
        let speed = 200.0 * Double(lockedFactor)
        let minDist = 4 * adjustedRadius
        if (elapsed - lastObstacleSpawnTime) < (minDist / CGFloat(speed)) {
            return
        }
        lastObstacleSpawnTime = elapsed

        let radius = CGFloat.random(in: 20...40) * lockedFactor
        let halfScreen = size.height * 0.5
        let groundMin = groundHeight + radius
        let maxPossible = min(halfScreen, size.height - radius)

        if elapsed < 10 {
            createObstacle(radius: radius, yPos: groundMin, speed: speed)
            return
        }

        let highMinimum = groundMin + 20
        let midMax = min(maxPossible, size.height * 0.6)
        let rand = Double.random(in: 0...1)
        let groundProb = 0.5
        let midProb = 0.3

        if rand < groundProb {
            createObstacle(radius: radius, yPos: groundMin, speed: speed)
        } else if rand < groundProb + midProb {
            var minY = highMinimum
            var maxY = midMax
            if minY > maxY { minY = groundMin }
            if minY > maxY {
                createObstacle(radius: radius, yPos: groundMin, speed: speed)
                return
            }
            let midY = CGFloat.random(in: minY...maxY)
            createObstacle(radius: radius, yPos: midY, speed: speed)
        } else {
            let minHigh = midMax + 20
            var lowY = minHigh
            var highY = maxPossible
            if lowY > highY {
                createObstacle(radius: radius, yPos: groundMin, speed: speed)
                return
            }
            let chosenY = CGFloat.random(in: lowY...highY)
            createObstacle(radius: radius, yPos: chosenY, speed: speed)
        }
    }

    func createObstacle(radius: CGFloat, yPos: CGFloat, speed: Double) {
        let rainbowColors: [SKColor] = [
            .red, .orange, .yellow, .green, .blue,
            SKColor(red: 75.0/255.0, green: 0, blue: 130.0/255.0, alpha: 1),
            SKColor(red: 139.0/255.0, green: 0, blue: 255.0/255.0, alpha: 1)
        ]
        let randColor = rainbowColors.randomElement()!

        let shapeSides = [3, 4, 6, 8]
        let sides = shapeSides.randomElement()!
        let path = CGMutablePath()
        let step = (2 * CGFloat.pi) / CGFloat(sides)

        for i in 0..<sides {
            let angle = step * CGFloat(i)
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        let obstacle = SKShapeNode(path: path)
        obstacle.fillColor = randColor
        obstacle.strokeColor = .white
        obstacle.lineWidth = 2.0
        obstacle.position = CGPoint(x: size.width + radius, y: yPos)
        obstacle.name = "obstacle"

        let pbody = SKPhysicsBody(polygonFrom: path)
        pbody.isDynamic = false
        pbody.categoryBitMask = 0x1 << 1
        pbody.collisionBitMask = 0
        obstacle.physicsBody = pbody
        
        obstacle.userData = [
            "scored": false,
            "collided": false
        ]

        addChild(obstacle)
        obstacles.append(obstacle)

        let moveTime = size.width / CGFloat(speed)
        let moveAction = SKAction.moveBy(x: -size.width * 2,
                                         y: 0,
                                         duration: moveTime * 2)
        let removeAction = SKAction.run { [weak self, weak obstacle] in
            if let obs = obstacle, let idx = self?.obstacles.firstIndex(of: obs) {
                self?.obstacles.remove(at: idx)
            }
            obstacle?.removeFromParent()
        }
        obstacle.run(.sequence([moveAction, removeAction]))
    }
    
    private func playBackgroundMusic() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error setting up audio session: \(error.localizedDescription)")
            return
        }

        if let filePath = Bundle.main.path(forResource: "shapes-in-space", ofType: "m4a") {
            let fileURL = URL(fileURLWithPath: filePath)
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                audioPlayer?.volume = SoundSettings.isMuted ? 0 : 0.5
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.play()
            } catch {
                print("Error playing audio: \(error.localizedDescription)")
            }
        } else {
            print("Audio file not found.")
        }
    }

    // MARK: - Margin & Collisions
    func checkObstacleMargins() {
        let currentNode = isDucking ? duckPlayer : player
        for obs in obstacles {
            if (obs.userData?["scored"] as? Bool == true) ||
               (obs.userData?["collided"] as? Bool == true) {
                continue
            }
            if obs.position.x + obs.frame.width/2 <
               currentNode.position.x - currentNode.size.width/2 {
                
                obs.userData?["scored"] = true
                let dx = currentNode.position.x - obs.position.x
                let dy = currentNode.position.y - obs.position.y
                let dist = sqrt(dx*dx + dy*dy)
                let activeRadius = currentNode.size.width / 2
                let margin = dist - (activeRadius + obs.frame.width / 2)
                awardMarginPoints(margin, obstacle: obs)
            }
        }
    }

    func awardMarginPoints(_ margin: CGFloat, obstacle: SKShapeNode) {
        let bonus: Int
        if margin < 10 {
            bonus = 1
        } else if margin < 25 {
            bonus = 2
        } else if margin < 45 {
            bonus = 3
        } else if margin < 60 {
            bonus = 4
        } else {
            bonus = 5
        }

        bonusScore += bonus
        spawnMarginLabel("+\(bonus)", at: obstacle.position, bonus: bonus)
    }

    func spawnMarginLabel(_ text: String, at pos: CGPoint, bonus: Int) {
        let lbl = SKLabelNode(text: text)
        switch bonus {
        case 2, 1:
            lbl.fontColor = .yellow
        default:
            lbl.fontColor = .green
        }
        lbl.fontName = "Avenir-Black"
        lbl.fontSize = 32
        lbl.position = pos
        lbl.alpha = 0
        addChild(lbl)

        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let moveUp = SKAction.moveBy(x: 0, y: 40, duration: 1.1)
        let fadeOut = SKAction.fadeOut(withDuration: 1.1)
        let remove = SKAction.removeFromParent()
        lbl.run(.sequence([fadeIn, .group([moveUp, fadeOut]), remove]))
    }

    func didBegin(_ contact: SKPhysicsContact) {
        if isInvincible { return }

        let currentNode = isDucking ? duckPlayer : player
        guard let nodeA = contact.bodyA.node,
              let nodeB = contact.bodyB.node else { return }

        let names = [nodeA.name, nodeB.name]
        if names.contains("obstacle"),
           (nodeA == currentNode || nodeB == currentNode) {
            
            let obstacle = (nodeA.name == "obstacle") ? nodeA : nodeB
            obstacle.userData?["collided"] = true

            hp -= 1
            updateLabels()

            isInvincible = true
            invincibleUntil = CACurrentMediaTime() + 0.9
            currentNode.colorBlendFactor = 0.8
            currentNode.color = .red

            spawnDamageLabel("-1", at: currentNode.position)
            if hp <= 0 {
                endGame()
            }
        }
    }

    func spawnDamageLabel(_ text: String, at pos: CGPoint) {
        let lbl = SKLabelNode(text: text)
        lbl.fontColor = .red
        lbl.fontName  = "Avenir-Black"
        lbl.fontSize  = 32
        lbl.position  = pos
        lbl.alpha = 0
        addChild(lbl)

        let fadeIn  = SKAction.fadeIn(withDuration: 0.2)
        let moveUp  = SKAction.moveBy(x: 0, y: 40, duration: 1.1)
        let fadeOut = SKAction.fadeOut(withDuration: 1.1)
        let remove  = SKAction.removeFromParent()
        lbl.run(.sequence([fadeIn, .group([moveUp, fadeOut]), remove]))
    }

    override func didSimulatePhysics() {
        // Force the player/duck onto the floor if they're below it
        if !isApplyingDuckingOffset {
            let currentNode = isDucking ? duckPlayer : player
            let groundY = groundHeight + currentNode.size.height/2 - groundOffset
            if currentNode.position.y < groundY {
                currentNode.position.y = groundY
                currentNode.physicsBody?.velocity.dy = 0
                canFirstJump = true
                canSecondJump = false
            }
        } else {
            let currentNode = isDucking ? duckPlayer : player
            let groundY = groundHeight + currentNode.size.height/2 - groundOffset + duckOffset
            if currentNode.position.y < groundY {
                currentNode.position.y = groundY
                currentNode.physicsBody?.velocity.dy = 0
                canFirstJump = true
                canSecondJump = false
            }
        }
    }

    func endGame() {
        let dur = CACurrentMediaTime() - startTime
        RunDataManager.shared.saveBestRun(
            positions: playerPositions,
            duration: dur,
            score: score
        )
        
        LeaderboardManager.shared.submitScore(score)
        let gm = GameOverScene(size: size)
        gm.finalScore = score
        view?.presentScene(gm, transition: .fade(withDuration: 0.7))
    }

    // MARK: - Texture Helper
    func makeAntialiasedBlueWhiteCircleTexture(diameter: Int) -> SKTexture {
        let width = diameter, height = diameter
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: width * 4,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return SKTexture()
        }
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let circleRect = CGRect(x: 0, y: 0, width: width, height: height)
        ctx.addEllipse(in: circleRect)
        ctx.clip()

        let center = CGPoint(x: circleRect.midX, y: circleRect.midY)
        let startColor = CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        let endColor   = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

        guard let grad = CGGradient(colorsSpace: colorSpace,
                                    colors: [startColor, endColor] as CFArray,
                                    locations: [0.0, 1.0])
        else {
            return SKTexture()
        }

        ctx.drawRadialGradient(
            grad,
            startCenter: center, startRadius: 0,
            endCenter: center, endRadius: CGFloat(width)/2,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )

        guard let cgImage = ctx.makeImage() else {
            return SKTexture()
        }
        let tex = SKTexture(cgImage: cgImage)
        tex.filteringMode = .linear
        return tex
    }
}
