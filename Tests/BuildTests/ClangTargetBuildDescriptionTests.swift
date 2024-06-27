//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Basics
@testable import Build
import PackageGraph
import PackageModel
import SPMBuildCore
import SPMTestSupport
import XCTest

final class ClangTargetBuildDescriptionTests: XCTestCase {
    func testClangIndexStorePath() throws {
        let targetDescription = try makeTargetBuildDescription("test")
        XCTAssertTrue(try targetDescription.basicArguments().contains("-index-store-path"))
        XCTAssertFalse(try targetDescription.basicArguments().contains("-w"))
    }

    func testWarningSuppressionForRemotePackages() throws {
        let targetDescription = try makeTargetBuildDescription("test-warning-supression", usesSourceControl: true)
        XCTAssertTrue(try targetDescription.basicArguments().contains("-w"))
    }

    private func makeClangTarget() throws -> ClangModule {
        try ClangModule(
            name: "dummy",
            cLanguageStandard: nil,
            cxxLanguageStandard: nil,
            includeDir: .root,
            moduleMapType: .none,
            type: .library,
            path: .root,
            sources: .init(paths: [.root.appending(component: "foo.c")], root: .root),
            usesUnsafeFlags: false
        )
    }

    private func makeResolvedTarget() throws -> ResolvedModule {
        ResolvedModule(
            packageIdentity: .plain("dummy"),
            underlying: try makeClangTarget(),
            dependencies: [],
            supportedPlatforms: [],
            platformVersionProvider: .init(implementation: .minimumDeploymentTargetDefault)
        )
    }

    private func makeTargetBuildDescription(_ packageName: String,
                                            buildParameters: BuildParameters? = nil,
                                            usesSourceControl: Bool = false) throws -> ClangModuleBuildDescription {
        let observability = ObservabilitySystem.makeForTesting(verbose: false)

        let manifest: Manifest
        if usesSourceControl {
            manifest = Manifest.createLocalSourceControlManifest(
                displayName: packageName, path: AbsolutePath("/\(packageName)"))
        } else {
            manifest = Manifest.createRootManifest(
                displayName: packageName,
                toolsVersion: .v5,
                targets: [try TargetDescription(name: "dummy")])
        }

        let target = try makeResolvedTarget()

        let package = Package(identity: .plain(packageName),
                              manifest: manifest,
                              path: .root,
                              targets: [target.underlying],
                              products: [],
                              targetSearchPath: .root,
                              testTargetSearchPath: .root)

        return try ClangModuleBuildDescription(
            package: .init(underlying: package,
                           defaultLocalization: nil,
                           supportedPlatforms: [],
                           dependencies: [],
                           modules: .init([target]),
                           products: [],
                           registryMetadata: nil,
                           platformVersionProvider: .init(implementation: .minimumDeploymentTargetDefault)),
            target: target,
            toolsVersion: .current,
            buildParameters: buildParameters ?? mockBuildParameters(
                destination: .target,
                toolchain: try UserToolchain.default,
                indexStoreMode: .on
            ),
            fileSystem: localFileSystem,
            observabilityScope: observability.topScope
        )
    }
}
