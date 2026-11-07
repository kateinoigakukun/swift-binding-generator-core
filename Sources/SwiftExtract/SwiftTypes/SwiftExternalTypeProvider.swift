//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftParser
import SwiftSyntax

/// Describes the types of modules whose source the analyzer doesn't see.
///
/// Consumers that already hold a description of their dependency modules
/// (e.g. an intermediate representation produced by an earlier build phase)
/// implement this to make references to those modules' types resolve during
/// analysis, without rendering Swift stub source (`importedModuleStubs`) or
/// re-parsing dependency sources (`SourceDependencies`).
///
/// The analyzer queries the provider lazily, once per type path, and caches the
/// answer. Types of provided modules resolve, but are not owned by the analysis:
/// an extension of one is recorded as a cross-module extension.
public protocol SwiftExternalTypeProvider {
  /// The modules this provider describes.
  var moduleNames: Set<String> { get }

  /// The shape of the type at `path` in `moduleName`, or `nil` if there is no
  /// such type.
  ///
  /// `path` holds the type's name components from the module root, e.g.
  /// `["Outer", "Inner"]` for `Module.Outer.Inner`. A nested type is only
  /// reachable if every enclosing path also has a shape.
  func lookupType(_ path: [String], inModule moduleName: String) -> SwiftExternalTypeShape?
}

/// The shape of a type described by a `SwiftExternalTypeProvider`.
public struct SwiftExternalTypeShape: Hashable {
  public var kind: SwiftNominalTypeDeclaration.Kind

  /// Names of the type's generic parameters, if any. Ignored for protocols.
  public var genericParameterNames: [String]

  public init(kind: SwiftNominalTypeDeclaration.Kind, genericParameterNames: [String] = []) {
    self.kind = kind
    self.genericParameterNames = genericParameterNames
  }
}

/// Symbol table for one module described by a `SwiftExternalTypeProvider`.
///
/// Declarations are created on first lookup and cached, so every lookup of the
/// same path returns the same declaration.
final class SwiftExternalModuleSymbolTable: SwiftSymbolTableProtocol {
  let moduleName: String
  private let provider: any SwiftExternalTypeProvider
  private var declarations: [[String]: SwiftNominalTypeDeclaration] = [:]
  private var missingPaths: Set<[String]> = []
  private var pathsByDeclaration: [ObjectIdentifier: [String]] = [:]

  init(moduleName: String, provider: any SwiftExternalTypeProvider) {
    self.moduleName = moduleName
    self.provider = provider
  }

  func lookupTopLevelNominalType(_ name: String) -> SwiftNominalTypeDeclaration? {
    declaration(at: [name], parent: nil)
  }

  func lookupTopLevelTypealias(_ name: String) -> SwiftTypeAliasDeclaration? {
    nil
  }

  func lookupNestedType(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftNominalTypeDeclaration? {
    guard let parentPath = pathsByDeclaration[ObjectIdentifier(parent)] else {
      return nil
    }
    return declaration(at: parentPath + [name], parent: parent)
  }

  func lookupNestedTypealias(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftTypeAliasDeclaration? {
    nil
  }

  private func declaration(at path: [String], parent: SwiftNominalTypeDeclaration?) -> SwiftNominalTypeDeclaration? {
    if let cached = declarations[path] {
      return cached
    }
    guard !missingPaths.contains(path) else {
      return nil
    }
    guard let shape = provider.lookupType(path, inModule: moduleName) else {
      missingPaths.insert(path)
      return nil
    }
    let declaration = SwiftNominalTypeDeclaration(
      name: path.last!,
      sourceFilePath: "",
      moduleName: moduleName,
      parent: parent,
      node: Self.syntax(name: path.last!, shape: shape)
    )
    declarations[path] = declaration
    pathsByDeclaration[ObjectIdentifier(declaration)] = path
    return declaration
  }

  /// `SwiftNominalTypeDeclaration` is syntax-backed: synthesize an empty
  /// declaration of the right kind and generic signature.
  private static func syntax(name: String, shape: SwiftExternalTypeShape) -> NominalTypeDeclSyntaxNode {
    let keyword =
      switch shape.kind {
      case .actor: "actor"
      case .class: "class"
      case .enum: "enum"
      case .protocol: "protocol"
      case .struct: "struct"
      }
    let genericClause =
      shape.kind == .protocol || shape.genericParameterNames.isEmpty
      ? "" : "<\(shape.genericParameterNames.joined(separator: ", "))>"
    func parse(_ name: String) -> NominalTypeDeclSyntaxNode? {
      guard let item = Parser.parse(source: "\(keyword) \(name)\(genericClause) {}").statements.first?.item else {
        return nil
      }
      if let node = item.as(ActorDeclSyntax.self) { return node }
      if let node = item.as(ClassDeclSyntax.self) { return node }
      if let node = item.as(EnumDeclSyntax.self) { return node }
      if let node = item.as(ProtocolDeclSyntax.self) { return node }
      if let node = item.as(StructDeclSyntax.self) { return node }
      return nil
    }
    // If `name` isn't a plain identifier, the declaration keeps the requested name.
    return parse(name) ?? parse("__Synthesized")!
  }
}
