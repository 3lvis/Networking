#if !os(watchOS)
    public class MultiplatformTest {
        #if os(macOS)
        func expectation(description: String) -> MultiplatformTest {
            return MultiplatformTest()
        }

        func fulfill() {

        }

        func waitForExpectations(timeout: Double, handler: (() -> Void)?) {

        }
        #endif
    }
    public typealias XCTestCase = MultiplatformTest
#else
    import XCTest
    public typealias XCTestCase = XCTestCase
#endif
