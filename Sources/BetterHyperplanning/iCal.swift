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
    
    guard let range2 = summary.range(of: " - ", options: .backwards) else {
        return nil
    }
    
    let type = String(summary.suffix(from: range2.upperBound))
    let title = String(summary.prefix(upTo: range2.lowerBound))
    
    return (code: code, title: title, type: type, isCanceled: isCanceled, subjectPublic: subjectPublic)
}

extension String {
    func isSubjectCode() -> Bool {
        let regex = "[A-Z]-[A-Z]{4}-[0-9]{3}"

        let predicate = NSPredicate(format:"SELF MATCHES %@", regex)
        return predicate.evaluate(with: self)
    }
}
