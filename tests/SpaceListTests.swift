import Testing
@testable import Projects

struct SpaceListTests {
    static func entry(_ uuid: String, type: Int = 0, id: Int = 0) -> [String: Any] {
        ["uuid": uuid, "type": type, "ManagedSpaceID": id]
    }

    static func display(spaces: [[String: Any]], current: [String: Any]) -> [[String: Any]] {
        [["Display Identifier": "Main", "Spaces": spaces, "Current Space": current]]
    }

    @Test func numbersDesktopsInListOrder() {
        let snap = SpaceList.parse(Self.display(
            spaces: [Self.entry("a"), Self.entry("b"), Self.entry("c")],
            current: Self.entry("b")))
        #expect(snap.spaces.map(\.uuid) == ["a", "b", "c"])
        #expect(snap.spaces.map(\.number) == [1, 2, 3])
        #expect(snap.currentUUID == "b")
    }

    @Test func skipsFullScreenSpacesWhenNumbering() {
        let snap = SpaceList.parse(Self.display(
            spaces: [Self.entry("a"), Self.entry("fs", type: 4), Self.entry("b")],
            current: Self.entry("a")))
        #expect(snap.spaces.map(\.uuid) == ["a", "b"])
        #expect(snap.spaces.last?.number == 2)
    }

    @Test func emptyUUIDFallsBackToManagedID() {
        let snap = SpaceList.parse(Self.display(
            spaces: [Self.entry("", id: 7)],
            current: Self.entry("", id: 7)))
        #expect(snap.spaces.first?.uuid == "managed-7")
        #expect(snap.currentUUID == "managed-7")
    }

    @Test func usesFirstDisplayOnly() {
        var displays = Self.display(spaces: [Self.entry("a")], current: Self.entry("a"))
        displays.append(Self.display(spaces: [Self.entry("z")], current: Self.entry("z"))[0])
        #expect(SpaceList.parse(displays).spaces.map(\.uuid) == ["a"])
    }

    @Test func noDisplaysGivesEmpty() {
        #expect(SpaceList.parse([]) == .empty)
    }
}
