//
//  Token+CustomDebugStringConvertible.swift
//  SwiftFormat
//
//  Created by andrew on 2/4/24.
//  Copyright © 2024 Nick Lockwood. All rights reserved.
//

import Foundation

extension Token: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Token.\(caseDescription)"
    }
    
    private var caseDescription: String {
        switch self {
        case let .number(string, numberType):
            """
            number(
                \(string),
                \(numberType.debugDescription)
            )
            """
        case let .linebreak(string, originalLine):
                        """
                        linebreak(
                            \(string),
                            OriginalLine.\(originalLine.description)
                        )
                        """
        case let .startOfScope(string):
                        """
                        startOfScope(\(string))
                        """
        case let .endOfScope(string):
                        """
                        endOfScope(\(string))
                        """
        case let .delimiter(string):
                        """
                        delimiter(\(string))
                        """
        case let .operator(string, operatorType):
                        """
                        operator(
                            \(string),
                            \(operatorType.debugDescription)
                        )
                        """
        case let .stringBody(string):
                        """
                        stringBody(\(string))
                        """
        case let .keyword(string):
                        """
                        keyword(\(string))
                        """
        case let .identifier(string):
                        """
                        identifier(\(string))
                        """
        case let .space(string):
                        """
                        space(\(string))
                        """
        case let .commentBody(string):
                        """
                        commentBody(\(string))
                        """
        case let .error(string):
                        """
                        error(\(string))
                        """
        }
    }
}


extension NumberType: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .binary:
            "NumberType.binary"
        case .decimal:
            "NumberType.decimal"
        case .hex:
            "NumberType.hex"
        case .integer:
            "NumberType.integer"
        case .octal:
            "NumberType.octal"
        }
    }
}

extension OperatorType: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .infix:
            "OperatorType.infix"
        case .none:
            "OperatorType.none"
        case .postfix:
            "OperatorType.postfix"
        case .prefix:
            "OperatorType.prefix"
        }
    }
}
