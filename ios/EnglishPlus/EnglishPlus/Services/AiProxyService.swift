import Foundation

protocol AiProxyService {
    func run(_ request: AiProxyRequest, currentUser: DemoUser?) async -> AiProxyResponse
}
