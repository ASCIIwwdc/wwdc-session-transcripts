#!/usr/bin/swift

import Foundation

// process arguments
enum Mode: String {
    case info, sessions
}

let filename: String
let lineBreak = "\r\n"
let mode: Mode

switch Process.arguments.count {
case 2:
    filename = Process.arguments[1]
    mode = .info
case 3 where Mode(rawValue: Process.arguments[2]) != nil:
    filename = Process.arguments[1]
    mode = Mode(rawValue: Process.arguments[2])!
default:
    print(
        "\nUsage: parse_sessions.swift path [mode]\n" +
        "\n" +
        "Valid modes:\n" +
        "   - sessions\n" +
        "   - info" as String
    )
    exit(0)
}

// load and parse data
@noreturn
func exitWithError(error: String) {
    print(error)
    exit(1)
}

guard let data = NSData(contentsOfFile: filename)
    else {
    exitWithError("Error: Couldn't open '\(filename)'")
}

typealias JSONDict = [String: AnyObject]

guard let
    jsonDict = try! NSJSONSerialization.JSONObjectWithData(data, options: []) as? JSONDict,
    responseDict = jsonDict["response"] as? JSONDict,
    sessionData = responseDict["sessions"] as? [JSONDict]
    else {
    exitWithError("Error: Couldn't parse JSON in '\(filename)'")
}

/// A single WWDC session
struct Session : CustomStringConvertible {
    var number: Int
    var title: String
    var track: String
    var desc: String
    
    var description: String {
        let lines = ["\(number):",
                     "  :title: \(title)",
                     "  :track: \(track)",
                     "  :description: \(desc)"
        ]
        return lines.joinWithSeparator(lineBreak)
    }
}



// process JSON into list of sessions
let sessions: [Session] = sessionData
    .filter {
        return ($0["type"] as? String) != "Lab"
    }
    .flatMap {
        guard let numberString = ($0["id"] ?? $0["number"]) as? String
            else { return nil }
        
        guard let
            type = $0["type"]! as? String,
            number = Int(numberString),
            title = $0["title"] as? String,
            track = $0["track"] as? String,
            desc = $0["description"] as? String
            else { return nil }

        let filteredTitle = title
            .stringByReplacingOccurrencesOfString(":", withString: "&#58;")
            .stringByReplacingOccurrencesOfString("\"", withString: "&quot;")
        
        let filteredDesc = desc
            .stringByReplacingOccurrencesOfString(":", withString: "&#58;")
            .stringByReplacingOccurrencesOfString("\"", withString: "&quot;")
        
        return Session(number: number, title: filteredTitle, track: track, desc: filteredDesc)
    }

// derive tracks and types
let tracks = Set(sessions.lazy.map { $0.track })
let types = Set(sessionData.lazy.flatMap { $0["type"] as? String })

// output
switch mode {
case .sessions:
    let sortedSessions = sessions.sort { $0.number < $1.number }
    print(sortedSessions.map({ "\($0)" }).joinWithSeparator(lineBreak))
case .info:
    print("\(sessions.count) sessions")
    print("Tracks: \(tracks.sort().joinWithSeparator(", "))")
    print("Types: \(types.sort().joinWithSeparator(", "))")
}

