//
//  Session.swift
//  BetterHyperplanning
//
//  Created by Valentin Dusollier on 04/02/2021.
//

import Foundation

public struct CalendarPreference: Codable {
    let url: String
    let ignore: [String]
    let subjects: [String: String]
}

public typealias Preference = [CalendarPreference]

public enum PreferencesError: Error {
    case preferencesDecodingFailed(error: Error)
    case badPath
}

public typealias Preferences = Dictionary<UUID, Preference>

extension Preferences {
    
    public init(path: String) throws {
        guard let xml = FileManager.default.contents(atPath: path) else {
            throw PreferencesError.badPath
        }
        
        let sessions = try JSONDecoder().decode([UUID: Preference].self, from: xml)
        
        self.init()
        self = sessions
    }
    
    public func save(atPath path: String) throws {
        guard let url = URL(string: "file://\(path)") else {
            throw PreferencesError.badPath
        }
        
        let data = try JSONEncoder().encode(self)
        try data.write(to: url)
    }
    
}
