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

fileprivate let logger = Logger(label: "http server")

let calendarRoute = Route(method: .get, uri: "/", handler: { request, response in
    
    logger.info("New request with \(request.uri)")
    
    //MARK: Parsing URL and loading Calendar
    guard let rawCalendar = getCalendar(request.param(name: "url"), response: response) else {
        return
    }
    
    //MARK: Parsing ignore parameter
    let decoder = JSONDecoder()
    
    var ignore = request.param(name: "ignore")
    var ignoreCodes = [String]()
    
    if ignore != nil {
        do {
            guard let data = ignore!.data(using: .utf8) else {
                let message = "The 'ignore' parameter cannot be encoded in UTF8..."
                logger.error(Logger.Message(stringLiteral: message))
                response.setBody(string: message)
                response.completed(status: .internalServerError)
                return
            }
            
            ignoreCodes = try decoder.decode([String].self, from: data)
        } catch {
            logger.error(Logger.Message(stringLiteral: error.localizedDescription))
            print(error)
            response.setBody(string: "An error occurred when decoding JSON...\nThe 'ignore' parameter must be a JSON list of String.")
            response.completed(status: .preconditionFailed)
            return
        }
    }
    
    //MARK: Parsing subjects parameter
    let subjects = request.param(name: "subjects")
    var subjectsDictionnary = [String: String]()
    
    if subjects != nil {
        do {
            guard let data = subjects!.data(using: .utf8) else {
                let message = "The 'subjects' parameter cannot be encoded in UTF8..."
                logger.error(Logger.Message(stringLiteral: message))
                response.setBody(string: message)
                response.completed(status: .internalServerError)
                return
            }
            
            subjectsDictionnary = try decoder.decode([String: String].self, from: data)
        } catch {
            logger.error(Logger.Message(stringLiteral: error.localizedDescription))
            print(error)
            response.setBody(string: "An error occurred when decoding JSON...\nThe 'subjects' parameter must be a JSON dictionnary with String keys and values.")
            response.completed(status: .preconditionFailed)
            return
        }
    }
    
    //Decode HTML entities
    subjectsDictionnary = subjectsDictionnary.mapValues({$0.htmlUnescape()})
    
    //MARK: Browsing the raw calendar to build the cleaned one
    var events = [Event]()
    
    for subComponent in rawCalendar.subComponents {
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
            
            if !ignoreCodes.contains(code) {
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
    
    let newCalendar = iCalKit.Calendar(withComponents: events)
    
    response.setBody(string: newCalendar.toCal())
    response.completed(status: .ok)
})

let uiRoute = Route(method: .get, uri: "/subjects/", handler: { request, response in
    
    logger.info("New UI request with \(request.uri)")
    
    //MARK: Setting up headers to allow cross-origin request
    response.setHeader(.accessControlAllowOrigin, value: "*")
    
    //MARK: Parsing URL and loading Calendar
    guard let rawCalendar = getCalendar(request.param(name: "url"), response: response) else {
        return
    }
    
    //MARK: Browsing the raw calendar to retrieve the code and title of each subject
    var subjects = [String: String]()
    
    for subComponent in rawCalendar.subComponents {
        if subComponent is Event {
            let event = subComponent as! Event
            
            guard let summary = event.summary else {
                continue
            }
            
            guard let formatedSummary = format(summary: summary) else {
                continue
            }
            
            let code = formatedSummary.code
            let title = formatedSummary.title
            
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
            let message = "The server cannot decode the JSON response..."
            logger.error(Logger.Message(stringLiteral: message))
            response.setBody(string: message)
            response.completed(status: .internalServerError)
            return
        }
        
        response.setBody(string: rep)
        response.completed(status: .ok)
    } catch {
        logger.error(Logger.Message(stringLiteral: error.localizedDescription))
        print(error)
        response.setBody(string: "An error occurred when encoding the JSON response...")
        response.completed(status: .internalServerError)
        return
    }
    
})

func getCalendar(_ opt_url: String?, response: HTTPResponse) -> iCalKit.Calendar? {
    //MARK: Parsing URL and loading Calendar
    guard let urlString = opt_url else {
        let message = "The 'url' parameter is missing in the query..."
        logger.error(Logger.Message(stringLiteral: message))
        response.setBody(string: message)
        response.completed(status: .badRequest)
        return nil
    }
    
    if !urlString.isHyperplanningURLFormat() {
        let message = "The given url isn't a hyperplanning one..."
        logger.error(Logger.Message(stringLiteral: message))
        response.setBody(string: message)
        response.completed(status: .preconditionFailed)
        return nil
    }
    
    guard let url = URL(string: urlString) else {
        let message = "The given url isn't a well formated one..."
        logger.error(Logger.Message(stringLiteral: message))
        response.setBody(string: message)
        response.completed(status: .badRequest)
        return nil
    }
    
    var loadedCalendar: iCalKit.Calendar?
    
    do {
        loadedCalendar = try loadCalendar(byURL: url)
    } catch {
        logger.error(Logger.Message(stringLiteral: error.localizedDescription))
        response.setBody(string: "An error occurred when loading calendar : \(error)")
        response.completed(status: .notFound)
        return nil
    }
    
    guard let rawCalendar = loadedCalendar else {
        let message = "The content of the given url must contain at least one iCal Calendar..."
        logger.error(Logger.Message(stringLiteral: message))
        response.setBody(string: message)
        response.completed(status: .notFound)
        return nil
    }
    
    return rawCalendar
}
