//
//  Route.swift
//  BetterHyperplanning
//
//  Created by Valentin Dusollier on 28/08/2020.
//

import Foundation
import Logging
import PerfectHTTP
import iCalKit

fileprivate let logger = Logger(label: "http server")


let route = Route(method: .get, uri: "/", handler: { request, response in
    
    logger.info("New request with \(request.uri)")
    
    //MARK: Parsing URL and loading Calendar
    guard let urlString = request.param(name: "url") else {
        let message = "The 'url' parameter is missing in the query..."
        logger.info(Logger.Message(stringLiteral: message))
        response.setBody(string: message)
        response.completed(status: .badRequest)
        return
    }
    
    guard let url = URL(string: urlString) else {
        let message = "The given url isn't a well formated one..."
        logger.info(Logger.Message(stringLiteral: message))
        response.setBody(string: message)
        response.completed(status: .badRequest)
        return
    }
    
    var loadedCalendar: iCalKit.Calendar?
    
    do {
        print(url)
        loadedCalendar = try loadCalendar(byURL: url)
    } catch {
        logger.error(Logger.Message(stringLiteral: error.localizedDescription))
        response.setBody(string: "An error occurred when loading calendar : \(error)")
        response.completed(status: .internalServerError)
        return
    }
    
    guard let rawCalendar = loadedCalendar else {
        let message = "The content of the given url must contain one iCal Calendar..."
        logger.info(Logger.Message(stringLiteral: message))
        response.setBody(string: message)
        response.completed(status: .notFound)
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
                logger.info(Logger.Message(stringLiteral: message))
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
                logger.info(Logger.Message(stringLiteral: message))
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
    
    //MARK: Browsing the raw calendar to build the cleaned one
    var events = [Event]()
    
    for subComponent in rawCalendar.subComponents {
        if subComponent is Event {
            let event = subComponent as! Event
            
            guard let summary = event.summary else {
                events.append(event)
                continue
            }
            
            guard let formatedSummary = format(summary: summary) else {
                events.append(event)
                continue
            }
            
            let code = formatedSummary.code
            
            if !ignoreCodes.contains(code) {
                let title = subjectsDictionnary[code] ?? formatedSummary.title
                
                events.append(Event(uid: event.uid,
                                    dtstamp: event.dtend,
                                    location: event.location,
                                    summary: "\(title) - \(formatedSummary.type)",
                                    descr: event.descr,
                                    isCancelled: formatedSummary.isCanceled,
                                    dtstart: event.dtstart,
                                    dtend: event.dtend))
            }
            
        }
    }
    
    let newCalendar = iCalKit.Calendar(withComponents: events)
    
    response.setBody(string: newCalendar.toCal())
    response.completed(status: .ok)
})
