import CoreGraphics

/// Maps free-form drag sizes onto a shared grid. Because every overlay uses the
/// same minimum and step, matching sizes never require pixel-level adjustment.
public enum SizeStepQuantizer {
    public static func quantize(
        _ proposed: CGSize,
        minimum: CGSize,
        maximum: CGSize,
        widthStep: CGFloat,
        heightStep: CGFloat
    ) -> CGSize {
        CGSize(
            width: quantize(
                proposed.width,
                minimum: minimum.width,
                maximum: maximum.width,
                step: widthStep
            ),
            height: quantize(
                proposed.height,
                minimum: minimum.height,
                maximum: maximum.height,
                step: heightStep
            )
        )
    }

    private static func quantize(
        _ proposed: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat,
        step: CGFloat
    ) -> CGFloat {
        guard step > 0 else {
            return min(maximum, max(minimum, proposed))
        }

        let clamped = min(maximum, max(minimum, proposed))
        let stepIndex = ((clamped - minimum) / step).rounded()
        return min(maximum, minimum + stepIndex * step)
    }
}
