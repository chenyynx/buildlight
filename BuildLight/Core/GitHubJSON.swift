import Foundation

/// 与 GitHub 的 JSON 约定集中在这里，测试也用同一份，避免两处漂移。
enum GitHubJSON {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = GitHubClient.iso8601WithFraction.date(from: raw) ?? GitHubClient.iso8601.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析日期 \(raw)")
        }
        return decoder
    }
}
