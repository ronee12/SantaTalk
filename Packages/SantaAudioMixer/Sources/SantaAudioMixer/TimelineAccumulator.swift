/// A growable timeline of mono float samples that callers write into at absolute
/// frame positions. Overlapping writes sum, gaps read as silence.
///
/// The two sides of a call arrive on independent audio threads with no shared
/// clock, so neither can be treated as "the" stream. Both are placed against
/// absolute frame positions instead, and the moments where they overlap — a
/// child talking over Santa — sum rather than one winning.
public struct TimelineAccumulator {

    /// Absolute frame index of `samples[0]`. Everything before this has been
    /// drained and written; late audio landing there is gone.
    public private(set) var baseFrame: Int

    private var samples: [Float] = []

    public init(baseFrame: Int = 0) {
        self.baseFrame = baseFrame
    }

    /// One past the last frame currently held.
    public var endFrame: Int { baseFrame + samples.count }

    /// Sums `block` into the timeline starting at absolute `frame`.
    ///
    /// A block that straddles `baseFrame` keeps its tail; the already-written
    /// prefix is dropped rather than the whole block, so a late buffer still
    /// contributes what it can.
    public mutating func add(_ block: [Float], at frame: Int) {
        var block = block
        var frame = frame

        if frame < baseFrame {
            let dropped = baseFrame - frame
            guard dropped < block.count else { return }
            block.removeFirst(dropped)
            frame = baseFrame
        }

        let offset = frame - baseFrame
        let needed = offset + block.count
        if samples.count < needed {
            samples.append(contentsOf: repeatElement(0, count: needed - samples.count))
        }
        for index in block.indices {
            samples[offset + index] += block[index]
        }
    }

    /// Removes and returns every frame before `frame`, clipped to `[-1, 1]`.
    ///
    /// The timeline is padded with silence if `frame` runs past the end, so the
    /// emitted audio is always contiguous — a silent stretch where nobody spoke
    /// still occupies its real duration.
    public mutating func drain(upTo frame: Int) -> (startFrame: Int, samples: [Float])? {
        let count = frame - baseFrame
        guard count > 0 else { return nil }

        if samples.count < count {
            samples.append(contentsOf: repeatElement(0, count: count - samples.count))
        }

        // Two voices at full scale would wrap without this, which clicks.
        let drained = samples[0 ..< count].map { min(1, max(-1, $0)) }
        samples.removeFirst(count)
        let start = baseFrame
        baseFrame += count
        return (start, drained)
    }

    /// Removes and returns everything still held.
    public mutating func drainAll() -> (startFrame: Int, samples: [Float])? {
        drain(upTo: endFrame)
    }
}
