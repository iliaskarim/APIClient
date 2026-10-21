import Foundation

public protocol QueryItemsConvertible {
  var queryItems: [URLQueryItem] { get }
}

extension [String: String]: QueryItemsConvertible {
  public var queryItems: [URLQueryItem] {
    map { URLQueryItem(name: $0.key, value: $0.value) }
  }
}

public struct Endpoint<QueryItems, RequestBody, ResponseBody> {
  let method: String
  let path: String

  public init(
    path: String,
    method: String = "GET"
  ) {
    self.path = path
    self.method = method
  }
}

public typealias VoidBodyEndpoint<QueryItems> = Endpoint<QueryItems, Void, Void>
public typealias VoidRequestBodyEndpoint<QueryItems, ResponseBody> =
  Endpoint<QueryItems, Void, ResponseBody>
public typealias VoidResponseBodyEndpoint<QueryItems, RequestBody> =
  Endpoint<QueryItems, RequestBody, Void>

public actor APIClient {
  public var bearerToken: String?

  private let baseURL: URL
  private let decoder: JSONDecoder
  private let encoder: JSONEncoder
  private let session: URLSession

  public func response<QueryItems: QueryItemsConvertible>(
    endpoint: VoidBodyEndpoint<QueryItems>,
    queryItems: QueryItems
  ) async throws {
    let url = url(for: endpoint.path, queryItems: queryItems)
    let request = request(url: url, method: endpoint.method)
    try await performRequest(request)
  }

  public func response<QueryItems: QueryItemsConvertible, RequestBody: Encodable>(
    endpoint: VoidResponseBodyEndpoint<QueryItems, RequestBody>,
    requestBody: RequestBody,
    queryItems: QueryItems
  ) async throws {
    let url = url(for: endpoint.path, queryItems: queryItems)
    let request = try request(url: url, method: endpoint.method, body: requestBody)
    try await performRequest(request)
  }

  public func response<QueryItems: QueryItemsConvertible, ResponseBody: Decodable>(
    endpoint: VoidRequestBodyEndpoint<QueryItems, ResponseBody>,
    queryItems: QueryItems
  ) async throws -> ResponseBody {
    let url = url(for: endpoint.path, queryItems: queryItems)
    let request = request(url: url, method: endpoint.method)
    let data = try await performRequest(request)
    return try decoder.decode(ResponseBody.self, from: data)
  }

  public func response<
    QueryItems: QueryItemsConvertible,
    RequestBody: Encodable,
    ResponseBody: Decodable
  >(
    endpoint: Endpoint<QueryItems, RequestBody, ResponseBody>,
    requestBody: RequestBody,
    queryItems: QueryItems
  ) async throws -> ResponseBody {
    let url = url(for: endpoint.path, queryItems: queryItems)
    let request = try request(url: url, method: endpoint.method, body: requestBody)
    let data = try await performRequest(request)
    return try decoder.decode(ResponseBody.self, from: data)
  }

  public func response<QueryItems: QueryItemsConvertible>(
    _ path: String,
    queryItems: QueryItems
  ) async throws {
    try await response(
      endpoint: VoidBodyEndpoint<QueryItems>(path: path),
      queryItems: queryItems
    )
  }

  public func response<QueryItems: QueryItemsConvertible, RequestBody: Encodable>(
    _ path: String,
    requestBody: RequestBody,
    queryItems: QueryItems
  ) async throws {
    try await response(
      endpoint: VoidResponseBodyEndpoint<QueryItems, RequestBody>(
        path: path,
        method: "POST"
      ),
      requestBody: requestBody,
      queryItems: queryItems
    )
  }

  public func response<QueryItems: QueryItemsConvertible, ResponseBody: Decodable>(
    _ path: String,
    queryItems: QueryItems
  ) async throws -> ResponseBody {
    try await response(
      endpoint: VoidRequestBodyEndpoint<QueryItems, ResponseBody>(path: path),
      queryItems: queryItems
    )
  }

  public func response<
    QueryItems: QueryItemsConvertible,
    RequestBody: Encodable,
    ResponseBody: Decodable
  >(
    _ path: String,
    requestBody: RequestBody,
    queryItems: QueryItems
  ) async throws -> ResponseBody {
    try await response(
      endpoint: Endpoint<QueryItems, RequestBody, ResponseBody>(
        path: path,
        method: "POST"
      ),
      requestBody: requestBody,
      queryItems: queryItems
    )
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

  private func request(url: URL, method: String, body: some Encodable) throws -> URLRequest {
    var request = request(url: url, method: method)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try encoder.encode(body)
    return request
  }

  private func url(for path: String, queryItems: some QueryItemsConvertible) -> URL {
    let items = queryItems.queryItems
    let url = baseURL.appending(path: path)
    guard !items.isEmpty,
          var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return url
    }

    components.queryItems = items
    return components.url ?? url
  }
}
