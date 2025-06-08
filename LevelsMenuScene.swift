import SpriteKit
import AVFoundation

// Assuming this enum is used elsewhere or for future context
enum PresentingSceneType {
    case mainMenu
    case levelMenu
}

class LevelsMenuScene: SKScene {

    private var preloadedLevel1Scene: Level1Scene?
    private var preloadedLevel1Audio: AVAudioPlayer?
    private var preloadedLevel2Scene: Level2Scene? // Added for Level 2
    private var preloadedLevel2Audio: AVAudioPlayer? // Added for Level 2

    private var loadingLabel: SKLabelNode?

    override func didMove(to view: SKView) {
        
        print("[LMS] didMove started.")
        
     //FUNCTION FOR DELETING HIGH SCORE
        /*  let scoreKey = "highScore_level2" // This must match the key used by LevelDataManager
            UserDefaults.standard.removeObject(forKey: scoreKey)
            print("Score for 'level2' was reset. Remove the function call now.")*/

        // General Background elements
        let grayBackground = SKSpriteNode(imageNamed: "grayBack.png")
        grayBackground.position = CGPoint(x: size.width / 2, y: size.height / 2)
        grayBackground.zPosition = -4
        grayBackground.xScale = 0.5
        grayBackground.yScale = 0.4
        addChild(grayBackground)

        // Decorative stitch elements (these are general decor, not specific to one level entry)
        /*let stitch_only = SKSpriteNode(imageNamed: "stitch_only.png")
        stitch_only.position = CGPoint(x: (size.width / 2), y: (size.height / 2) - 25)
        stitch_only.zPosition = 0 // Adjust if needed relative to new entry nodes
        stitch_only.xScale = 0.205
        stitch_only.yScale = 0.24
        stitch_only.alpha = 0.5
        let degreesToRotate: CGFloat = 0.2
        let radiansToRotate = degreesToRotate * (CGFloat.pi / 180.0)
        stitch_only.zRotation += radiansToRotate
        addChild(stitch_only)*/

        let stitch_only2 = SKSpriteNode(imageNamed: "stitch_only.png")
        stitch_only2.position = CGPoint(x: (size.width / 2) + 180, y: (size.height / 2) - 25)
        stitch_only2.zPosition = 0 // Adjust if needed
        stitch_only2.xScale = 0.205
        stitch_only2.yScale = 0.24
        stitch_only2.alpha = 0.5
        addChild(stitch_only2)
        
        // "Coming Soon" images for other potential level slots
        let coming_soon = SKSpriteNode(imageNamed: "coming_soon.png")
        coming_soon.position = CGPoint(x: (size.width / 2), y: (size.height / 2) - 25) // Example position
        coming_soon.zPosition = 0 // Ensure zPosition is logical with level entries
        coming_soon.xScale = 0.09
        coming_soon.yScale = 0.09
        coming_soon.alpha = 0.6
        // addChild(coming_soon) // Only add if you want it visible at this specific central spot initially

        let coming_soon2 = SKSpriteNode(imageNamed: "coming_soon.png")
        coming_soon2.position = CGPoint(x: (size.width / 2) + 180, y: (size.height / 2) - 25) // Example position
        coming_soon2.zPosition = 0
        coming_soon2.xScale = 0.09
        coming_soon2.yScale = 0.09
        coming_soon2.alpha = 0.6
        addChild(coming_soon2) // Only add if you want it visible

        // World 1 Title elements
        let world1 = SKSpriteNode(imageNamed: "world_new.png")
        world1.position = CGPoint(x: (size.width / 2) - 30, y: (size.height / 2) + 120)
        world1.zPosition = -2 // Behind level entries if they overlap
        world1.xScale = 0.125
        world1.yScale = 0.0955
        addChild(world1)

        let new1 = SKSpriteNode(imageNamed: "1_new.png")
        new1.position = CGPoint(x: (size.width / 2) + 70, y: (size.height / 2) + 121)
        new1.zPosition = -2
        new1.xScale = 0.057
        new1.yScale = 0.048
        addChild(new1)

        // Main dark map background
        let darkMap = SKSpriteNode(imageNamed: "darkGrey_map.png")
        darkMap.position = CGPoint(x: (size.width / 2), y: (size.height / 2))
        darkMap.zPosition = -5 // Deepest background
        darkMap.xScale = 0.55
        darkMap.yScale = 0.5
        addChild(darkMap)
        
        // Note: The original `blackFelt` (dark_grey_felt.png) that was here is now removed,
        // as each level entry will manage its own backdrop.

        setupBaseUI()
        addLevelEntries() // This will now create entries with their own backdrops

        // Preload assets for Level 1
        preloadAssetsForLevel(levelID: "level1", sceneFileName: "Level1Scene", audioFileName: "orchid_sky", audioFileExtension: "m4a")
        // Preload assets for Level 2 (adjust audio file if needed)
        preloadAssetsForLevel(levelID: "level2", sceneFileName: "Level2Scene", audioFileName: "orange_dream", audioFileExtension: "m4a") // =

        print("[LMS] didMove finished.")
    }

    func setupBaseUI() {
        let backButton = SKLabelNode(text: "Back")
        backButton.fontName = "Avenir-Black"; backButton.fontSize = 24; backButton.fontColor = .white
        // Position back button appropriately (e.g., top-left or bottom-left)
        backButton.position = CGPoint(x: 70, y: size.height - 50) // Adjusted for typical back button placement
        backButton.name = "backToMainMenuButton"
        addChild(backButton)
    }

    func addLevelEntries() {
        // --- Level 1 Entry (positioned to the left) ---
        let level1EntryX = (size.width / 2) - 180 // X-center for Level 1's block
        // Y-center for Level 1's block, where its felt backdrop will be centered
        let level1EntryY = (size.height / 2) - 25

        // Calculate the Y offset for the button relative to level1EntryY (felt's center Y)
        // This maintains the original visual spacing between the button and where the felt *was*.
        // Original button absolute Y was: ((size.height * 0.75) - 40) - 50
        let originalButtonAbsoluteYForLevel1 = ((size.height * 0.75) - 40) - 50
        let level1ButtonYOffset = originalButtonAbsoluteYForLevel1 - level1EntryY

        addLevelEntry(levelID: "level1",
                      levelName: "Level 1", // Used if image button fails or for text-only button
                      entryX: level1EntryX,
                      entryY: level1EntryY,
                      sceneFileName: "Level1Scene",
                      isLocked: false,
                      useImageButton: true,
                      imageName: "cartoon_1_btn",
                      backdropImageName: "dark_grey_felt.png", // Level 1's felt backdrop
                      backdropScaleX: 0.215, // Original scale for the felt
                      backdropScaleY: 0.17,  // Original scale for the felt
                      buttonYOffsetFromEntryCenter: level1ButtonYOffset)

        // --- Level 2 Entry (positioned "dead center") ---
        let level2EntryX = size.width / 2 // X-center for Level 2's block (scene center)
        let level2EntryY = (size.height / 2) - 25// Y-center for Level 2's block (scene center)

        // Use the same relative Y offset for the button to maintain visual consistency with Level 1's layout
        let level2ButtonYOffset = level1ButtonYOffset - 2
        // Alternatively, if you want Level 2's button differently placed relative to its felt:
        // let level2ButtonYOffset = CGFloat(-50) // Example: 50 points below the felt's center

        addLevelEntry(levelID: "level2",
                      levelName: "Level 2",
                      entryX: level2EntryX,
                      entryY: level2EntryY,
                      sceneFileName: "Level2Scene",
                      isLocked: false, // Assuming Level 2 is unlocked
                      useImageButton: true,
                      imageName: "cartoon_btn_2_2.png", // New button image for Level 2
                      backdropImageName: "dark_grey_felt.png", // Assuming same felt style
                      backdropScaleX: 0.215, // Assuming same felt scale
                      backdropScaleY: 0.17,  // Assuming same felt scale
                      buttonYOffsetFromEntryCenter: level2ButtonYOffset)
    }

    func addLevelEntry(levelID: String, levelName: String,
                       entryX: CGFloat, entryY: CGFloat,
                       sceneFileName: String,
                       isLocked: Bool = false,
                       useImageButton: Bool = false, imageName: String? = nil,
                       backdropImageName: String? = nil,
                       backdropScaleX: CGFloat = 1.0, backdropScaleY: CGFloat = 1.0,
                       buttonYOffsetFromEntryCenter: CGFloat) {

        let entryNode = SKNode()
        entryNode.position = CGPoint(x: entryX, y: entryY)
        entryNode.zPosition = 1 // Ensure entry nodes are above general background but can be ordered among themselves
        addChild(entryNode)

        if let bdn = backdropImageName {
            let backdrop = SKSpriteNode(imageNamed: bdn)
            backdrop.position = .zero
            backdrop.xScale = backdropScaleX
            backdrop.yScale = backdropScaleY
            backdrop.zPosition = -1 // Behind other elements in this entryNode
            entryNode.addChild(backdrop)
        }

        let buttonNodeName = isLocked ? "play_\(levelID)_locked" : "play_\(levelID)"
        var buttonVisualNode: SKNode
        var buttonVisualHeight: CGFloat
        let buttonCenterXInEntry: CGFloat = 0 // Button is X-centered in entryNode

        if useImageButton, let imgName = imageName, let uiImageForTexture = UIImage(named: imgName) {
            let buttonTexture = SKTexture(image: uiImageForTexture)
            let imageButton = SKSpriteNode(texture: buttonTexture)
            let aspectRatio = buttonTexture.size().height / buttonTexture.size().width
            let desiredUnscaledWidth: CGFloat = size.width * 0.235
            imageButton.size = CGSize(width: desiredUnscaledWidth, height: desiredUnscaledWidth * aspectRatio)
            if levelID == "level2" {
                imageButton.setScale(0.69) // A smaller scale for level 2
                buttonVisualHeight = imageButton.size.height * 0.6
            } else {
                imageButton.setScale(0.7) // The default scale for all other buttons
                buttonVisualHeight = imageButton.size.height * 0.7
            }

            imageButton.position = CGPoint(x: buttonCenterXInEntry, y: buttonYOffsetFromEntryCenter)
            buttonVisualNode = imageButton
            buttonVisualHeight = imageButton.size.height * imageButton.yScale // imageButton.yScale is 0.7 due to setScale

            imageButton.name = buttonNodeName
            imageButton.userData = NSMutableDictionary()
            imageButton.userData?.setValue(sceneFileName, forKey: "sceneFileName")
            imageButton.userData?.setValue(levelID, forKey: "levelID")
        } else {
            if useImageButton && imageName != nil {
                print("[LMS] Warning: Image button requested for \(levelID) but image '\(imageName!)' might be missing.")
            }
            let playLevelLabel = SKLabelNode(text: levelName)
            playLevelLabel.fontName = "Avenir-Black"; playLevelLabel.fontSize = 30
            playLevelLabel.fontColor = isLocked ? .darkGray : .white
            playLevelLabel.horizontalAlignmentMode = .center
            playLevelLabel.verticalAlignmentMode = .center

            playLevelLabel.position = CGPoint(x: buttonCenterXInEntry, y: buttonYOffsetFromEntryCenter)
            buttonVisualNode = playLevelLabel
            buttonVisualHeight = playLevelLabel.frame.size.height

            playLevelLabel.name = buttonNodeName
            playLevelLabel.userData = NSMutableDictionary()
            playLevelLabel.userData?.setValue(sceneFileName, forKey: "sceneFileName")
            playLevelLabel.userData?.setValue(levelID, forKey: "levelID")
        }
        entryNode.addChild(buttonVisualNode)

        if !isLocked {
            let verticalPadding: CGFloat = 12
            let interLabelPadding: CGFloat = 8
            let buttonBottomYInEntry = buttonVisualNode.position.y - (buttonVisualHeight / 2)

            let localHighScore = LevelDataManager.shared.getHighScore(forLevel: levelID)
            let highScoreText = "Your Best: \(localHighScore != nil ? String(localHighScore!) : "---")"
            let highScoreLabel = SKLabelNode(text: highScoreText)
            highScoreLabel.fontName = "Avenir-Light"; highScoreLabel.fontSize = 16
            highScoreLabel.fontColor = SKColor.white
            highScoreLabel.horizontalAlignmentMode = .center
            highScoreLabel.verticalAlignmentMode = .center

            let highScoreLabelHeight = highScoreLabel.frame.size.height
            highScoreLabel.position = CGPoint(
                x: buttonCenterXInEntry,
                y: buttonBottomYInEntry - verticalPadding - (highScoreLabelHeight / 2)
            )
            entryNode.addChild(highScoreLabel)

            let leaderboardButton = SKLabelNode(text: "Leaderboard")
            leaderboardButton.fontName = "Avenir-Black"; leaderboardButton.fontSize = 20
            leaderboardButton.fontColor = .white
            leaderboardButton.horizontalAlignmentMode = .center
            leaderboardButton.verticalAlignmentMode = .center

            let highScoreLabelBottomYInEntry = highScoreLabel.position.y - (highScoreLabelHeight / 2)
            let leaderboardButtonHeight = leaderboardButton.frame.size.height
            leaderboardButton.position = CGPoint(
                x: buttonCenterXInEntry,
                y: highScoreLabelBottomYInEntry - interLabelPadding - (leaderboardButtonHeight / 2)
            )
            leaderboardButton.name = "leaderboard_\(levelID)"
            leaderboardButton.userData = NSMutableDictionary()
            leaderboardButton.userData?.setValue(levelID, forKey: "levelID")
            entryNode.addChild(leaderboardButton)
        }
    }

    func showLoadingLabel() {
        print("[LMS] showLoadingLabel() called.")
        loadingLabel?.removeFromParent() // Remove old one if any

        loadingLabel = SKLabelNode(text: "Loading...")
        loadingLabel!.fontName = "Avenir-Black"
        loadingLabel!.fontSize = 30
        loadingLabel!.fontColor = .white
        // Position loading label appropriately, e.g., screen center or near the touched button
        // For simplicity, let's keep its original positioning logic relative to (size.width/2) - 180,
        // but you might want to make this dynamic based on which level is loading.
        // A more robust solution would be to position it at scene center:
        loadingLabel!.position = CGPoint(x: (size.width / 2) - 180, y: (size.height / 2) + 110) // Centered and slightly up
        loadingLabel!.zPosition = 1000 // Ensure it's on top
        addChild(loadingLabel!)
        print("[LMS] Loading label added to scene.")
    }

    func hideLoadingLabel() {
        print("[LMS] hideLoadingLabel() called.")
        loadingLabel?.removeFromParent()
        loadingLabel = nil
        // No need to print here if already printed in showLoadingLabel for adding
    }

    func preloadAssetsForLevel(levelID: String, sceneFileName: String, audioFileName: String?, audioFileExtension: String?) {
        print("[LMS] preloadAssetsForLevel for \(levelID) starting on thread: \(Thread.current).")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            print("[LMS BGPreload] Preloading \(levelID) assets on background thread: \(Thread.current).")

            // Scene Preloading
            if levelID == "level1" && self.preloadedLevel1Scene == nil {
                if let scene = Level1Scene(fileNamed: sceneFileName) {
                    scene.scaleMode = .aspectFill
                    self.preloadedLevel1Scene = scene
                    print("[LMS BGPreload] Level 1 SKScene object preloaded.")
                } else {
                    print("[LMS BGPreload] Failed to preload Level 1 SKScene object from file: \(sceneFileName).")
                }
            } else if levelID == "level2" && self.preloadedLevel2Scene == nil { // Added for Level 2
                if let scene = Level2Scene(fileNamed: sceneFileName) { // Assumes Level2Scene exists
                    scene.scaleMode = .aspectFill
                    self.preloadedLevel2Scene = scene
                    print("[LMS BGPreload] Level 2 SKScene object preloaded.")
                } else {
                    print("[LMS BGPreload] Failed to preload Level 2 SKScene object from file: \(sceneFileName).")
                }
            }

            // Audio Preloading
            if let audioName = audioFileName, let audioExt = audioFileExtension {
                if let url = Bundle.main.url(forResource: audioName, withExtension: audioExt) {
                    do {
                        let audioPlayer = try AVAudioPlayer(contentsOf: url)
                        // Assign to correct property based on levelID
                        if levelID == "level1" {
                            self.preloadedLevel1Audio = audioPlayer
                            print("[LMS BGPreload] Level 1 audio preloaded.")
                        } else if levelID == "level2" { // Added for Level 2
                            self.preloadedLevel2Audio = audioPlayer
                            print("[LMS BGPreload] Level 2 audio preloaded.")
                        }
                    } catch {
                        print("[LMS BGPreload] Audio preloading error for \(levelID) (\(audioName).\(audioExt)): \(error.localizedDescription)")
                    }
                } else {
                    print("[LMS BGPreload] Audio file not found for \(levelID): \(audioName).\(audioExt)")
                }
            }
            print("[LMS BGPreload] Asset preloading for \(levelID) finished on background thread.")
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let locationInScene = touch.location(in: self)

        // Iterate through nodes at touch location. Check children of entryNodes first.
        // The `nodes(at:)` method checks top-most nodes first.
        // Our interactive elements (buttons, labels) are children of `entryNode`s.
        // The `entryNode` itself doesn't have a name for interaction.
        for topNode in nodes(at: locationInScene) {
            // Check if the topNode is an entryNode's child that we care about
            // The name is on the button/label itself, which is a child of entryNode.
            // So, node will be the button/label directly.
            guard let nodeName = topNode.name else { continue }
            
            var wasInteractiveNodeHit = false
            let touchAnimationDuration = 0.15
            let actionDelay = 0.05 // Delay before performing action post-animation

            if let labelNode = topNode as? SKLabelNode, (nodeName.starts(with: "play_") || nodeName.starts(with: "leaderboard_") || nodeName == "backToMainMenuButton") {
                let originalColor = labelNode.fontColor ?? .white
                labelNode.fontColor = SKColor.cyan.withAlphaComponent(0.7)
                DispatchQueue.main.asyncAfter(deadline: .now() + touchAnimationDuration) { labelNode.fontColor = originalColor }
                wasInteractiveNodeHit = true
            } else if let spriteNode = topNode as? SKSpriteNode, nodeName.starts(with: "play_") && !nodeName.contains("_locked") {
                // This condition implies the SKSpriteNode itself is named "play_levelX"
                let originalAlpha = spriteNode.alpha
                spriteNode.alpha = 0.7
                DispatchQueue.main.asyncAfter(deadline: .now() + touchAnimationDuration) { spriteNode.alpha = originalAlpha }
                wasInteractiveNodeHit = true
            }

            if wasInteractiveNodeHit {
                // Perform action after a slight delay for the animation to be visible
                DispatchQueue.main.asyncAfter(deadline: .now() + actionDelay) { [weak self] in
                    guard let self = self else { return }

                    if nodeName == "backToMainMenuButton" {
                        self.hideLoadingLabel() // Hide if it was shown for some other action
                        self.goToMainMenu()
                    } else if nodeName.starts(with: "play_") && !nodeName.contains("_locked") {
                        if let levelID = topNode.userData?.value(forKey: "levelID") as? String,
                           let sceneFileName = topNode.userData?.value(forKey: "sceneFileName") as? String {
                            
                            print("[LMS Action] Play button for \(levelID). Showing loading label.")
                            self.showLoadingLabel() // Show loading label immediately

                            // Short delay to allow loading label to render before heavy work
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                                print("[LMS Action] Preparing to navigate to \(levelID).")
                                
                                var sceneInstance: SKScene?
                                var audioToPass: AVAudioPlayer?

                                // Check for preloaded scene and audio
                                if levelID == "level1" {
                                    sceneInstance = self.preloadedLevel1Scene
                                    audioToPass = self.preloadedLevel1Audio
                                } else if levelID == "level2" { // Added for Level 2
                                    sceneInstance = self.preloadedLevel2Scene
                                    audioToPass = self.preloadedLevel2Audio
                                }
                                
                                // If not preloaded, instantiate now
                                if sceneInstance == nil {
                                    print("[LMS Action] SKScene object for \(levelID) was not preloaded or failed. Instantiating from \(sceneFileName).")
                                    if levelID == "level1" {
                                        if let newScene = Level1Scene(fileNamed: sceneFileName) {
                                            newScene.scaleMode = .aspectFill
                                            sceneInstance = newScene
                                        }
                                    } else if levelID == "level2" { // Added for Level 2
                                        if let newScene = Level2Scene(fileNamed: sceneFileName) { // Ensure Level2Scene.swift exists
                                            newScene.scaleMode = .aspectFill
                                            sceneInstance = newScene
                                        }
                                    }
                                    // You might want to also load audio here if not preloaded and needed immediately
                                }
                                
                                if sceneInstance == nil {
                                     print("[LMS Action] CRITICAL: Failed to instantiate scene for \(levelID) from \(sceneFileName). Aborting navigation.")
                                     self.hideLoadingLabel()
                                     return
                                }
                                
                                self.navigateToLevel(levelID: levelID, sceneToPresent: sceneInstance, preloadedAudio: audioToPass)
                            }
                        }
                    } else if nodeName.starts(with: "leaderboard_") {
                        self.hideLoadingLabel() // Hide if shown for other reasons
                        if let levelID = topNode.userData?.value(forKey: "levelID") as? String {
                            self.goToLevelLeaderboard(levelID: levelID)
                        }
                    }
                }
                break // Interaction handled, no need to check other nodes at this touch location
            }
        }
    }

    func navigateToLevel(levelID: String, sceneToPresent: SKScene?, preloadedAudio: AVAudioPlayer?) {
        print("[LMS Navigate] Attempting to present \(levelID).")

        guard let sceneToActuallyPresent = sceneToPresent else {
            print("[LMS Navigate] Scene to present for \(levelID) is nil. Hiding loading label.")
            self.hideLoadingLabel()
            return
        }

        // Pass preloaded audio to the respective scene type
        if let level1Scene = sceneToActuallyPresent as? Level1Scene {
            level1Scene.preloadedAudioPlayer = preloadedAudio
        } else if let level2Scene = sceneToActuallyPresent as? Level2Scene { // Added for Level 2
            level2Scene.preloadedAudioPlayer = preloadedAudio // Assuming Level2Scene has this property
        }
        // Add more 'else if' for other level scene types if they differ and need audio

        if let view = self.view {
            print("[LMS Navigate] Presenting scene for \(levelID).")
            // The loading label will be hidden by the scene transition implicitly,
            // or explicitly if navigation fails.
            view.presentScene(sceneToActuallyPresent, transition: .fade(withDuration: 0.0))
        } else {
            print("[LMS Navigate] View is nil. Cannot present scene for \(levelID). Hiding loading label.")
            self.hideLoadingLabel()
        }
    }

    func goToMainMenu() {
        print("[LMS] goToMainMenu called.")
        guard let view = self.view else { return }
        // hideLoadingLabel() // Already called by interactive node hit logic or not needed if transitioning
        let mainMenuScene = MainMenuScene(size: self.size) // Assuming MainMenuScene exists
        mainMenuScene.scaleMode = .aspectFill
        view.presentScene(mainMenuScene, transition: .fade(withDuration: 0.5))
    }

    func goToLevelLeaderboard(levelID: String) {
        print("[LMS] goToLevelLeaderboard for \(levelID) called.")
        guard let view = self.view else { return }
        // hideLoadingLabel() // Already called by interactive node hit logic
        let leaderboardScene = LevelHighScoresScene(size: self.size, levelID: levelID) // Assuming LevelHighScoresScene exists
        leaderboardScene.scaleMode = .aspectFill
        view.presentScene(leaderboardScene, transition: .fade(withDuration: 0.5))
    }
}
