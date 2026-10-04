import Foundation
import ChotkiCore
import WindowsUI

enum WindowsAssets {
    struct Focus: Decodable, Sendable { let number: Int; let focusX: Double; let focusY: Double }
    static let root = Bundle.module.resourceURL!.appendingPathComponent("Assets")
    static let names: [String] = {
        guard let text = try? String(contentsOf: root.appendingPathComponent("sayings/order.txt"), encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline).map(String.init)
    }()
    static let focuses: [Int: Focus] = {
        var result:[Int:Focus]=[:]
        for filename in ["approved-sources.json","legacy-focus.json"] {
            guard let data=try? Data(contentsOf:root.appendingPathComponent("sayings/"+filename)),
                  let values=try? JSONDecoder().decode([Focus].self,from:data) else { continue }
            for value in values { result[value.number]=value }
        }
        return result
    }()
    static func image(on day: CalendarDate) -> (URL, Double, Double)? {
        guard names.count == 365 else { return nil }
        let first = CalendarDate(year: day.year, month: 1, day: 1)!
        let name = names[(first.days(until: day)+1) % names.count]
        let url = root.appendingPathComponent(name)
        let number = Int(url.deletingPathExtension().lastPathComponent) ?? 0
        return (url, focuses[number]?.focusX ?? 0.5, focuses[number]?.focusY ?? 0.45)
    }
    static func loadFonts() throws {
        for cut in ["Roman", "Bold", "Italic", "BoldItalic"] {
            let path = root.appendingPathComponent("fonts/XCharter-\(cut).otf").path
            guard path.withCString({ ch_font($0) }) > 0 else { throw BootstrapError.verification("Bundled reading font \(cut) could not be loaded") }
        }
    }
}
