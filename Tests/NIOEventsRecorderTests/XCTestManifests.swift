import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(swift_nio_events_recorderTests.allTests),
    ]
}
#endif
