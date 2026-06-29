import Testing
import SwiftUI
import UIKit
@testable import BibleAI

@Suite("Task 2 — BibleAITheme")
struct BibleAIThemeTests {

    private func rgba8(_ color: Color) -> (r: Int, g: Int, b: Int, a: Int) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ v: CGFloat) -> Int { Int((v * 255).rounded()) }
        return (byte(r), byte(g), byte(b), byte(a))
    }

    @Test("Color(hex:) parses #RRGGBB into exact sRGB bytes")
    func hexInitParsesKnownValues() {
        #expect(rgba8(Color(hex: "#000000")) == (0, 0, 0, 255))
        #expect(rgba8(Color(hex: "#ffffff")) == (255, 255, 255, 255))
        #expect(rgba8(Color(hex: "#FF8800")) == (255, 136, 0, 255))
        #expect(rgba8(Color(hex: "abcdef"))  == (171, 205, 239, 255))
    }

    @Test("Neutral color tokens resolve to their spec hex")
    func neutralTokensMatchSpec() {
        #expect(rgba8(.canvas) == (233, 231, 226, 255)) // #e9e7e2
        #expect(rgba8(.card)   == (255, 255, 255, 255)) // #ffffff
        #expect(rgba8(.subtle) == (243, 241, 236, 255)) // #f3f1ec
    }

    @Test("Every AccentChoice resolves to its spec hex (map is exhaustive)")
    func accentColorsMatchSpec() {
        let expected: [AccentChoice: (Int, Int, Int)] = [
            .purple:      (108, 92, 231),  // #6C5CE7
            .teal:        (31, 169, 143),  // #1FA98F
            .burntOrange: (224, 103, 59),  // #E0673B
        ]
        #expect(Set(expected.keys) == Set(AccentChoice.allCases))
        for (choice, rgb) in expected {
            let (r, g, b, a) = rgba8(.accent(for: choice))
            #expect((r, g, b) == rgb, "accent \(choice) resolved to wrong color")
            #expect(a == 255)
        }
    }

    @Test("AccentChoice has exactly the three expected cases")
    func accentChoiceCases() {
        #expect(AccentChoice.allCases.count == 3)
        #expect(Set(AccentChoice.allCases) == [.purple, .teal, .burntOrange])
    }

    @Test("AccentChoice raw values are the stable persisted strings")
    func accentChoiceRawValues() {
        #expect(AccentChoice.purple.rawValue == "purple")
        #expect(AccentChoice.teal.rawValue == "teal")
        #expect(AccentChoice.burntOrange.rawValue == "burntOrange")
    }

    @Test("AccentChoice round-trips through Codable for every case")
    func accentChoiceCodableRoundTrip() throws {
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        for choice in AccentChoice.allCases {
            let data = try encoder.encode(choice)
            #expect(try decoder.decode(AccentChoice.self, from: data) == choice)
        }
    }

    @Test("AccentChoice decodes from its pinned JSON wire form")
    func accentChoiceDecodesPinnedWireForm() throws {
        let decoded = try JSONDecoder()
            .decode(AccentChoice.self, from: Data("\"teal\"".utf8))
        #expect(decoded == .teal)
    }

    @Test("Spacing tokens have exact 8pt-grid values")
    func spacingValues() {
        #expect(BibleAITheme.Spacing.xs == 4)
        #expect(BibleAITheme.Spacing.s  == 8)
        #expect(BibleAITheme.Spacing.m  == 16)
        #expect(BibleAITheme.Spacing.l  == 24)
        #expect(BibleAITheme.Spacing.xl == 40)
    }

    @Test("Spacing scale is strictly increasing and positive")
    func spacingMonotonic() {
        let scale: [CGFloat] = [
            BibleAITheme.Spacing.xs, BibleAITheme.Spacing.s,
            BibleAITheme.Spacing.m,  BibleAITheme.Spacing.l,
            BibleAITheme.Spacing.xl,
        ]
        #expect(scale == scale.sorted())
        #expect(Set(scale).count == scale.count)
        #expect(scale.allSatisfy { $0 > 0 })
    }

    @Test("Every typography token maps to a bundled PostScript face")
    func typographyUsesBundledFaces() {
        let bundled = Set(BundledFonts.all.map(\.postScriptName))
        for style in BibleAITheme.Typography.all {
            #expect(
                bundled.contains(style.postScriptName),
                "Typography references \"\(style.postScriptName)\", not a bundled face"
            )
            #expect(style.size > 0)
        }
    }

    @Test("Font.BibleAI tokens are wired to their typography descriptors")
    func fontTokensMatchDescriptors() {
        #expect(Font.BibleAI.displayHandwritten == BibleAITheme.Typography.displayHandwritten.font)
        #expect(Font.BibleAI.titleL  == BibleAITheme.Typography.titleL.font)
        #expect(Font.BibleAI.body    == BibleAITheme.Typography.body.font)
        #expect(Font.BibleAI.caption == BibleAITheme.Typography.caption.font)
    }
}
