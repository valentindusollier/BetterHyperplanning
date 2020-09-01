import Logging
import PerfectHTTPServer

#if os(Linux)
    import FoundationNetworking
#endif

fileprivate let logger = Logger(label: "root")

logger.info("Initializing the server...")

try HTTPServer.launch(name: "httpserver", port: 8000, routes: [calendarRoute, uiRoute])
