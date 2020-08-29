//
//  Route.swift
//  BetterHyperplanning
//
//  Created by Valentin Dusollier on 28/08/2020.
//

import Foundation
import Logging
import PerfectHTTP

fileprivate let logger = Logger(label: "http server")


let route = Route(method: .get, uri: "/", handler: { request, response in
    response.setBody(string: "200 OK")
    response.completed(status: .ok)
})
