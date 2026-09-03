import Foundation
import Observation
import os

@MainActor
@Observable
final class ProjectStore {
  private(set) var projects: [Project] = []
  let fileURL: URL
  private var saveDisabled = false

  private static let logger = Logger(subsystem: "uk.co.29degrees.projects", category: "ProjectStore")

  nonisolated static var defaultFileURL: URL {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return support.appendingPathComponent("uk.co.29degrees.projects").appendingPathComponent("projects.json")
  }

  init(fileURL: URL = ProjectStore.defaultFileURL) {
    self.fileURL = fileURL
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
    do {
      let data = try Data(contentsOf: fileURL)
      projects = try JSONDecoder().decode([Project].self, from: data)
    } catch {
      Self.logger.error(
        "Failed to load projects from \(fileURL.path, privacy: .public): \(String(describing: error), privacy: .public)"
      )
      moveAsideBrokenFile()
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

  private func moveAsideBrokenFile() {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let brokenURL = URL(fileURLWithPath: fileURL.path + ".broken-\(formatter.string(from: Date()))")
    do {
      try FileManager.default.moveItem(at: fileURL, to: brokenURL)
    } catch {
      Self.logger.error(
        "Failed to move aside broken projects file \(self.fileURL.path, privacy: .public): \(String(describing: error), privacy: .public)"
      )
      saveDisabled = true
    }
  }

  private func save() {
    guard !saveDisabled else { return }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
      let data = try encoder.encode(projects)
      let directory = fileURL.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try data.write(to: fileURL, options: .atomic)
    } catch {
      Self.logger.error(
        "Failed to save projects to \(self.fileURL.path, privacy: .public): \(String(describing: error), privacy: .public)"
      )
    }
  }
}
