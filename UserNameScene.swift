import SpriteKit
import UIKit
import FirebaseFirestore

class UserNameScene: SKScene, UITextFieldDelegate {
    
    private let titleLabel = SKLabelNode(text: "Create user name for the public leaderboard")
    private let textBoxLabel = SKLabelNode(text: "Tap to enter name")
    private let saveButton = SKLabelNode(text: "Save")
    private let savedLabel = SKLabelNode(text: "User name saved!")
    private let backButton = SKLabelNode(text: "Back")
    
    // Changed: Make the shape an outline instead of a filled rect
    private let textBoxBackground = SKShapeNode(rectOf: CGSize(width: 260, height: 50), cornerRadius: 10)
    private let saveButtonBackground = SKShapeNode(rectOf: CGSize(width: 120, height: 50), cornerRadius: 25)
    
    private var textField: UITextField?
    private var textFieldContainer: UIView?
    
    private let userNameKey = "username"
    private var existingName: String = ""
    
    private let db = Firestore.firestore()
    private let usernamesCollection = "usernames"
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        
        existingName = UserDefaults.standard.string(forKey: userNameKey) ?? ""
        
        // Title label
        titleLabel.fontColor = .white
        titleLabel.fontName = "Avenir-Black"
        titleLabel.fontSize = 22
        titleLabel.numberOfLines = 2
        titleLabel.preferredMaxLayoutWidth = size.width * 0.9
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.80)
        addChild(titleLabel)
        
        // Back button
        backButton.fontName = "Avenir-Black"
        backButton.fontSize = 28
        backButton.fontColor = .white
        backButton.position = CGPoint(x: 60, y: size.height - 50)
        backButton.name = "backButton"
        addChild(backButton)
        
        // Gray outline for text box
        textBoxBackground.fillColor = .clear
        textBoxBackground.strokeColor = .gray
        textBoxBackground.lineWidth = 3
        textBoxBackground.zPosition = -1
        textBoxBackground.position = CGPoint(x: size.width / 2, y: size.height * 0.65)
        textBoxBackground.name = "textBoxBackground"
        addChild(textBoxBackground)
        
        // Text box label
        textBoxLabel.fontColor = existingName.isEmpty ? .gray : .white
        textBoxLabel.fontName = "Avenir-Black"
        textBoxLabel.fontSize = 28
        textBoxLabel.horizontalAlignmentMode = .center
        textBoxLabel.verticalAlignmentMode = .center
        textBoxLabel.zPosition = 10
        textBoxLabel.position = textBoxBackground.position
        textBoxLabel.name = "textBox"
        if !existingName.isEmpty {
            textBoxLabel.text = existingName
        }
        addChild(textBoxLabel)
        
        // Save button background (hidden initially)
        saveButtonBackground.fillColor = UIColor(red: 0, green: 0.8, blue: 0.8, alpha: 0.3)
        saveButtonBackground.strokeColor = .cyan
        saveButtonBackground.lineWidth = 2
        saveButtonBackground.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        saveButtonBackground.name = "saveButton"
        saveButtonBackground.isHidden = true
        addChild(saveButtonBackground)
        
        // "Save" text (hidden initially)
        saveButton.fontColor = .cyan
        saveButton.fontName = "Avenir-Black"
        saveButton.fontSize = 32
        saveButton.horizontalAlignmentMode = .center
        saveButton.verticalAlignmentMode = .center
        saveButton.position = saveButtonBackground.position
        saveButton.name = "saveButton"
        saveButton.isHidden = true
        addChild(saveButton)
        
        // Saved feedback label
        savedLabel.fontColor = .green
        savedLabel.fontName = "Avenir-Black"
        savedLabel.fontSize = 24
        savedLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.35)
        savedLabel.alpha = 0.0
        addChild(savedLabel)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = self.view, let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)
        
        for node in tappedNodes {
            if (node.name == "textBox" || node.name == "textBoxBackground") {
                if textField == nil && textFieldContainer == nil {
                    showKeyboard(in: view)
                    textBoxBackground.isHidden = true
                }
            } else if node.name == "saveButton" {
                saveUsername()
            } else if node.name == "backButton", let labelNode = node as? SKLabelNode {
                dismissKeyboardIfNeeded()
                let originalColor = labelNode.fontColor
                labelNode.fontColor = .cyan

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                labelNode.fontColor = originalColor
                let menu = MainMenuScene(size: self.size)
                menu.scaleMode = .aspectFill
                self.view?.presentScene(menu, transition: .fade(withDuration: 0.5))
                }
            }
        }
    }
    
    private func showKeyboard(in skView: SKView) {
        dismissKeyboardIfNeeded()
        
        let container = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        container.frame = CGRect(x: 0, y: 0, width: skView.frame.width, height: 80)
        container.center.y = skView.frame.height * 0.3
        
        let tf = UITextField(frame: .zero)
        tf.delegate = self
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.returnKeyType = .done
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.textColor = .white
        tf.font = UIFont(name: "Avenir-Black", size: 20)
        tf.tintColor = .cyan
        tf.textAlignment = .center
        
        let currentName = (textBoxLabel.text == "Tap to enter name") ? "" : textBoxLabel.text ?? ""
        tf.text = currentName
        tf.attributedPlaceholder = NSAttributedString(
            string: "Enter username",
            attributes: [.foregroundColor: UIColor.gray,
                         .font: UIFont(name: "Avenir-Black", size: 20)!]
        )
        
        let borderView = UIView(frame: CGRect(x: 0, y: 0, width: skView.frame.width * 0.7, height: 2))
        borderView.backgroundColor = .cyan
        borderView.alpha = 0.7
        
        container.contentView.addSubview(tf)
        container.contentView.addSubview(borderView)
        skView.addSubview(container)
        
        tf.translatesAutoresizingMaskIntoConstraints = false
        borderView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tf.centerXAnchor.constraint(equalTo: container.contentView.centerXAnchor),
            tf.centerYAnchor.constraint(equalTo: container.contentView.centerYAnchor),
            tf.widthAnchor.constraint(equalTo: container.contentView.widthAnchor, multiplier: 0.7),
            tf.heightAnchor.constraint(equalToConstant: 40),
            
            borderView.topAnchor.constraint(equalTo: tf.bottomAnchor, constant: 4),
            borderView.centerXAnchor.constraint(equalTo: tf.centerXAnchor),
            borderView.widthAnchor.constraint(equalTo: tf.widthAnchor, multiplier: 0.5),
            borderView.heightAnchor.constraint(equalToConstant: 2)
        ])
        
        container.alpha = 0
        UIView.animate(withDuration: 0.3) {
            container.alpha = 1
        }
        
        tf.becomeFirstResponder()
        
        textField = tf
        textFieldContainer = container
    }
    
    private func dismissKeyboardIfNeeded() {
        if let tf = textField {
            tf.resignFirstResponder()
            UIView.animate(withDuration: 0.3) {
                self.textFieldContainer?.alpha = 0
            } completion: { _ in
                self.textFieldContainer?.removeFromSuperview()
                self.textField = nil
                self.textFieldContainer = nil
            }
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let typed = textField.text ?? ""
        if typed.isEmpty {
            textBoxLabel.text = "Tap to enter name"
            textBoxLabel.zPosition = 100
            textBoxLabel.fontColor = .gray
        } else {
            textBoxLabel.text = typed
            textBoxLabel.fontColor = .white
        }
        
        textBoxBackground.isHidden = false
        
        UIView.animate(withDuration: 0.3) {
            self.textFieldContainer?.alpha = 0
        } completion: { _ in
            self.textFieldContainer?.removeFromSuperview()
            self.textField = nil
            self.textFieldContainer = nil
        }
    }
    
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard let current = textField.text else { return true }
        let newText = (current as NSString).replacingCharacters(in: range, with: string)
        
        if newText.count >= 3 && newText != existingName {
            saveButtonBackground.isHidden = false
            saveButton.isHidden = false
        } else {
            saveButtonBackground.isHidden = true
            saveButton.isHidden = true
        }
        
        return newText.count <= 6
    }
    
    // MARK: - Save Logic
    
    private func saveUsername() {
        dismissKeyboardIfNeeded()
        let rawName = (textBoxLabel.text == "Tap to enter name") ? "" : textBoxLabel.text ?? ""
        
        // Trim whitespace and newlines from the username, convert to lowercase
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if name.count < 3 {
            savedLabel.text = "Username must be at least 3 characters!"
            savedLabel.fontColor = .red
            savedLabel.removeAllActions()
            savedLabel.alpha = 1.0
            savedLabel.run(.fadeOut(withDuration: 3.0))
            return
        }
        
        // Check if username exists in Firestore (case-insensitive)
        db.collection(usernamesCollection)
          .whereField("username", isEqualTo: name)
          .getDocuments { [weak self] (querySnapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error checking for username: \(error)")
                self.savedLabel.text = "Error saving username"
                self.savedLabel.fontColor = .red
                self.savedLabel.removeAllActions()
                self.savedLabel.alpha = 1.0
                self.savedLabel.run(.fadeOut(withDuration: 3.0))
                return
            }
            
            if let querySnapshot = querySnapshot, !querySnapshot.documents.isEmpty {
                // Username already exists
                self.savedLabel.text = "Damn, that username is already taken"
                self.savedLabel.position = CGPoint(x: self.saveButton.position.x, y: self.saveButton.position.y - 55)
                self.savedLabel.fontColor = .red
                self.savedLabel.removeAllActions()
                self.savedLabel.alpha = 1.0
                self.savedLabel.run(.fadeOut(withDuration: 5.0))
            } else {
                // Username is unique, proceed with saving
                // Note: Save the original case of the username
                self.db.collection(self.usernamesCollection).addDocument(data: ["username": rawName]) { error in
                    if let error = error {
                        print("Error saving username to Firestore: \(error)")
                        self.savedLabel.text = "Error saving username"
                        self.savedLabel.fontColor = .red
                        self.savedLabel.removeAllActions()
                        self.savedLabel.alpha = 1.0
                        self.savedLabel.run(.fadeOut(withDuration: 3.0))
                    } else {
                        // Save to UserDefaults with original case
                        UserDefaults.standard.set(rawName, forKey: self.userNameKey)
                        
                        self.savedLabel.position = CGPoint(x: self.saveButton.position.x, y: self.saveButton.position.y - 50)
                        self.savedLabel.text = "User name saved!"
                        self.savedLabel.fontColor = .green
                        self.savedLabel.removeAllActions()
                        self.savedLabel.alpha = 1.0
                        self.savedLabel.run(.fadeOut(withDuration: 2.0))
                    }
                }
            }
        }
    }
}
