//
//  Rules+TCA.swift
//  SwiftFormat
//
//  Created by andrew on 2/3/24.
//  Copyright © 2024 Nick Lockwood. All rights reserved.
//

import Foundation

extension _FormatRules {

        public static let _tcaScopeStoreWithKeyPaths = FormatRule(
            help:"""
            TCA 1.5
            Prior to version 1.5 of the Composable Architecture, one was allowed to scope(state:action:) a store with any kind of closures that transform the parent state to the child state, and child actions into parent actions:
            ```swift
            store.scope(
              state: (State) -> ChildState,
              action: (ChildAction) -> Action
            )
            ```
            In practice you could typically use key paths for the state transformation since key path literals can be promoted to closures. That means often scoping looked something like this:
            ```swift
            // ⚠️ Deprecated API
            ChildView(
              store: store.scope(
                state: \\.child,
                action: { .child($0) }
              )
            )
            ```
            
            However, as of version 1.5 of the Composable Architecture, the version of scope(state:action:) that takes two closures is soft-deprecated. Instead, you are to use the version of scope(state:action:) that takes a key path for the state argument, and a case key path for the action argument.
            ```swift
            // ✅ New API
            ChildView(
              store: store.scope(
                state: \\.child,
                action: \\.child
              )
            )
            ```
            """
        ) { formatter in
            
            formatter.forEach(.identifier("scope")) { scopeIndex, token in
                guard let scopeOpenParen = formatter.nextIndexedToken(of: .startOfScope, after: scopeIndex), scopeOpenParen.token == .startOfScope("("), let scopeCloseParenIndex = formatter.endOfScope(at: scopeOpenParen.index) else {
                    return
                }
                let scopeParenIndexRange: CountableRange = scopeOpenParen.index ..< (scopeCloseParenIndex + 1)
                
                let rangeTokens = scopeParenIndexRange.reduce(into: [(Int, String)](), { (acc, next) in
                    acc.append((next, formatter.tokens[next].string))
                })
                
                func closureToKeyPath(startIndex: Int) {
                    guard let endIndex = formatter.endOfScope(at: startIndex) else {
                        return
                    }
                    guard let next = formatter.nextIndexedToken(after: startIndex, where: { !$0.isSpaceOrCommentOrLinebreak }) else {
                        return
                    }
                    if next.token.isAnonymousParameter {
                        if let nextAfterAnonymousParameter = formatter.nextIndexedToken(after: next.index, where: { !$0.isSpaceOrCommentOrLinebreak }), nextAfterAnonymousParameter.index == endIndex {
                            formatter.replaceTokens(in: startIndex..<(endIndex + 1), with: [.operator("\\", .prefix), .operator(".", .prefix), .identifier("self")])
                        } else {
                            formatter.removeToken(at: endIndex)
                            formatter.replaceToken(at: next.index, with: .operator("\\", .prefix))
                            formatter.removeToken(at: startIndex)
                        }
                    } else if tokenIsTypeIdentifier(token: next.token) {
                        if functionClosureToKeyPath(startIndex: next.index, startToken: next.token, removing: nil),
                            let newEndIndex = formatter.endOfScope(at: startIndex) {
                            formatter.removeToken(at: newEndIndex)
                            formatter.removeToken(at: startIndex)
                        }
                    } else if next.token.isIdentifier,
                              let inKeyWord = formatter.nextIndexedToken(after: next.index, where: { !$0.isSpaceOrCommentOrLinebreak }),
                              inKeyWord.token == .keyword("in"),
                              let namedParameterCallSite = formatter.nextIndexedToken(after: inKeyWord.index, where: { !$0.isSpaceOrCommentOrLinebreak }),
                              namedParameterCallSite.token == next.token {
                        formatter.removeToken(at: endIndex)
                        formatter.replaceToken(at: namedParameterCallSite.index, with: .operator("\\", .prefix))
                        formatter.removeToken(at: inKeyWord.index)
                        formatter.removeToken(at: next.index)
                        formatter.removeToken(at: startIndex)
                    }
                }
                
                func tokenIsTypeIdentifier(token: Token) -> Bool {
                    guard token.isIdentifier, let firstChar = token.string.first else {
                        return false
                    }
                    return firstChar.isLetter && firstChar.isUppercase
                }
                
                func chained(index: Int) -> IndexedToken? {
                    guard let nextToken = formatter.nextIndexedToken(after: index, where: { !$0.isSpaceOrCommentOrLinebreak }) else {
                        return nil
                    }
                    guard nextToken.token == .operator(".", .infix) else {
                        return nil
                    }
                    return nextToken
                }
                
                @discardableResult
                func functionClosureToKeyPath(startIndex: Int, startToken: Token, removing rangeToRemove: Range<Int>?) -> Bool {
                    guard tokenIsTypeIdentifier(token: startToken) else {
                        return false
                    }
                    guard let chained = chained(index: startIndex) else {
                        return false
                    }
                    guard let nextIdentifier = formatter.nextIndexedToken(after: chained.index, where: { !$0.isSpaceOrCommentOrLinebreak }), nextIdentifier.isIdentifier else {
                        return false
                    }
                    if tokenIsTypeIdentifier(token: nextIdentifier.token) {
                        if let rangeToRemove {
                            let newRangeToRemove = rangeToRemove.lowerBound ..< startIndex
                            return functionClosureToKeyPath(startIndex: nextIdentifier.index, startToken: nextIdentifier.token, removing: newRangeToRemove)
                        } else {
                            return functionClosureToKeyPath(startIndex: nextIdentifier.index, startToken: nextIdentifier.token, removing: startIndex ..< (chained.index + 1))
                        }
                    } else {
                        formatter.convertNestedEnumCallsToCaseKeyPath(caseNameIndex: nextIdentifier.index)
                        formatter.replaceToken(at: startIndex, with: .operator("\\", .prefix))
                        if let rangeToRemove {
                            formatter.removeTokens(in: rangeToRemove)
                        }
                        return true
                    }
                }
                
                func scopeWithKeyPath(startIndex: Int) {
                    guard let startToken = formatter.token(at: startIndex) else {
                        return
                    }
                    switch startToken {
                    case .startOfScope("{"):
                        closureToKeyPath(startIndex: startIndex)
                    case .identifier:
                        functionClosureToKeyPath(startIndex: startIndex, startToken: startToken, removing: nil)
                    default:
                        return
                    }
                }
                
                guard let actionParameter = formatter.indexedToken(.identifier("action"), after: scopeOpenParen.index) else {
                    return
                }
                scopeWithKeyPath(startIndex: formatter.index(after: actionParameter.index, where: { !$0.isSpaceOrCommentOrLinebreak && $0.string != ":" })!)
                
                guard let stateParameter = formatter.indexedToken(.identifier("state"), after: scopeOpenParen.index) else {
                    return
                }
                
                scopeWithKeyPath(startIndex: formatter.index(after: stateParameter.index, where: { !$0.isSpaceOrCommentOrLinebreak && $0.string != ":" })!)
                
            }
        }
}

extension Formatter {
    func convertNestedEnumCallsToCaseKeyPath(caseNameIndex: Int) {
        guard let nextNonEmptyToken = nextIndexedToken(after: caseNameIndex, where: { !$0.isSpaceOrCommentOrLinebreak }), nextNonEmptyToken.token == .startOfScope("("),
              let endOfScope = endOfScope(at: nextNonEmptyToken.index) else {
            return
        }
        var indicesToRemove = [Int]()
        for index in (nextNonEmptyToken.index ... endOfScope) {
            if let nestedToken = token(at: index),
                nestedToken == .startOfScope("(")
                || nestedToken == .endOfScope(")")
                || nestedToken.isAnonymousParameter {
                    indicesToRemove.append(index)
            }
        }
        for index in indicesToRemove.reversed() {
            removeToken(at: index)
        }
    }
}

extension Token {
    var isAnonymousParameter: Bool {
        guard isIdentifier else {
            return false
        }
        for (index, character) in string.enumerated() {
            if index == 0, character == "$" {
                continue
            } else if character.isWholeNumber {
                continue
            } else {
                return false
            }
        }
        return true
    }
}
