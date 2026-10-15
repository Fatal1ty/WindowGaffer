import AppKit
import WindowGafferCore

enum OverlayMetrics {
    static let font = NSFont.systemFont(ofSize: 15, weight: .semibold)
    static let horizontalPadding: CGFloat = 15
    static let verticalPadding: CGFloat = 10
    static let minimumSize = NSSize(width: 44, height: 38)
    static let maximumSize = NSSize(width: 244, height: 110)
    static let widthStep: CGFloat = 20
    static let heightStep: CGFloat = 12

    static func size(for label: String) -> NSSize {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        let constraint = NSSize(
            width: maximumSize.width - horizontalPadding * 2,
            height: maximumSize.height - verticalPadding * 2
        )
        let bounds = (label as NSString).boundingRect(
            with: constraint,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )

        let naturalSize = NSSize(
            width: min(
                maximumSize.width,
                max(minimumSize.width, ceil(bounds.width) + horizontalPadding * 2)
            ),
            height: min(
                maximumSize.height,
                max(minimumSize.height, ceil(bounds.height) + verticalPadding * 2)
            )
        )
        return steppedSize(for: naturalSize)
    }

    static func steppedSize(for proposed: NSSize) -> NSSize {
        SizeStepQuantizer.quantize(
            proposed,
            minimum: minimumSize,
            maximum: maximumSize,
            widthStep: widthStep,
            heightStep: heightStep
        )
    }
}
