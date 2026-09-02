import Foundation
import Observation

@MainActor
@Observable
final class ProjectStore {
    private(set) var projects: [Project] = []
    let fileURL: URL

    nonisolated static var defaultFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("uk.co.29degrees.projects").appendingPathComponent("projects.json")
    }

    init(fileURL: URL = ProjectStore.defaultFileURL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = loaded
        }
    }

    func add(_ project: Project) {
        projects.append(project)
        enforceUniqueSpace(for: project)
        save()
    }

    /// Replaces the project with the same id. If it now claims a space, any
    /// other project on that space is unassigned.
    func update(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project
        enforceUniqueSpace(for: project)
        save()
    }

    func remove(id: UUID) {
        projects.removeAll { $0.id == id }
        save()
    }

    func project(forSpace uuid: String?) -> Project? {
        guard let uuid else { return nil }
        return projects.first { $0.spaceUUID == uuid }
    }

    private func enforceUniqueSpace(for project: Project) {
        guard let space = project.spaceUUID else { return }
        for index in projects.indices where projects[index].id != project.id && projects[index].spaceUUID == space {
            projects[index].spaceUUID = nil
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(projects) else { return }
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
