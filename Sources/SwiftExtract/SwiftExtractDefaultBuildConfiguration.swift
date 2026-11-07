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

import Foundation
import SwiftIfConfig
import SwiftSyntax

/// A default, fixed build configuration during static analysis for interface extraction.
public struct SwiftExtractDefaultBuildConfiguration: BuildConfiguration {
  public static let shared = SwiftExtractDefaultBuildConfiguration()

  private var base: StaticBuildConfiguration

  public init() {
    guard let url = Bundle.module.url(forResource: "static-build-config", withExtension: "json") else {
      fatalError("static-build-config.json is not found in module bundle")
    }
    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      base = try decoder.decode(StaticBuildConfiguration.self, from: data)
    } catch {
      fatalError("\(error)")
    }
  }

  public func isCustomConditionSet(name: String) throws -> Bool {
    base.isCustomConditionSet(name: name)
  }

  public func hasFeature(name: String) throws -> Bool {
    base.hasFeature(name: name)
  }

  public func hasAttribute(name: String) throws -> Bool {
    base.hasAttribute(name: name)
  }

  public func canImport(importPath: [(TokenSyntax, String)], version: CanImportVersion) throws -> Bool {
    try base.canImport(importPath: importPath, version: version)
  }

  public func isActiveTargetOS(name: String) throws -> Bool {
    true
  }

  public func isActiveTargetArchitecture(name: String) throws -> Bool {
    true
  }

  public func isActiveTargetEnvironment(name: String) throws -> Bool {
    true
  }

  public func isActiveTargetRuntime(name: String) throws -> Bool {
    true
  }

  public func isActiveTargetPointerAuthentication(name: String) throws -> Bool {
    true
  }

  public func isActiveTargetObjectFormat(name: String) throws -> Bool {
    true
  }

  public var targetPointerBitWidth: Int {
    base.targetPointerBitWidth
  }

  public var targetAtomicBitWidths: [Int] {
    base.targetAtomicBitWidths
  }

  public var endianness: Endianness {
    base.endianness
  }

  public var languageVersion: VersionTuple {
    base.languageVersion
  }

  public var compilerVersion: VersionTuple {
    base.compilerVersion
  }
}

extension BuildConfiguration where Self == SwiftExtractDefaultBuildConfiguration {
  public static var swiftExtractDefault: SwiftExtractDefaultBuildConfiguration {
    .shared
  }
}

/// Wraps any `BuildConfiguration` and additionally reports a configured set of
/// module names as importable. Used so a target can extract declarations guarded
/// behind `#if canImport(<module>)` for modules the static build configuration
/// does not otherwise know about (e.g. another language code generator can
/// declare its own runtime module importable for extraction).
public struct ImportOverlayBuildConfiguration<Base: BuildConfiguration>: BuildConfiguration {
  public var base: Base
  public var availableImportModules: Set<String>

  public init(base: Base, availableImportModules: Set<String>) {
    self.base = base
    self.availableImportModules = availableImportModules
  }

  public func canImport(importPath: [(TokenSyntax, String)], version: CanImportVersion) throws -> Bool {
    // `importPath` is the dotted module path; the leading component is the module.
    if let moduleName = importPath.first?.1, availableImportModules.contains(moduleName) {
      return true
    }
    return try base.canImport(importPath: importPath, version: version)
  }

  public func isCustomConditionSet(name: String) throws -> Bool { try base.isCustomConditionSet(name: name) }
  public func hasFeature(name: String) throws -> Bool { try base.hasFeature(name: name) }
  public func hasAttribute(name: String) throws -> Bool { try base.hasAttribute(name: name) }
  public func isActiveTargetOS(name: String) throws -> Bool { try base.isActiveTargetOS(name: name) }
  public func isActiveTargetArchitecture(name: String) throws -> Bool { try base.isActiveTargetArchitecture(name: name) }
  public func isActiveTargetEnvironment(name: String) throws -> Bool { try base.isActiveTargetEnvironment(name: name) }
  public func isActiveTargetRuntime(name: String) throws -> Bool { try base.isActiveTargetRuntime(name: name) }
  public func isActiveTargetPointerAuthentication(name: String) throws -> Bool { try base.isActiveTargetPointerAuthentication(name: name) }
  public func isActiveTargetObjectFormat(name: String) throws -> Bool { try base.isActiveTargetObjectFormat(name: name) }
  public var targetPointerBitWidth: Int { base.targetPointerBitWidth }
  public var targetAtomicBitWidths: [Int] { base.targetAtomicBitWidths }
  public var endianness: Endianness { base.endianness }
  public var languageVersion: VersionTuple { base.languageVersion }
  public var compilerVersion: VersionTuple { base.compilerVersion }
}
