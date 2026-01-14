import Testing
import Foundation
@testable import Domain

@Suite
struct ProviderTests {

    // MARK: - Provider Identity

    @Test func `codex provider has correct id`() {
        let provider = Provider.codex

        #expect(provider.id == "codex")
    }

    @Test func `claude provider has correct id`() {
        let provider = Provider.claude

        #expect(provider.id == "claude")
    }

    // MARK: - Display Name

    @Test func `codex provider displays as Codex`() {
        let provider = Provider.codex

        #expect(provider.displayName == "Codex")
    }

    @Test func `claude provider displays as Claude Code`() {
        let provider = Provider.claude

        #expect(provider.displayName == "Claude Code")
    }

    // MARK: - All Providers

    @Test func `allCases contains both providers`() {
        let all = Provider.allCases

        #expect(all.count == 2)
        #expect(all.contains(.codex))
        #expect(all.contains(.claude))
    }
}

// Note: Installation path tests are in InfrastructureTests/ProviderPathResolverTests.swift
// Provider is a pure domain value object - file system paths are infrastructure concerns
