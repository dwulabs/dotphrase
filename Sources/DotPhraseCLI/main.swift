import Foundation
import DotPhraseCore

// Simple CLI to exercise phrase loading + search.
// Usage:
//   swift run dotphrase <query>
// Example:
//   swift run dotphrase g

func eprint(_ s: String) {
    FileHandle.standardError.write((s + "\n").data(using: .utf8)!)
}

let args = CommandLine.arguments

guard args.count >= 2 else {
    eprint("Usage: dotphrase <query>")
    exit(2)
}

let query = args[1]

let fm = FileManager.default
let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
let phrasesURL = cwd
    .appendingPathComponent("resources")
    .appendingPathComponent("phrases.sample.json")

let store: PhraseStore

do {
    store = try PhraseStore.loadJSON(from: phrasesURL)
} catch {
    eprint("Failed to load phrases from \(phrasesURL.path): \(error)")
    exit(1)
}

let matches = store.search(query, limit: 10)

if matches.isEmpty {
    print("(no matches)")
    exit(0)
}

for (i, p) in matches.enumerated() {
    let desc = p.description ?? ""
    print(String(format: "%2d  .%-12s  %s", i + 1, (p.trigger as NSString).utf8String!, (desc as NSString).utf8String!))
}
