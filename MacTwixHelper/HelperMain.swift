import Foundation
import Security

@main
enum MacTwixHelperMain {
    static func main() {
        let delegate = HelperXPCService()
        let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
        listener.delegate = delegate
        listener.resume()

        Logger.log("MacTwixHelper started uid=\(getuid())")
        AutoModeEngine.shared.start()
        RunLoop.current.run()
    }
}

enum Logger {
    static func log(_ message: String) {
        let line = "MacTwixHelper: \(message)\n"
        if let data = line.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
        NSLog("%@", "MacTwixHelper: \(message)")
    }
}
