//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

//==========================================================================//
// IMPORTANT: The macros defined in this file are intended to test the      //
// behavior of MacroSystem. Many of them do not serve as good examples of   //
// how macros should be written. In particular, they often lack error       //
// handling because it is not needed in the few test cases in which these   //
// macros are invoked.                                                      //
//==========================================================================//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacroExpansion
@_spi(ExperimentalLanguageFeatures) import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

private struct AnnotateDeclaration: AttributeMacro {
  static func expansion(
    of node: AttributeSyntax,
    providingAttributesFor decl: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AttributeSyntax] {
    return ["@someAttribute"]
  }
}

final class AttributeMacroTests: XCTestCase {
  private let indentationWidth: Trivia = .spaces(2)

  func testAnnotateDeclaration() {
    assertMacroExpansion(
      """
      @annotateDeclaration
      struct Point {}
      """,
      expandedSource: """
        @someAttribute
        struct Point {}
        """,
      macros: ["annotateDeclaration": AnnotateDeclaration.self],
      indentationWidth: indentationWidth
    )
  }

  func testAttributeWithComment() {
    assertMacroExpansion(
      """
      @annotateDeclaration
      // Some comment
      struct S {}
      """,
      expandedSource: """
        @someAttribute
        // Some comment
        struct S {}
        """,
      macros: ["annotateDeclaration": AnnotateDeclaration.self],
      indentationWidth: indentationWidth
    )
  }

  func testUseDeclaration() {
    struct AnnotateStructOrClass: AttributeMacro {
      static func expansion(
        of node: AttributeSyntax,
        providingAttributesFor decl: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
      ) throws -> [AttributeSyntax] {
        if decl.is(StructDeclSyntax.self) {
            return ["@structAttribute"]
        }
        if decl.is(ClassDeclSyntax.self) {
            return ["@classAttribute"]
        }
        return []
      }
    }

    assertMacroExpansion(
      """
      @annotateStructOrClass
      struct Foo {
      }
      """,
      expandedSource: """
        @structAttribute
        struct Foo {
        }
        """,
      macros: ["annotateStructOrClass": AnnotateStructOrClass.self],
      indentationWidth: indentationWidth
    )

    assertMacroExpansion(
      """
      @annotateStructOrClass
      class Foo {
      }
      """,
      expandedSource: """
        @classAttribute
        class Foo {
        }
        """,
      macros: ["annotateStructOrClass": AnnotateStructOrClass.self],
      indentationWidth: indentationWidth
    )

    assertMacroExpansion(
      """
      @annotateStructOrClass
      func foo() {
      }
      """,
      expandedSource: """
        func foo() {
        }
        """,
      macros: ["annotateStructOrClass": AnnotateStructOrClass.self],
      indentationWidth: indentationWidth
    )
  }

  func testOnDeclThatAlreadyHasAttribute() {
    struct TestMacro: AttributeMacro {
      static func expansion(
        of node: AttributeSyntax,
        providingAttributesFor decl: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
      ) throws -> [AttributeSyntax] {
        return ["@someAttribute"]
      }
    }

    assertMacroExpansion(
      """
      @Test
      @available(*, deprecated)
      struct Foo {
      }
      """,
      expandedSource: """
        @available(*, deprecated)
        @someAttribute
        struct Foo {
        }
        """,
      macros: ["Test": TestMacro.self],
      indentationWidth: indentationWidth
    )

    assertMacroExpansion(
      """
      @Test
      @available(*, deprecated)

      struct Foo {
      }
      """,
      expandedSource: """
        @available(*, deprecated)
        @someAttribute

        struct Foo {
        }
        """,
      macros: ["Test": TestMacro.self],
      indentationWidth: indentationWidth
    )

    assertMacroExpansion(
      """
      @Test
      @available(*, deprecated) // some comment

      struct Foo {
      }
      """,
      expandedSource: """
        @available(*, deprecated)
        @someAttribute // some comment

        struct Foo {
        }
        """,
      macros: ["Test": TestMacro.self],
      indentationWidth: indentationWidth
    )
  }

  func testEmpty() {
    struct TestMacro: AttributeMacro {
      static func expansion(
        of node: AttributeSyntax,
        providingAttributesFor decl: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
      ) throws -> [AttributeSyntax] {
        return []
      }
    }

    assertMacroExpansion(
      """
      @Test
      struct Foo {
      }
      """,
      expandedSource: """
        struct Foo {
        }
        """,
      macros: [
        "Test": TestMacro.self
      ]
    )
  }

  func testDelegation() {
    struct DelegateMacro: AttributeMacro {
      static func expansion(
        of node: AttributeSyntax,
        providingAttributesFor decl: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
      ) throws -> [AttributeSyntax] {
        return ["@someAttribute"]
      }
    }
    struct MainMacro: AttributeMacro {
      static func expansion(
        of node: AttributeSyntax,
        providingAttributesFor decl: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
      ) throws -> [AttributeSyntax] {
        return ["@Delegate"]
      }
    }

    assertMacroExpansion(
      """
      @Main
      struct Foo {
      }
      """,
      expandedSource: """
        @someAttribute
        struct Foo {
        }
        """,
      macros: [
        "Main": MainMacro.self,
        "Delegate": DelegateMacro.self
      ]
    )
  }

  func testAppliedByPeerMacro() {
    struct TestPeerMacro: PeerMacro {
      static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
      ) throws -> [DeclSyntax] {
          return ["""
            @Test
            struct PeerStruct {
            }
            """
          ]
      }
    }
    struct TestMacro: AttributeMacro {
      static func expansion(
        of node: AttributeSyntax,
        providingAttributesFor decl: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
      ) throws -> [AttributeSyntax] {
        return ["@someAttribute"]
      }
    }

    assertMacroExpansion(
      """
      @TestPeer
      struct Foo {
      }
      """,
      expandedSource: """
        struct Foo {
        }
        @someAttribute
        struct PeerStruct {
        }
        """,
      macros: [
        "TestPeer": TestPeerMacro.self,
        "Test": TestMacro.self
      ]
    )
  }
}
