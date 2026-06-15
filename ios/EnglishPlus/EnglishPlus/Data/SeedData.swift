import Foundation

enum SeedData {
    static let starterQuestions: [Question] = [
        Question(id: "q-vocab-001", type: .vocabulary, prompt: "Choose the word that means 'important'.", difficulty: "基礎"),
        Question(id: "q-grammar-001", type: .grammar, prompt: "She ___ to school every day.", difficulty: "基礎"),
        Question(id: "q-reading-001", type: .reading, prompt: "Read a short paragraph and find the main idea.", difficulty: "會考核心")
    ]
}
