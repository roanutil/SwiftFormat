//
//  IndexedToken.swift
//  SwiftFormat
//
//  Created by andrew on 2/3/24.
//  Copyright © 2024 Nick Lockwood. All rights reserved.
//

import Foundation

@dynamicMemberLookup
struct IndexedToken {
    let index: Int
    let token: Token

    subscript<Member>(dynamicMember keyPath: KeyPath<Token, Member>) -> Member {
        token[keyPath: keyPath]
    }
}

extension Formatter {
    /// Returns the next IndexedToken at the current scope that matches the block
    func nextIndexedToken(after index: Int, where operation: @escaping (Token) -> Bool = { _ in true }) -> IndexedToken? {
        guard let nextIndex = self.index(after: index, where: operation), let token = token(at: nextIndex) else {
            return nil
        }
        return IndexedToken(index: nextIndex, token: token)
    }

    /// Returns the IndexedToken of the last token in the specified range that matches the block
    func nextIndexedToken(in range: CountableRange<Int>, where operation: @escaping (Token) -> Bool = { _ in true }) -> IndexedToken? {
        guard let nextIndex = index(in: range, where: operation), let token = token(at: nextIndex) else {
            return nil
        }
        return IndexedToken(index: nextIndex, token: token)
    }

    /// Returns the IndexedToken of the next token in the specified range of the specified type
    func indexedToken(of type: TokenType, in range: CountableRange<Int>, if matches: (Token) -> Bool = { _ in true }) -> IndexedToken? {
        guard let index = index(of: type, in: range, if: matches), let token = token(at: index) else {
            return nil
        }
        return IndexedToken(index: index, token: token)
    }

    /// Returns the IndexedToken of the next token at the current scope of the specified type
    func indexedToken(of type: TokenType, after index: Int, if matches: (Token) -> Bool = { _ in true }) -> IndexedToken? {
        guard let index = self.index(of: type, after: index, if: matches), let token = token(at: index) else {
            return nil
        }
        return IndexedToken(index: index, token: token)
    }

    /// Returns the IndexedToken of the next token at the current scope of the specified type
    func indexedToken(_ of: Token, after index: Int) -> IndexedToken? {
        guard let index = self.index(of: of, after: index), let token = token(at: index) else {
            return nil
        }
        return IndexedToken(index: index, token: token)
    }

    /// Returns the next IndexedToken at the current scope of the specified type
    func nextIndexedToken(of type: TokenType, after index: Int, if matches: (Token) -> Bool = { _ in true }) -> IndexedToken? {
        guard let index = self.index(of: type, after: index, if: matches), let token = token(at: index) else {
            return nil
        }
        return IndexedToken(index: index, token: token)
    }

    /// Returns the IndexedToken of the previous token at the current scope that matches the block
    func indexedToken(before index: Int, where matches: (Token) -> Bool = { _ in true }) -> IndexedToken? {
        guard let index = self.index(before: index, where: matches), let token = token(at: index) else {
            return nil
        }
        return IndexedToken(index: index, token: token)
    }

    /// Returns the IndexedToken of the last matching token in the specified range
    func lastIndexedToken(_ token: Token, in range: CountableRange<Int>) -> IndexedToken? {
        guard let index = lastIndex(of: token, in: range) else {
            return nil
        }
        return IndexedToken(index: index, token: token)
    }

    func indexedToken(_ token: Token, in range: CountableRange<Int>) -> IndexedToken? {
        guard let index = index(of: token, in: range) else {
            return nil
        }
        return IndexedToken(index: index, token: token)
    }

    /// Returns the IndexedToken of the previous matching token at the current scope
    func indexedToken(of token: Token, before index: Int) -> IndexedToken? {
        guard let index = self.index(of: token, before: index) else {
            return nil
        }
        return IndexedToken(index: index, token: token)
    }

    /// Returns the index of the last IndexedToken in the specified range of the specified type
    func lastIndexedToken(of type: TokenType, in range: CountableRange<Int>, if matches: (Token) -> Bool = { _ in true }) -> IndexedToken? {
        guard let index = lastIndex(of: type, in: range, if: matches), let token = token(at: index) else {
            return nil
        }
        return IndexedToken(index: index, token: token)
    }
}
