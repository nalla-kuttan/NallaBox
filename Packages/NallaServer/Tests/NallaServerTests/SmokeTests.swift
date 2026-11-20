import Testing
import NallaCore
@testable import NallaServer

@Test func serverSeesCoreProtocolVersion() {
    #expect(nallaServerProtocolVersion == nallaProtocolVersion)
}
