import Foundation
import os

nonisolated protocol SpaceProviding {
    /// Raw per-display dictionaries from CGSCopyManagedDisplaySpaces.
    func displaySpaces() -> [[String: Any]]
}

/// Loads the private SkyLight functions at runtime. If either symbol is
/// missing the provider returns an empty list, so the app keeps running.
nonisolated struct SpaceProvider: SpaceProviding {
    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias CopySpacesFn = @convention(c) (Int32) -> Unmanaged<CFArray>?

    private static let log = Logger(subsystem: "uk.co.29degrees.projects", category: "SpaceProvider")

    nonisolated(unsafe) private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    func displaySpaces() -> [[String: Any]] {
        guard let handle = Self.handle,
              let mainSymbol = dlsym(handle, "CGSMainConnectionID"),
              let copySymbol = dlsym(handle, "CGSCopyManagedDisplaySpaces")
        else {
            Self.log.error("SkyLight is missing a symbol; the space list will be empty")
            return []
        }
        let mainConnection = unsafeBitCast(mainSymbol, to: MainConnectionFn.self)
        let copySpaces = unsafeBitCast(copySymbol, to: CopySpacesFn.self)
        guard let array = copySpaces(mainConnection())?.takeRetainedValue() else { return [] }
        return array as? [[String: Any]] ?? []
    }
}
