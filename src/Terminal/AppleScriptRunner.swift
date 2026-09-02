import Foundation

@MainActor
enum AppleScriptRunner {
    struct Failure: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }

    static func run(_ source: String) throws {
        guard let script = NSAppleScript(source: source) else {
            throw Failure(message: "Could not compile AppleScript.")
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "\(error)"
            throw Failure(message: message)
        }
    }
}
