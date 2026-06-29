import Testing
import UIKit
@testable import BibleAI

// TDD red phase: these tests assert the custom fonts are bundled and registered
// via the app's `UIAppFonts`. They are expected to FAIL at runtime until the
// GREEN step ships the real `.ttf` files and the `UIAppFonts` registration.
// The `BundledFonts` manifest already exists so the target COMPILES and all three
// tests RUN (and fail for the right reason: fonts not yet bundled), rather than
// the whole suite failing to build.
//
// Simulator-safe: only exercises CoreText/UIKit font registration, no hardware.

@Suite("Task 1 — bundled fonts")
struct BundledFontsTests {

    @Test("Nunito Sans family is registered with the font manager")
    func nunitoSansFamilyRegistered() {
        let names = UIFont.fontNames(forFamilyName: "Nunito Sans")
        #expect(
            names.isEmpty == false,
            "No faces registered for family \"Nunito Sans\". Expected the bundled NunitoSans .ttf files to be present and listed in the app's UIAppFonts."
        )
    }

    @Test("Caveat family is registered with the font manager")
    func caveatFamilyRegistered() {
        let names = UIFont.fontNames(forFamilyName: "Caveat")
        #expect(
            names.isEmpty == false,
            "No faces registered for family \"Caveat\". Expected the bundled Caveat-Regular.ttf to be present and listed in the app's UIAppFonts."
        )
    }

    @Test("Every manifest face resolves to its exact PostScript face (no system fallback)")
    func bundledFacesResolveExactly() {
        for face in BundledFonts.all {
            let font = UIFont(name: face.postScriptName, size: 17)
            #expect(
                font != nil,
                "UIFont(name: \"\(face.postScriptName)\", size: 17) returned nil — \"\(face.fileName)\" is not bundled/registered."
            )
            // Guards against a silent system-font substitution: when a PostScript
            // name is unknown, UIFont can hand back a different concrete font.
            // Requiring an exact fontName match proves the intended face loaded.
            #expect(
                font?.fontName == face.postScriptName,
                "Resolved font for \"\(face.postScriptName)\" was \"\(font?.fontName ?? "nil")\" — expected an exact match. A mismatch means the system silently substituted a fallback font."
            )
        }
    }
}
