import Foundation

/// A type that produces the query items for a request URL.
public protocol QueryItemsConvertible {
  /// Query items appended to the request URL.
  var queryItems: [URLQueryItem] { get }
}

extension [String: String]: QueryItemsConvertible {
  /// One query item per entry. The key is the name and the value is the value.
  public var queryItems: [URLQueryItem] {
    map { URLQueryItem(name: $0.key, value: $0.value) }
  }
}

extension [URLQueryItem]: @retroactive ExpressibleByDictionaryLiteral {
  /// One query item per pair, in source order. The key is the name and the value is the value.
  public init(dictionaryLiteral elements: (String, String)...) {
    self = elements.map { URLQueryItem(name: $0.0, value: $0.1) }
  }
}

/// Path, HTTP method, and the types of the query, request body, and response body.
///
/// `RequestBody` and `ResponseBody` are `Void` when that side of the call has no
/// body. `QueryItems` is the type of the value passed to `response` as `queryItems`.
public struct Endpoint<QueryItems, RequestBody, ResponseBody> {
  let method: String
  let path: String

  /// Creates an endpoint for `path` and `method`.
  ///
  /// - Parameters:
  ///   - path: Path appended to the client's base URL.
  ///   - method: HTTP method to send. The default is GET.
  public init(
    path: String,
    method: String = "GET"
  ) {
    self.path = path
    self.method = method
  }
}

/// An `Endpoint` whose request body and response body are both `Void`.
public typealias VoidBodyEndpoint<QueryItems> = Endpoint<QueryItems, Void, Void>
/// An `Endpoint` whose request body is `Void` and whose response body is decoded.
public typealias VoidRequestBodyEndpoint<QueryItems, ResponseBody> =
  Endpoint<QueryItems, Void, ResponseBody>
/// An `Endpoint` whose request body is encoded and whose response body is `Void`.
public typealias VoidResponseBodyEndpoint<QueryItems, RequestBody> =
  Endpoint<QueryItems, RequestBody, Void>

/// JSON client that performs one request per call to `response`.
///
/// A path string is sent as GET, or as POST when the call includes a request body.
/// Pass an `Endpoint` to choose another method. Query items are appended to the URL.
/// Request bodies are encoded with the client's encoder and sent as JSON. Response
/// bodies are decoded with the client's decoder.
///
/// Every request sets `Accept` to `application/json`. A request with a body also sets
/// `Content-Type` to `application/json`. When `bearerToken` is set, the request sets
/// `Authorization` to `Bearer <token>`. A status code outside 200..<300 throws
/// `URLError.badServerResponse`.
public actor APIClient {
  /// Token sent as `Authorization: Bearer <token>` when non-nil.
  ///
  /// Change this after creating the client to send a different token on later requests.
  public var bearerToken: String?

  private let baseURL: URL
  private let decoder: JSONDecoder
  private let encoder: JSONEncoder
  private let session: URLSession

  /// Performs `endpoint` and discards the response body.
  ///
  /// - Parameters:
  ///   - endpoint: Path and HTTP method for a call with no request or response body.
  ///   - queryItems: Query string appended to the URL. An empty collection adds no query.
  /// - Throws: `URLError.badServerResponse` when the status code is outside
  ///   200..<300, or an error raised by `URLSession`.
  public func response<QueryItems: QueryItemsConvertible>(
    endpoint: VoidBodyEndpoint<QueryItems>,
    queryItems: QueryItems
  ) async throws {
    let url = url(for: endpoint.path, queryItems: queryItems)
    let request = request(url: url, method: endpoint.method)
    try await performRequest(request)
  }

  /// Encodes `requestBody` as JSON, performs `endpoint`, and discards the response body.
  ///
  /// - Parameters:
  ///   - endpoint: Path and HTTP method for a call with no response body.
  ///   - requestBody: Value encoded as the JSON request body.
  ///   - queryItems: Query string appended to the URL. An empty collection adds no query.
  /// - Throws: `URLError.badServerResponse` when the status code is outside
  ///   200..<300, an encoding error when `requestBody` cannot be encoded, or an error
  ///   raised by `URLSession`.
  public func response<QueryItems: QueryItemsConvertible, RequestBody: Encodable>(
    endpoint: VoidResponseBodyEndpoint<QueryItems, RequestBody>,
    requestBody: RequestBody,
    queryItems: QueryItems
  ) async throws {
    let url = url(for: endpoint.path, queryItems: queryItems)
    let request = try request(url: url, method: endpoint.method, body: requestBody)
    try await performRequest(request)
  }

  /// Performs `endpoint` and decodes the JSON response body.
  ///
  /// - Parameters:
  ///   - endpoint: Path and HTTP method for a call with no request body.
  ///   - queryItems: Query string appended to the URL. An empty collection adds no query.
  /// - Returns: The response body decoded as `ResponseBody`.
  /// - Throws: `URLError.badServerResponse` when the status code is outside
  ///   200..<300, a decoding error when the body does not match `ResponseBody`, or an
  ///   error raised by `URLSession`.
  public func response<QueryItems: QueryItemsConvertible, ResponseBody: Decodable>(
    endpoint: VoidRequestBodyEndpoint<QueryItems, ResponseBody>,
    queryItems: QueryItems
  ) async throws -> ResponseBody {
    let url = url(for: endpoint.path, queryItems: queryItems)
    let request = request(url: url, method: endpoint.method)
    let data = try await performRequest(request)
    return try decoder.decode(ResponseBody.self, from: data)
  }

  /// Encodes `requestBody` as JSON, performs `endpoint`, and decodes the response body.
  ///
  /// - Parameters:
  ///   - endpoint: Path and HTTP method for the call.
  ///   - requestBody: Value encoded as the JSON request body.
  ///   - queryItems: Query string appended to the URL. An empty collection adds no query.
  /// - Returns: The response body decoded as `ResponseBody`.
  /// - Throws: `URLError.badServerResponse` when the status code is outside
  ///   200..<300, an encoding error when `requestBody` cannot be encoded, a decoding
  ///   error when the body does not match `ResponseBody`, or an error raised by
  ///   `URLSession`.
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

  /// Sends a GET request to `path` and discards the response body.
  ///
  /// - Parameters:
  ///   - path: Path appended to the base URL.
  ///   - queryItems: Query string appended to the URL. An empty collection adds no query.
  /// - Throws: `URLError.badServerResponse` when the status code is outside
  ///   200..<300, or an error raised by `URLSession`.
  public func response<QueryItems: QueryItemsConvertible>(
    _ path: String,
    queryItems: QueryItems
  ) async throws {
    try await response(
      endpoint: VoidBodyEndpoint<QueryItems>(path: path),
      queryItems: queryItems
    )
  }

  /// Sends a POST request to `path` with `requestBody` encoded as JSON and discards
  /// the response body.
  ///
  /// - Parameters:
  ///   - path: Path appended to the base URL.
  ///   - requestBody: Value encoded as the JSON request body.
  ///   - queryItems: Query string appended to the URL. An empty collection adds no query.
  /// - Throws: `URLError.badServerResponse` when the status code is outside
  ///   200..<300, an encoding error when `requestBody` cannot be encoded, or an error
  ///   raised by `URLSession`.
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

  /// Sends a GET request to `path` and decodes the JSON response body.
  ///
  /// - Parameters:
  ///   - path: Path appended to the base URL.
  ///   - queryItems: Query string appended to the URL. An empty collection adds no query.
  /// - Returns: The response body decoded as `ResponseBody`.
  /// - Throws: `URLError.badServerResponse` when the status code is outside
  ///   200..<300, a decoding error when the body does not match `ResponseBody`, or an
  ///   error raised by `URLSession`.
  public func response<QueryItems: QueryItemsConvertible, ResponseBody: Decodable>(
    _ path: String,
    queryItems: QueryItems
  ) async throws -> ResponseBody {
    try await response(
      endpoint: VoidRequestBodyEndpoint<QueryItems, ResponseBody>(path: path),
      queryItems: queryItems
    )
  }

  /// Sends a POST request to `path` with `requestBody` encoded as JSON and decodes
  /// the response body.
  ///
  /// - Parameters:
  ///   - path: Path appended to the base URL.
  ///   - requestBody: Value encoded as the JSON request body.
  ///   - queryItems: Query string appended to the URL. An empty collection adds no query.
  /// - Returns: The response body decoded as `ResponseBody`.
  /// - Throws: `URLError.badServerResponse` when the status code is outside
  ///   200..<300, an encoding error when `requestBody` cannot be encoded, a decoding
  ///   error when the body does not match `ResponseBody`, or an error raised by
  ///   `URLSession`.
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

  /// Creates a client rooted at `baseURL`.
  ///
  /// - Parameters:
  ///   - baseURL: Absolute URL that request paths are appended to.
  ///   - bearerToken: Token sent as a bearer `Authorization` header. The default is `nil`.
  ///   - session: Session that performs each request. The default is `.shared`.
  ///   - encoder: Encoder for request bodies. The default is a new `JSONEncoder`.
  ///   - decoder: Decoder for response bodies. The default is a new `JSONDecoder`.
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
