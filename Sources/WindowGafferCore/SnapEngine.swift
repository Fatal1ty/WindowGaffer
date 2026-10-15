import CoreGraphics
import Foundation

public struct SnapResult: Equatable, Sendable {
    public var frame: CGRect
    public var snappedHorizontally: Bool
    public var snappedVertically: Bool

    public init(
        frame: CGRect,
        snappedHorizontally: Bool,
        snappedVertically: Bool
    ) {
        self.frame = frame
        self.snappedHorizontally = snappedHorizontally
        self.snappedVertically = snappedVertically
    }
}

public enum SnapEngine {
    public static func snap(
        _ proposedFrame: CGRect,
        to otherFrames: [CGRect],
        screenFrames: [CGRect] = [],
        threshold: CGFloat = 10
    ) -> SnapResult {
        var result = proposedFrame

        let xCandidate = closestCandidate(
            current: proposedFrame.minX,
            candidates: horizontalCandidates(
                for: proposedFrame,
                otherFrames: otherFrames,
                screenFrames: screenFrames,
                threshold: threshold
            ),
            threshold: threshold
        )

        if let xCandidate {
            result.origin.x = xCandidate
        }

        let yCandidate = closestCandidate(
            current: proposedFrame.minY,
            candidates: verticalCandidates(
                for: result,
                otherFrames: otherFrames,
                screenFrames: screenFrames,
                threshold: threshold
            ),
            threshold: threshold
        )

        if let yCandidate {
            result.origin.y = yCandidate
        }

        return SnapResult(
            frame: result.integral,
            snappedHorizontally: xCandidate != nil,
            snappedVertically: yCandidate != nil
        )
    }

    private static func horizontalCandidates(
        for moving: CGRect,
        otherFrames: [CGRect],
        screenFrames: [CGRect],
        threshold: CGFloat
    ) -> [CGFloat] {
        var candidates: [CGFloat] = []

        for other in otherFrames {
            // Column alignment does not require the overlays to touch. Aligning
            // left edges, centers, or right edges should work across a Space.
            candidates.append(other.minX)
            candidates.append(other.midX - moving.width / 2)
            candidates.append(other.maxX - moving.width)

            let verticallyRelevant = intervalsOverlap(
                moving.minY,
                moving.maxY,
                other.minY - threshold,
                other.maxY + threshold
            )

            if verticallyRelevant {
                candidates.append(other.minX - moving.width)
                candidates.append(other.maxX)
            }
        }

        for screen in screenFrames {
            candidates.append(screen.minX)
            candidates.append(screen.maxX - moving.width)
        }

        return candidates
    }

    private static func verticalCandidates(
        for moving: CGRect,
        otherFrames: [CGRect],
        screenFrames: [CGRect],
        threshold: CGFloat
    ) -> [CGFloat] {
        var candidates: [CGFloat] = []

        for other in otherFrames {
            // Row alignment likewise works for separated overlays: bottom edge,
            // vertical center, and top edge are all valid magnetic guides.
            candidates.append(other.minY)
            candidates.append(other.midY - moving.height / 2)
            candidates.append(other.maxY - moving.height)

            let horizontallyRelevant = intervalsOverlap(
                moving.minX,
                moving.maxX,
                other.minX - threshold,
                other.maxX + threshold
            )

            if horizontallyRelevant {
                candidates.append(other.minY - moving.height)
                candidates.append(other.maxY)
            }
        }

        for screen in screenFrames {
            candidates.append(screen.minY)
            candidates.append(screen.maxY - moving.height)
        }

        return candidates
    }

    private static func closestCandidate(
        current: CGFloat,
        candidates: [CGFloat],
        threshold: CGFloat
    ) -> CGFloat? {
        candidates
            .map { (value: $0, distance: abs($0 - current)) }
            .filter { $0.distance <= threshold }
            .min { lhs, rhs in lhs.distance < rhs.distance }?
            .value
    }

    private static func intervalsOverlap(
        _ firstMin: CGFloat,
        _ firstMax: CGFloat,
        _ secondMin: CGFloat,
        _ secondMax: CGFloat
    ) -> Bool {
        firstMax >= secondMin && secondMax >= firstMin
    }
}
