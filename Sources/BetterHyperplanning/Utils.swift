//
//  iCal.swift
//  BetterHyperplanning
//
//  Created by Valentin Dusollier on 28/08/2020.
//

import Foundation
import Logging
import PerfectHTTP
import iCalKit

public enum CalendarError: Error {
    case notHyperplanningURL
    case badFormattedURL
    case coding(error: Error)
    case emptyiCalCalendar
    case missParameters(parameters: [String])
    case badPreferenceID
    case notValideRegisterBody
    case registerFailed(error: Error)
}

public func message(fromError error: CalendarError) -> (message: String, status: HTTPResponseStatus) {
    switch error {
    case .notHyperplanningURL:
        return ("The given url isn't a hyperplanning one...", .preconditionFailed)
    case .badFormattedURL:
        return ("The given url isn't a well formated one...", .badRequest)
    case .coding(let error):
        return ("An error occurred when loading calendar : \(error)", .internalServerError)
    case .emptyiCalCalendar:
        return ("The content of the given url must contain at least one iCal Calendar...", .notFound)
    case .missParameters(let parameters):
        return ("One of the following parameters are missing : \(parameters.joined(separator: ", "))", .preconditionFailed)
    case .badPreferenceID:
        return ("Your preference id is not valid...", .notFound)
    case .notValideRegisterBody:
        return ("The register body is not valid...", .preconditionFailed)
    case .registerFailed(let error):
        return ("The register failed : \(error)", .internalServerError)
    }
}

public func loadCalendar(url urlString: String) throws -> iCalKit.Calendar {
    // Parsing URL and loading Calendar
    
    if !urlString.isHyperplanningURLFormat() {
        throw CalendarError.notHyperplanningURL
    }
    
    guard let url = URL(string: urlString) else {
        throw CalendarError.badFormattedURL
    }
    
    var calendars: [iCalKit.Calendar]
    
    do {
        calendars = try iCal.load(url: url)
    } catch {
        throw CalendarError.coding(error: error)
    }
    
    guard let calendar = calendars.first else {
        throw CalendarError.emptyiCalCalendar
    }
    
    return calendar
}

public func buildCalendar(withPreference preference: Preference) throws -> iCalKit.Calendar {
    var events = [Event]()
    
    for calendarPreference in preference {
        
        //Decode HTML entities
        let subjectsDictionnary = calendarPreference.subjects.mapValues({$0.htmlUnescape()})
        
        let calendar = try loadCalendar(url: calendarPreference.url)
        
        // Browsing this raw calendar to add events to the cleaned one
        for subComponent in calendar.subComponents {
            if subComponent is Event {
                let event = subComponent as! Event
                
                guard let description = event.descr else {
                    events.append(event)
                    continue
                }
                
                guard let formatedDescription = format(description: description) else {
                    events.append(event)
                    continue
                }
                
                let code = formatedDescription.code
                
                if !calendarPreference.ignore.contains(code) {
                    let title = subjectsDictionnary[code] ?? formatedDescription.title
                    
                    events.append(Event(uid: event.uid,
                                        dtstamp: event.dtend,
                                        location: event.location,
                                        summary: "\(title)\(formatedDescription.memo != nil ? " - \(formatedDescription.memo!)" : "") - \(formatedDescription.type)",
                                        descr: event.descr,
                                        isCancelled: formatedDescription.isCancelled,
                                        dtstart: event.dtstart,
                                        dtend: event.dtend))
                }
                
            }
        }
        
    }
    
    return iCalKit.Calendar(withComponents: events)
}

extension HTTPResponse {
    
    func closeWithError(_ message: String, status: HTTPResponseStatus) {
        iCalLogger.error(Logger.Message(stringLiteral: message))
        self.setBody(string: message)
        self.completed(status: status)
    }
    func closeWithError(_ tuple: (String, HTTPResponseStatus)) {
        self.closeWithError(tuple.0, status: tuple.1)
    }
}

public func format(description: String) -> (isCancelled: Bool, code: String, title: String, salle: String?, type: String, memo: String?, td: String?, others : [String: String])? {
    let lines = description.components(separatedBy: "\\n")
    let splittedLines = lines.map { str -> (key: String, value: String)? in
        if let range = str.range(of: " : ") {
            let key = String(str[..<range.lowerBound])
            let value = String(str[range.upperBound...])
            return (key, value)
        }
        return nil
    }
    
    var isCancelled = false
    var code: String? = nil
    var title: String? = nil
    var salle: String? = nil
    var type: String? = nil
    var memo: String? = nil
    var td: String? = nil
    var others = [String: String]()
    
    for splittedLine in splittedLines {
        guard let (key, value) = splittedLine else {
            continue
        }
        switch key {
        case "ANNULÉ":
            isCancelled = true
        case "Matière":
            guard let range = value.range(of: " - ") else {
                continue
            }
            code = String(value.prefix(upTo: range.lowerBound))
            title = String(value.suffix(from: range.upperBound))
        case "Salle":
            salle = value
        case "Type":
            type = value
        case "Mémo":
            memo = value
        case "TD":
            td = value
        default:
            others[key] = value
        }
    }
    
    if code == nil || title == nil || type == nil {
        return nil
    }
    
    return (isCancelled: isCancelled, code: code!, title: title!, salle: salle, type: type!, memo: memo, td: td, others : others)
}

extension String {
    func evaluate(regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
    
    func isSubjectCode() -> Bool {
        return self.evaluate(regex: "[A-Z]-[A-Z]{4}-[0-9]{3}")
    }
    
    func isHyperplanningURLFormat() -> Bool {
        return self.contains(string: "https://hplanning")
    }
}
