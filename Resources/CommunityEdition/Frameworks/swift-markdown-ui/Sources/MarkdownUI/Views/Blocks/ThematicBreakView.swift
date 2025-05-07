import SwiftUI

struct ThematicBreakView: View {
    @Environment(\.theme.thematicBreak) private var thematicBreak

    var body: some View {
        thematicBreak.makeBody(configuration: ())
    }
}
