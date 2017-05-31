//
//  SwiftFormat.swift
//  SwiftFormat
//
//  Created by Nick Lockwood on 12/08/2016.
//  Copyright 2016 Nick Lockwood
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/SwiftFormat
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

import Foundation

/// The current SwiftFormat version
public let version = "0.28.6"

/// An enumeration of the types of error that may be thrown by SwiftFormat
public enum FormatError: Error, CustomStringConvertible {
    case reading(String)
    case writing(String)
    case parsing(String)
    case options(String)

    public var description: String {
        switch self {
        case let .reading(string),
             let .writing(string),
             let .parsing(string),
             let .options(string):
            return string
        }
    }
}

/// File enumeration options
public struct FileOptions {
    public var followSymlinks: Bool
    public var supportedFileExtensions: [String]

    public init(followSymlinks: Bool = false,
                supportedFileExtensions: [String] = ["swift"]) {

        self.followSymlinks = followSymlinks
        self.supportedFileExtensions = supportedFileExtensions
    }
}

/// Enumerate all swift files at the specified location and (optionally) calculate an output file URL for each.
/// Ignores the file if any of the excluded file URLs is a prefix of the input file URL.
///
/// Files are enumerated concurrently. For convenience, the enumeration block returns a completion block, which
/// will be executed synchronously on the calling thread once enumeration is complete.
///
/// Errors may be thrown by either the enumeration block or the completion block, and are gathered into an
/// array and returned after enumeration is complete, along with any errors generated by the function itself.
/// Throwing an error from inside either block does *not* terminate the enumeration.
public func enumerateFiles(withInputURL inputURL: URL,
                           excluding excludedURLs: [URL] = [],
                           outputURL: URL? = nil,
                           options: FileOptions = FileOptions(),
                           concurrent: Bool = true,
                           block: @escaping (URL, URL) throws -> () throws -> Void) -> [Error] {

    guard let resourceValues = try? inputURL.resourceValues(
        forKeys: Set([.isDirectoryKey, .isAliasFileKey, .isSymbolicLinkKey])) else {
        if FileManager.default.fileExists(atPath: inputURL.path) {
            return [FormatError.reading("failed to read attributes for \(inputURL.path)")]
        }
        return [FormatError.options("file not found at \(inputURL.path)")]
    }
    if !options.followSymlinks &&
        (resourceValues.isAliasFile == true || resourceValues.isSymbolicLink == true) {
        return [FormatError.options("symbolic link or alias was skipped: \(inputURL.path)")]
    }
    if resourceValues.isDirectory == false &&
        !options.supportedFileExtensions.contains(inputURL.pathExtension) {
        return [FormatError.options("unsupported file type: \(inputURL.path)")]
    }

    let group = DispatchGroup()
    var completionBlocks = [() throws -> Void]()
    let completionQueue = DispatchQueue(label: "swiftformat.enumeration")
    func onComplete(_ block: @escaping () throws -> Void) {
        completionQueue.async(group: group) {
            completionBlocks.append(block)
        }
    }

    let manager = FileManager.default
    let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isAliasFileKey, .isSymbolicLinkKey]
    let queue = concurrent ? DispatchQueue.global(qos: .userInitiated) : completionQueue

    func enumerate(inputURL: URL,
                   outputURL: URL?,
                   options: FileOptions,
                   block: @escaping (URL, URL) throws -> () throws -> Void) {

        for excludedURL in excludedURLs {
            if inputURL.absoluteString.hasPrefix(excludedURL.absoluteString) {
                return
            }
        }
        guard let resourceValues = try? inputURL.resourceValues(forKeys: Set(keys)) else {
            onComplete { throw FormatError.reading("failed to read attributes for \(inputURL.path)") }
            return
        }
        if resourceValues.isRegularFile == true {
            if options.supportedFileExtensions.contains(inputURL.pathExtension) {
                do {
                    onComplete(try block(inputURL, outputURL ?? inputURL))
                } catch {
                    onComplete { throw error }
                }
            }
        } else if resourceValues.isDirectory == true {
            guard let files = try? manager.contentsOfDirectory(
                at: inputURL, includingPropertiesForKeys: keys, options: .skipsHiddenFiles) else {
                onComplete { throw FormatError.reading("failed to read contents of directory at \(inputURL.path)") }
                return
            }
            for url in files {
                queue.async(group: group) {
                    let outputURL = outputURL.map {
                        URL(fileURLWithPath: $0.path + url.path.substring(from: inputURL.path.characters.endIndex))
                    }
                    enumerate(inputURL: url, outputURL: outputURL, options: options, block: block)
                }
            }
        } else if options.followSymlinks &&
            (resourceValues.isSymbolicLink == true || resourceValues.isAliasFile == true) {
            let resolvedURL = inputURL.resolvingSymlinksInPath()
            enumerate(inputURL: resolvedURL, outputURL: outputURL, options: options, block: block)
        }
    }

    queue.async(group: group) {
        if !manager.fileExists(atPath: inputURL.path) {
            onComplete { throw FormatError.options("file not found at \(inputURL.path)") }
            return
        }
        enumerate(inputURL: inputURL, outputURL: outputURL, options: options, block: block)
    }
    group.wait()

    var errors = [Error]()
    for block in completionBlocks {
        do {
            try block()
        } catch {
            errors.append(error)
        }
    }
    return errors
}

/// Get line/column offset for token
/// Note: line indexes start at 1, columns start at zero
public func offsetForToken(at index: Int, in tokens: [Token]) -> (line: Int, column: Int) {
    var line = 1, column = 0
    for token in tokens[0 ..< index] {
        if token.isLinebreak {
            line += 1
            column = 0
        } else {
            column += token.string.characters.count
        }
    }
    return (line, column)
}

/// Process parsing errors
public func parsingError(for tokens: [Token], options: FormatOptions) -> FormatError? {
    if let index = tokens.index(where: {
        guard options.fragment || !$0.isError else { return true }
        guard !options.ignoreConflictMarkers, case let .operator(string, _) = $0 else { return false }
        return string.hasPrefix("<<<<<") || string.hasPrefix("=====") || string.hasPrefix(">>>>>")
    }) {
        let message: String
        switch tokens[index] {
        case .error(""):
            message = "unexpected end of file"
        case let .error(string):
            message = "unexpected token \(string)"
        case let .operator(string, _):
            message = "found conflict marker \(string)"
        default:
            preconditionFailure()
        }
        let (line, column) = offsetForToken(at: index, in: tokens)
        return .parsing("\(message) at \(line):\(column)")
    }
    return nil
}

/// Convert a token array back into a string
public func sourceCode(for tokens: [Token]) -> String {
    var output = ""
    for token in tokens { output += token.string }
    return output
}

/// Apply specified rules to a token array with optional callback
/// Useful for perfoming additional logic after each rule is applied
public func applyRules(_ rules: [FormatRule],
                       to tokens: inout [Token],
                       with options: FormatOptions,
                       callback: ((Int, [Token]) -> Void)? = nil) throws {
    // Parse
    if let error = parsingError(for: tokens, options: options) {
        throw error
    }

    // Recursively apply rules until no changes are detected
    var options = options
    for _ in 0 ..< 10 {
        let formatter = Formatter(tokens, options: options)
        for (i, rule) in rules.enumerated() {
            rule(formatter)
            callback?(i, formatter.tokens)
        }
        if tokens == formatter.tokens {
            return
        }
        tokens = formatter.tokens
        options.fileHeader = nil // Prevents infinite recursion
    }
    throw FormatError.writing("failed to terminate")
}

/// Format a pre-parsed token array
/// Returns the formatted token array, and the number of edits made
public func format(_ tokens: [Token],
                   rules: [FormatRule] = FormatRules.default,
                   options: FormatOptions = FormatOptions()) throws -> [Token] {

    var tokens = tokens
    try applyRules(rules, to: &tokens, with: options)
    return tokens
}

/// Format code with specified rules and options
public func format(_ source: String,
                   rules: [FormatRule] = FormatRules.default,
                   options: FormatOptions = FormatOptions()) throws -> String {

    return sourceCode(for: try format(tokenize(source), rules: rules, options: options))
}
