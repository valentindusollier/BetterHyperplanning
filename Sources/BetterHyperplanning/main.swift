import Foundation
import Logging
import PerfectHTTPServer

#if os(Linux)
    import FoundationNetworking
#endif

struct Config: Codable {
    var port: Int
}

fileprivate let logger = Logger(label: "root")

let configPath = "\(FileManager.default.currentDirectoryPath)/config.plist"
let preferencesPath = "\(FileManager.default.currentDirectoryPath)/preferences.json"

var port = 8070

// Read configs
if let xml = FileManager.default.contents(atPath: configPath),
   let config = try? PropertyListDecoder().decode(Config.self, from: xml) {
    port = config.port
} else {
    logger.error("Config file is corrupted or does not exist... Set default settings.")
    
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .xml
    
    if let url = URL(string: "file://\(configPath)"),
       let data = try? encoder.encode(Config(port: port)),
       let _ = try? data.write(to: url) {
        // Nothing to do...
    } else {
        logger.error("Can't write config file...")
    }
}

// Read preferences

var preferences: Preferences

if FileManager.default.fileExists(atPath: preferencesPath) {
    do {
        preferences = try Preferences(path: preferencesPath)
    } catch {
        logger.error("Can't retrieve preferences, exit...\n\(error)")
        exit(1)
    }
} else {
    preferences = Preferences()
}

// Initialize server

logger.info("Initializing the server on port \(port)...")

try HTTPServer.launch(name: "iCal", port: port, routes: [deprecatedCalendarRoute,
                                                         calendarRoute,
                                                         uiRoute,
                                                         registerRoute])
