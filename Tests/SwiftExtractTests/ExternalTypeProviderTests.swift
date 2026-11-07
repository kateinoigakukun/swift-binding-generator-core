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

import SwiftExtract
import SwiftParser
import Testing

/// Describes `FishKit` from a fixed table and records every lookup.
private final class FishKitProvider: SwiftExternalTypeProvider {
  let types: [[String]: SwiftExternalTypeShape] = [
    ["Fish"]: SwiftExternalTypeShape(kind: .class),
    ["Fish", "Species"]: SwiftExternalTypeShape(kind: .enum),
    ["School"]: SwiftExternalTypeShape(kind: .struct, genericParameterNames: ["Member"]),
  ]
  private(set) var lookups: [[String]] = []

  var moduleNames: Set<String> { ["FishKit"] }

  func lookupType(_ path: [String], inModule moduleName: String) -> SwiftExternalTypeShape? {
    lookups.append(path)
    return moduleName == "FishKit" ? types[path] : nil
  }
}

@Suite("External type provider")
struct ExternalTypeProviderSuite {

  @Test func providedTypesResolveDuringAnalysis() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          import FishKit

          public func adopt(_ fish: Fish) {}
          public func identify(_ fish: Fish) -> Fish.Species { fatalError() }
          public func gather(_ school: School<Fish>) {}
          """
        )
      ],
      moduleName: "Aquarium",
      externalTypeProvider: FishKitProvider()
    )

    #expect(Set(result.extractedGlobalFuncs.map(\.name)) == ["adopt", "identify", "gather"])

    let identify = try #require(result.extractedGlobalFuncs.first { $0.name == "identify" })
    let species = try #require(identify.functionSignature.result.type.asNominalTypeDeclaration)
    #expect(species.name == "Species")
    #expect(species.moduleName == "FishKit")
    #expect(species.kind == .enum)
    #expect(species.parent?.name == "Fish")

    let gather = try #require(result.extractedGlobalFuncs.first { $0.name == "gather" })
    let school = try #require(gather.functionSignature.parameters.first?.type.asNominalTypeDeclaration)
    #expect(school.genericParameters.map(\.name) == ["Member"])
  }

  @Test func lookupsAreLazyAndCached() throws {
    let provider = FishKitProvider()
    let symbolTable = SwiftSymbolTable.setup(
      moduleName: "Aquarium",
      [SwiftInputFile(syntax: Parser.parse(source: "import FishKit"), path: "Source.swift")],
      config: nil,
      sourceDependencies: SourceDependencies(),
      externalTypeProvider: provider
    )
    #expect(provider.lookups.isEmpty)

    let fish = try #require(symbolTable.lookupTopLevelNominalType("Fish", inModule: "FishKit"))
    #expect(symbolTable.lookupTopLevelNominalType("Fish", inModule: "FishKit") === fish)
    #expect(symbolTable.lookupTopLevelNominalType("Coral", inModule: "FishKit") == nil)
    #expect(symbolTable.lookupTopLevelNominalType("Coral", inModule: "FishKit") == nil)
    #expect(symbolTable.lookupNestedType("Species", parent: fish)?.moduleName == "FishKit")
    #expect(provider.lookups == [["Fish"], ["Coral"], ["Fish", "Species"]])
  }

  @Test func extensionsOfProvidedTypesAreCrossModule() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          import FishKit

          public protocol Swimmer {}
          extension Fish: Swimmer {}
          """
        )
      ],
      moduleName: "Aquarium",
      externalTypeProvider: FishKitProvider()
    )

    #expect(result.extractedTypes["Fish"] == nil)
    let fishExtension = try #require(result.crossModuleExtensions.all.first)
    #expect(fishExtension.extendedType.moduleName == "FishKit")
    #expect(fishExtension.addedConformances.map(\.description) == ["Swimmer"])
  }

  @Test func stubsTakePrecedenceForTheSameModule() throws {
    let provider = FishKitProvider()
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          import FishKit

          public func decorate(_ coral: Coral) {}
          """
        )
      ],
      moduleName: "Aquarium",
      config: DefaultSwiftExtractConfiguration(
        swiftModule: "Aquarium",
        importedModuleStubs: ["FishKit": ["public struct Coral {}"]]
      ),
      externalTypeProvider: provider
    )

    #expect(result.extractedGlobalFuncs.map(\.name) == ["decorate"])
    #expect(provider.lookups.isEmpty)
  }
}
