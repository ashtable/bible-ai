import Foundation

/// Declarative manifest of the custom font faces the app **intends** to bundle.
///
/// This is a contract, not an implementation: it lists the faces that the GREEN
/// step must register via the app bundle's `UIAppFonts` (and ship as real `.ttf`
/// files). Tests assert that every face in `all` actually resolves at runtime —
/// so this manifest is what makes the font-bundling requirement testable.
///
/// Design tokens (see `BibleAITheme`): `Nunito Sans` for all UI body/headings,
/// `Caveat` for display/handwritten accents.
enum BundledFonts {

    /// A single font face we intend to bundle.
    struct Face: Sendable {
        /// Family name as reported by `UIFont.fontNames(forFamilyName:)`, e.g. `"Nunito Sans"`.
        let familyName: String
        /// Exact PostScript name used with `UIFont(name:size:)`, e.g. `"NunitoSans-Regular"`.
        let postScriptName: String
        /// Bundled resource file name, e.g. `"NunitoSans-Regular.ttf"`.
        let fileName: String
    }

    /// The four faces approved for bundling.
    static let all: [Face] = [
        Face(
            familyName: "Nunito Sans",
            postScriptName: "NunitoSans-Regular",
            fileName: "NunitoSans-Regular.ttf"
        ),
        Face(
            familyName: "Nunito Sans",
            postScriptName: "NunitoSans-SemiBold",
            fileName: "NunitoSans-SemiBold.ttf"
        ),
        Face(
            familyName: "Nunito Sans",
            postScriptName: "NunitoSans-Bold",
            fileName: "NunitoSans-Bold.ttf"
        ),
        Face(
            familyName: "Caveat",
            postScriptName: "Caveat-Regular",
            fileName: "Caveat-Regular.ttf"
        ),
    ]
}
