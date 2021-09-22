//
//  Routes.swift
//  BetterHyperplanning
//
//  Created by Valentin Dusollier on 28/08/2020.
//

import Foundation
import Logging
import PerfectHTTP
import iCalKit
import HTMLEntities

let iCalLogger = Logger(label: "iCal server")

// This route is needed for compatiblity reasons
let deprecatedCalendarRoute = Route(method: .get, uri: "/", handler: { request, response in
    
    iCalLogger.info("Depracted request with \(request.uri)")
    
    guard let url = request.param(name: "url") else {
        response.closeWithError(message(fromError: .missParameters(parameters: ["url"])))
        return
    }
    
    let jsonDecoder = JSONDecoder()
    var ignore = [String]()
    var subjects = [String: String]()
    
    if let ignoreParam = request.param(name: "ignore")?.data(using: .utf8) {
        do {
            ignore = try jsonDecoder.decode([String].self, from: ignoreParam)
        } catch {
            response.closeWithError("The following error happened : \(error)", status: .internalServerError)
            return
        }
    }
    
    if let subjectsParam = request.param(name: "subjects")?.data(using: .utf8) {
        do {
            subjects = try jsonDecoder.decode([String: String].self, from: subjectsParam)
        } catch {
            response.closeWithError("The following error happened : \(error)", status: .internalServerError)
            return
        }
    }
    
    do {
        let preference = [CalendarPreference(url: url,
                                             ignore: ignore,
                                             subjects: subjects)]
        let calendar = try buildCalendar(withPreference: preference, ignoreDuplicates: false)
        response.setBody(string: calendar.toCal())
        response.completed(status: .ok)
    } catch {
        guard let calendarError = error as? CalendarError else {
            response.closeWithError("The following error happened : \(error)", status: .internalServerError)
            return
        }
        response.closeWithError(message(fromError: calendarError))
    }
})

let calendarRoute = Route(method: .get, uri: "/v2/", handler: { request, response in
    
    let ignoreDuplicates = request.param(name: "ignoreDuplicates") != nil
    
    guard let preferenceID = request.param(name: "preferenceID") else {
        response.closeWithError(message(fromError: .missParameters(parameters: ["preferenceID"])))
        return
    }
    
    guard let preferenceUUID = UUID(uuidString: preferenceID),
          let preference = preferences[preferenceUUID] else {
        response.closeWithError(message(fromError: .badPreferenceID))
        return
    }
    
    iCalLogger.info("New request for \(preferenceUUID) preference.")
    
    do {
        let calendar = try buildCalendar(withPreference: preference, ignoreDuplicates: ignoreDuplicates)
        response.setBody(string: calendar.toCal())
        response.completed(status: .ok)
    } catch {
        guard let calendarError = error as? CalendarError else {
            response.closeWithError("The following error happened : \(error)", status: .internalServerError)
            return
        }
        response.closeWithError(message(fromError: calendarError))
    }
})

let uiRoute = Route(method: .get, uri: "/subjects/", handler: { request, response in
    
    // Setting up headers to allow cross-origin request
    response.setHeader(.accessControlAllowOrigin, value: "*")

    // Parsing URL and loading Calendar
    
    guard let url = request.param(name: "url") else {
        response.closeWithError(message(fromError: .missParameters(parameters: ["url"])))
        return
    }
    
    iCalLogger.info("UI request for \(url)")
    
    let calendar: iCalKit.Calendar
    
    do {
        calendar = try loadCalendar(url: url)
    } catch {
        guard let calendarError = error as? CalendarError else {
            response.closeWithError("The following error happened : \(error)", status: .internalServerError)
            return
        }
        response.closeWithError(message(fromError: calendarError))
        return
    }

    // Browsing the calendar to retrieve the code and title of each subject
    var subjects = [String: String]()

    for subComponent in calendar.subComponents {
        if subComponent is Event {
            let event = subComponent as! Event

            guard let description = event.descr else {
                continue
            }

            guard let formatedDescription = format(description: description) else {
                continue
            }

            let code = formatedDescription.code
            let title = formatedDescription.title

            if subjects.keys.contains(code) {
                if title.count < subjects[code]!.count {
                    subjects[code] = title
                }
            } else {
                subjects[code] = title
            }

        }
    }

    //Encode HTML Entities
    subjects = subjects.mapValues({$0.htmlEscape()})

    do {
        let data = try JSONEncoder().encode(subjects)

        guard let rep = String(data: data, encoding: .utf8) else {
            response.closeWithError("The server cannot decode the JSON response...", status: .internalServerError)
            return
        }

        response.setBody(string: rep)
        response.completed(status: .ok)
    } catch {
        response.closeWithError(message(fromError: .coding(error: error)))
    }
    
})

let registerRoute = Route(method: .post, uri: "/register/", handler: { request, response in
    
    // Setting up headers to allow cross-origin request
    response.setHeader(.accessControlAllowOrigin, value: "*")
    
    guard let body = request.postBodyBytes else {
        response.closeWithError(message(fromError: .notValideRegisterBody))
        return
    }
    
    let preference: Preference
    
    do {
        preference = try JSONDecoder().decode(Preference.self, from: Data(body))
    } catch {
        response.closeWithError(message(fromError: .coding(error: error)))
        return
    }
    
    let uuid = UUID()
    
    preferences[uuid] = preference
    
    do {
        try preferences.save(atPath: preferencesPath)
        response.setBody(string: uuid.uuidString)
        response.completed(status: .ok)
        iCalLogger.info("Register \(uuid) preference's")
    } catch {
        response.closeWithError(message(fromError: .registerFailed(error: error)))
    }
})
