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
import Testing

@Suite
struct MultipleBindingsSuite {

  @Test func everyBindingIsExtracted() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Tank.swift",
          """
          public class Tank {
            public var width: Int = 0, height: Int = 0
            public let depth: Double = 0, label: String = ""
          }
          """
        )
      ],
      moduleName: "Aquarium"
    )
    let tank = try #require(result.extractedTypes["Tank"])
    // A getter and setter for each `var` binding, a getter for each `let` binding.
    #expect(
      tank.variables.map { "\($0.name).\($0.apiKind)" } == [
        "width.getter", "width.setter",
        "height.getter", "height.setter",
        "depth.getter",
        "label.getter",
      ]
    )
  }

  @Test func globalBindingsAreExtracted() throws {
    let result = try analyze(
      sources: [("/fake/Globals.swift", "public let minDepth: Int = 1, maxDepth: Int = 10")],
      moduleName: "Aquarium"
    )
    #expect(result.extractedGlobalVariables.map(\.name) == ["minDepth", "maxDepth"])
  }
}
