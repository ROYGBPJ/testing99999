import Foundation
import XCTest
@testable import NovaVideoSearch

final class YouTubeSearchServiceTests: XCTestCase {
    func testEmptyQueryIsRejectedBeforeNetworkRequest() async {
        let service = YouTubeSearchService(apiKey: "test-key")
        do {
            _ = try await service.searchVideos(query: "  \n ")
            XCTFail("Expected empty query error")
        } catch let error as YouTubeSearchError {
            XCTAssertEqual(error, .emptyQuery)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMissingAPIKeyIsReported() async {
        let service = YouTubeSearchService(apiKey: " \n ")
        do {
            _ = try await service.searchVideos(query: "cats")
            XCTFail("Expected missing API key error")
        } catch let error as YouTubeSearchError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWatchURLEncodesVideoID() throws {
        let data = Data(#"{"items":[{"id":{"videoId":"abc_123-xy"},"snippet":{"title":"Test & title","channelTitle":"Channel","description":"Description","thumbnails":{"high":{"url":"https://i.ytimg.com/vi/abc_123-xy/hqdefault.jpg"}}}}]}"#.utf8)
        let response = try JSONDecoder().decode(TestEnvelope.self, from: data)
        let result = response.items[0]
        XCTAssertEqual(result.videoID, "abc_123-xy")
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(result.watchURL), resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value, "abc_123-xy")
        XCTAssertEqual(result.snippet.title, "Test & title")
    }

    private struct TestEnvelope: Decodable { let items: [YouTubeSearchResult] }
}
