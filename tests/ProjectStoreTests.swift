import Testing
import Foundation
import CoreGraphics
@testable import Projects

@MainActor
struct ProjectStoreTests {
    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectStoreTests-\(UUID().uuidString)")
            .appendingPathComponent("projects.json")
    }

    @Test func startsEmptyWhenFileMissing() {
        #expect(ProjectStore(fileURL: tempFile()).projects.isEmpty)
    }

    @Test func addPersistsAcrossInstances() {
        let url = tempFile()
        let project = Project(name: "Website", directory: "/tmp/site",
                              windows: [TerminalWindow(rect: CGRect(x: 0, y: 25, width: 800, height: 600))],
                              urls: ["https://example.com"])
        ProjectStore(fileURL: url).add(project)
        #expect(ProjectStore(fileURL: url).projects == [project])
    }

    @Test func updateReplacesById() {
        let store = ProjectStore(fileURL: tempFile())
        var project = Project(name: "A", directory: "/a")
        store.add(project)
        project.name = "B"
        store.update(project)
        #expect(store.projects.map(\.name) == ["B"])
    }

    @Test func removeDeletes() {
        let store = ProjectStore(fileURL: tempFile())
        let project = Project(name: "A", directory: "/a")
        store.add(project)
        store.remove(id: project.id)
        #expect(store.projects.isEmpty)
    }

    @Test func assigningASpaceUnassignsItFromOtherProjects() {
        let store = ProjectStore(fileURL: tempFile())
        var first = Project(name: "A", directory: "/a", spaceUUID: "s1")
        var second = Project(name: "B", directory: "/b")
        store.add(first)
        store.add(second)
        second.spaceUUID = "s1"
        store.update(second)
        first = store.projects[0]
        #expect(first.spaceUUID == nil)
        #expect(store.project(forSpace: "s1")?.name == "B")
    }

    @Test func lookupByNilSpaceIsNil() {
        let store = ProjectStore(fileURL: tempFile())
        store.add(Project(name: "A", directory: "/a"))
        #expect(store.project(forSpace: nil) == nil)
    }

    @Test func decodesRecordsWithoutFlagsDerivingThemFromContent() throws {
        let json = """
        [{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"A","directory":"/a","spaceUUID":"s1",
          "windows":[{"left":0,"top":0,"right":1,"bottom":1}],"urls":[]},
         {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FE","name":"B","directory":"","spaceUUID":"s2",
          "windows":[],"urls":["https://b.test"]}]
        """
        let projects = try JSONDecoder().decode([Project].self, from: Data(json.utf8))
        #expect(projects[0].openTerminals == true)
        #expect(projects[0].openChrome == false)
        #expect(projects[1].openTerminals == false)
        #expect(projects[1].openChrome == true)
    }

    @Test func flagsRoundTrip() throws {
        var project = Project(name: "A", directory: "/a")
        project.openTerminals = true
        project.openChrome = true
        let data = try JSONEncoder().encode(project)
        #expect(try JSONDecoder().decode(Project.self, from: data) == project)
    }

    @Test func terminalWindowFromRectUsesEdges() {
        let window = TerminalWindow(rect: CGRect(x: 10, y: 20, width: 300, height: 200))
        #expect(window == TerminalWindow(left: 10, top: 20, right: 310, bottom: 220))
    }

    @Test func undecodableFileIsMovedAsideNotOverwritten() throws {
        let url = tempFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let store = ProjectStore(fileURL: url)
        #expect(store.projects.isEmpty)
        let siblings = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
        #expect(siblings.contains { $0.hasPrefix("projects.json.broken-") })
        store.add(Project(name: "A", directory: "/a"))
        let reloaded = try Data(contentsOf: url)
        #expect(!reloaded.isEmpty)
        #expect(ProjectStore(fileURL: url).projects.map(\.name) == ["A"])
    }
}
