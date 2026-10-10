import Foundation

public struct Endpoint<RequestBody, ResponseBody> {
  let method: String
  let path: String

  public init(path: String, method: String = "GET") {
    self.path = path
    self.method = method
  }
}

public typealias VoidBodyEndpoint = Endpoint<Void, Void>
public typealias VoidRequestBodyEndpoint<ResponseBody> = Endpoint<Void, ResponseBody>
public typealias VoidResponseBodyEndpoint<RequestBody> = Endpoint<RequestBody, Void>

public actor APIClient {
  public var bearerToken: String?

  private let baseURL: URL
  private let decoder: JSONDecoder
  private let encoder: JSONEncoder
  private let session: URLSession

  public func response(endpoint: VoidBodyEndpoint) async throws {
    let url = url(for: endpoint.path)
    let request = request(url: url, method: endpoint.method)
    try await performRequest(request)
  }

  public func response<RequestBody: Encodable>(
    endpoint: VoidResponseBodyEndpoint<RequestBody>,
    requestBody: RequestBody
  ) async throws {
    let url = url(for: endpoint.path)
    let request = try request(url: url, method: endpoint.method, body: requestBody)
    try await performRequest(request)
  }

  public func response<ResponseBody: Decodable>(
    endpoint: VoidRequestBodyEndpoint<ResponseBody>
  ) async throws -> ResponseBody {
    let url = url(for: endpoint.path)
    let request = request(url: url, method: endpoint.method)
    let data = try await performRequest(request)
    return try decoder.decode(ResponseBody.self, from: data)
  }

  public func response<RequestBody: Encodable, ResponseBody: Decodable>(
    endpoint: Endpoint<RequestBody, ResponseBody>,
    requestBody: RequestBody
  ) async throws -> ResponseBody {
    let url = url(for: endpoint.path)
    let request = try request(url: url, method: endpoint.method, body: requestBody)
    let data = try await performRequest(request)
    return try decoder.decode(ResponseBody.self, from: data)
  }

  public init(
    baseURL: URL,
    bearerToken: String? = nil,
    session: URLSession = .shared,
    encoder: JSONEncoder = .init(),
    decoder: JSONDecoder = .init()
  ) {
    self.baseURL = baseURL
    self.bearerToken = bearerToken
    self.session = session
    self.encoder = encoder
    self.decoder = decoder
  }

  @discardableResult
  private func performRequest(_ request: URLRequest) async throws -> Data {
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          (200 ..< 300).contains(httpResponse.statusCode) else {
      throw URLError(.badServerResponse)
    }
    return data
  }

  private func request(url: URL, method: String) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let bearerToken {
      request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
    }
    return request
  }

  private func request<Body: Encodable>(url: URL, method: String, body: Body) throws -> URLRequest {
    var request = request(url: url, method: method)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try encoder.encode(body)
    return request
  }

  private func url(for path: String) -> URL {
    baseURL.appending(path: path)
  }
}
