import Foundation

protocol SeedLoadable: Decodable {
    static var seedFileName: String { get }
}

enum SeedError: LocalizedError {
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "Seed file not found: \(fileName).json"
        }
    }
}

struct SeedLoader {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func load<T: SeedLoadable>(_ type: T.Type) throws -> T {
        guard let url = bundle.url(
            forResource: T.seedFileName,
            withExtension: "json",
            subdirectory: "SeedData"
        ) else {
            throw SeedError.fileNotFound(T.seedFileName)
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
