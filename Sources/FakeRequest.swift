struct FakeRequest {
    let response: Any?
    let responseType: Networking.ResponseType
    let statusCode: Int

    static func findRequest(in dictionary: [String: FakeRequest], usingPath path: String) -> FakeRequest? {
        // Before this was just a dictionary and you could use the path to get it. But now is more complex than that.
        // Now you need to check for possible matches for an specific path.

        // get all faked paths
        // remove leading and tail '/'
        // split using '/'
        // filter using the number of elements
        // take first element from requested path
        // search in list of faked paths
        // Not found? Continue.
        // Found?
        // If that's all the components, use the path
        // If there are more components, continue with next component
        // Next component. Starts with {?

        return dictionary[path]
    }

    static func find(ofType type: Networking.RequestType, forPath path: String, in collection: [Networking.RequestType: [String: FakeRequest]]) -> FakeRequest? {
        let requestsForType = collection[type]
        let result = requestsForType?[path]

        return result
    }
}
