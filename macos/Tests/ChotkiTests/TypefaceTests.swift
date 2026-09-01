import Testing
import AppKit
import SwiftUI
@testable import Chotki

/// The reading face, and the thing that would otherwise go wrong silently.
///
/// `Font.custom` falls back to the system font when a face is missing, without
/// complaint. A typeface change that quietly did nothing would look like a
/// typeface change that had not been made yet — so the chain is asserted here
/// rather than left to the eye.
@Suite("The reading face")
struct TypefaceTests {

    @Test("Iowan Old Style is on this machine, with the cuts we ask of it")
    func iowanIsPresent() {
        #expect(NSFont(name: "Iowan Old Style", size: 13) != nil)
        // Family name rather than PostScript name, so weights resolve to the
        // real cuts. This checks that assumption rather than assuming it.
        let roman = NSFont(name: "Iowan Old Style", size: 13)
        let bold = roman.map { NSFontManager.shared.convert($0, toHaveTrait: .boldFontMask) }
        #expect(roman?.fontName == "IowanOldStyle-Roman")
        #expect(bold?.fontName == "IowanOldStyle-Bold")
    }

    /// Charter is not decoration. It is what everyone without Iowan reads in,
    /// and what the Android port will bundle, so it has to be real here too.
    @Test("Charter is present as the fallback, with its cuts")
    func charterIsPresent() {
        let roman = NSFont(name: "Charter", size: 13)
        #expect(roman?.fontName == "Charter-Roman")
        let bold = roman.map { NSFontManager.shared.convert($0, toHaveTrait: .boldFontMask) }
        #expect(bold?.fontName == "Charter-Bold")
    }

    @Test("every face in the chain resolves — a typo would be silent otherwise")
    func chainHasNoTypos() {
        for name in Theme.serifChain {
            #expect(NSFont(name: name, size: 13) != nil, "\(name) is not a font on this system")
        }
    }

    @Test("the chain is tried in order, and Iowan wins where it exists")
    func chainIsOrdered() {
        #expect(Theme.serifChain.first == "Iowan Old Style")
        #expect(Theme.serifChain.contains("Charter"))
        #expect(Theme.readingFace == "Iowan Old Style")
    }

    /// The point of the chain: a machine without Iowan still reads in something
    /// chosen, not in whatever SwiftUI felt like.
    @Test("with Iowan gone, the next face in the chain is still a real one")
    func fallbackIsReal() {
        let withoutIowan = Theme.serifChain.dropFirst()
        let resolved = withoutIowan.first { NSFont(name: $0, size: 13) != nil }
        #expect(resolved == "Charter")
    }

    @Test("asking for the reading face returns something")
    func readingReturnsAFont() {
        // Font is opaque, so this asserts it can be built at all and at the
        // sizes actually used, rather than inspecting it.
        for size in [11.0, 12.0, 13.0, 15.0, 16.0] as [CGFloat] {
            _ = Theme.reading(size)
        }
    }
}

/// A guard against the failure this change uncovered.
///
/// The app asked for `Cardo` in six places — scripture, the fathers, prayers,
/// the glossary term, the welcome, the thanksgiving line — and **Cardo was
/// never installed and never bundled**, so every one of them had been quietly
/// rendering in the system sans. Nothing looked broken; it simply was not the
/// font anyone had chosen.
///
/// The lesson is not "remember to bundle fonts". It is that `Font.custom` fails
/// silently, so a face named at a call site is a claim nobody checks. Every
/// reading face now goes through `Theme.reading`, whose chain is asserted
/// above — and this test fails the moment a raw name reappears.
@Suite("No font is named at a call site")
struct FontCallSiteTests {

    @Test("nothing asks for a font by name outside Theme")
    func noRawCustomFonts() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Chotki")

        let files = try FileManager.default
            .contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" && $0.lastPathComponent != "Theme.swift" }
        #expect(!files.isEmpty, "no sources found — the scan is looking in the wrong place")

        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(
                !text.contains("Font.custom(") && !text.contains(".font(.custom("),
                """
                \(file.lastPathComponent) names a font at the call site. \
                Font.custom falls back silently, so an unavailable face renders \
                as the system font and nobody notices — which is exactly what \
                Cardo did here. Use Theme.reading instead.
                """
            )
        }
    }
}
