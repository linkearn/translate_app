import SwiftUI

/// A simple wrapping (flow) layout — used to render the English output as word chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows = layout(subviews: subviews, maxWidth: maxWidth)
        let height = rows.totalHeight(lineSpacing: lineSpacing)
        let width = rows.maxRowWidth
        rows.removeAll()
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = layout(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows.items {
            var x = bounds.minX
            for item in row {
                let size = subviews[item.index].sizeThatFits(.unspecified)
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.map { subviews[$0.index].sizeThatFits(.unspecified).height }.max() ?? 0
            y += lineSpacing
        }
    }

    private struct Item { let index: Int }
    private struct Rows {
        var items: [[Item]] = []
        var rowHeights: [CGFloat] = []
        var maxRowWidth: CGFloat = 0
        mutating func removeAll() { items.removeAll() }
        func totalHeight(lineSpacing: CGFloat) -> CGFloat {
            guard !rowHeights.isEmpty else { return 0 }
            return rowHeights.reduce(0, +) + CGFloat(rowHeights.count - 1) * lineSpacing
        }
    }

    private func layout(subviews: Subviews, maxWidth: CGFloat) -> Rows {
        var rows = Rows()
        var current: [Item] = []
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !current.isEmpty, x + size.width > maxWidth {
                rows.items.append(current)
                rows.rowHeights.append(rowHeight)
                widest = max(widest, x - spacing)
                current = []
                x = 0
                rowHeight = 0
            }
            current.append(Item(index: index))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        if !current.isEmpty {
            rows.items.append(current)
            rows.rowHeights.append(rowHeight)
            widest = max(widest, x - spacing)
        }
        rows.maxRowWidth = widest
        return rows
    }
}

/// Tokenize text into whitespace-separated chunks (word + attached punctuation).
enum Tokenizer {
    static func chunks(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .map(String.init)
    }
}
