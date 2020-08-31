import Logging
import PerfectHTTPServer

fileprivate let logger = Logger(label: "root")

logger.info("Initializing the server...")

print("dzdz".isSubjectCode())
print("S-MATH-987".isSubjectCode())

try HTTPServer.launch(name: "httpserver", port: 8000, routes: [calendarRoute, uiRoute])
