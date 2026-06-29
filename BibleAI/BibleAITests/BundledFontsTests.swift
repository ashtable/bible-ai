import Testing
import UIKit
@testable import BibleAI

// These tests assert the custom fonts are bundled and registered via the app's
// `UIAppFonts`. They drive off the `BundledFonts` manifest: every face listed
// there must resolve at runtime, and every family it names must be known to the
// font manager. Keeping the assertions manifest-driven means adding a face to
// `BundledFonts.all` automatically extends coverage.
//
// Simulator-safe: only exercises CoreText/UIKit font registration, no hardware.

@Suite("Task 1 — bundled fonts")
struct BundledFontsTests {

    @Test("Every manifest family is registered with the font manager")
    func everyManifestFamilyRegistered() {
        for family in Set(BundledFonts.all.map(\.familyName)) {
            let names = UIFont.fontNames(forFamilyName: family)
            #expect(
                names.isEmpty == false,
                "No faces registered for family \"\(family)\". Expected the bundled .ttf files for this family to be present and listed in the app's UIAppFonts."
            )
        }
    }

    @Test("Every manifest face resolves to its exact PostScript face (no system fallback)")
    func bundledFacesResolveExactly() {
        for face in BundledFonts.all {
            let font = UIFont(name: face.postScriptName, size: 17)
            #expect(
                font != nil,
                "UIFont(name: \"\(face.postScriptName)\", size: 17) returned nil — \"\(face.fileName)\" is not bundled/registered."
            )
            // `UIFont(name:size:)` returns nil for an unknown name (the `!= nil`
            // check above covers that). This equality guard catches the other
            // failure mode: a name that *does* resolve but to a different face —
            // e.g. passing a family or full name that maps to a sibling weight,
            // or a stale PostScript name colliding with an already-registered
            // font. Requiring fontName == postScriptName proves the exact
            // intended face loaded.
            #expect(
                font?.fontName == face.postScriptName,
                "Resolved font for \"\(face.postScriptName)\" was \"\(font?.fontName ?? "nil")\" — expected an exact match. A mismatch means a different face was resolved instead of the intended one."
            )
        }
    }
}
