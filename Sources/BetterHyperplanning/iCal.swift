//
//  iCal.swift
//  BetterHyperplanning
//
//  Created by Valentin Dusollier on 28/08/2020.
//

import Foundation
import Logging
import iCalKit

fileprivate let logger = Logger(label: "iCal")

func loadCalendar(byURL url: URL) throws -> iCalKit.Calendar? {
    let calendars = try iCal.load(url: url)
    return calendars.first
}

func format(description: String) -> (isCancelled: Bool, code: String, title: String, salle: String?, type: String, memo: String?, td: String?, others : [String: String])? {
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

func format(summary: String) -> (code: String, title: String, type: String, isCanceled: Bool, subjectPublic: [String])? {
    var summary = summary
    var isCanceled = false
    
    if summary.starts(with: "ANNULÉ : ") {
        let index = summary.index(summary.startIndex, offsetBy: 9)
        summary = String(summary.suffix(from: index))
        isCanceled = true
    }
    
    let regex = try! NSRegularExpression(pattern: "<\\.[A-Z0-9]+ - [^<]+> [^,-]+,?")
    let subjectPublic = regex.matches(in: summary, range: NSRange(summary.startIndex..., in: summary)).map { String(summary[Range($0.range, in: summary)!]) }
    if !subjectPublic.isEmpty {
        summary = summary.replacingOccurrences(of: Array(subjectPublic.suffix(from: 1)).reduce(subjectPublic.first!, { (result, str) in
            return "\(result) \(str)"
        }) + "- ", with: "")
    }
    
    guard let range1 = summary.range(of: " - ") else {
        return nil
    }
    
    let code = String(summary.prefix(upTo: range1.lowerBound))
    summary = String(summary.suffix(from: range1.upperBound))
    
    if !code.isSubjectCode() {
        return nil
    }
    
    guard let range2 = summary.range(of: " - ", options: .backwards) else {
        return nil
    }
    
    let type = String(summary.suffix(from: range2.upperBound))
    let title = String(summary.prefix(upTo: range2.lowerBound))
    
    return (code: code, title: title, type: type, isCanceled: isCanceled, subjectPublic: subjectPublic)
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
