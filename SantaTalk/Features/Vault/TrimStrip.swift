import SwiftUI

/// The timeline: thumbnails of the composed video, the conversation's waveform
/// over them, and two handles.
///
/// It shows a *window* onto the call rather than the whole call, because a
/// three-minute recording across a phone's width is half a second per point and
/// nobody can trim that. Pinch narrows the window, dragging the background moves
/// it, and the handles keep working the same way at every zoom.
struct TrimStrip: View {

    let thumbnails: [TrimShareModel.Thumbnail]
    let waveform: [Float]
    let duration: Double
    let start: Double
    let end: Double
    let position: Double
    let onStartChanged: (Double) -> Void
    let onEndChanged: (Double) -> Void
    let onScrub: (Double) -> Void

    private static let height: CGFloat = 78
    private static let handleWidth: CGFloat = 13
    private static let maximumZoom: Double = 8

    @State private var windowStart: Double = 0
    @State private var windowLength: Double = 0
    @State private var panAnchor: Double?
    @State private var zoomAnchor: Double?

    private var space: NamedCoordinateSpace { .named("trim-strip") }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let window = resolvedWindow

            ZStack(alignment: .topLeading) {
                filmstrip(width: width, window: window)
                waveformOverlay(width: width, window: window)
                shading(width: width, window: window)
                selectionFrame(width: width, window: window)
                playhead(width: width, window: window)
                handles(width: width, window: window)
            }
            .frame(width: width, height: Self.height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(.rect)
            .coordinateSpace(space)
            .gesture(panGesture(width: width))
            .gesture(zoomGesture)
            .onTapGesture { location in
                onScrub(time(at: location.x, width: width, window: window))
            }
        }
        .frame(height: Self.height)
        .onAppear { if windowLength == 0 { windowLength = duration } }
        .onChange(of: duration) { _, new in
            windowStart = 0
            windowLength = new
        }
        .accessibilityElement()
        .accessibilityLabel("Trim range")
        .accessibilityValue("From \(Format.duration(Int(start))) to \(Format.duration(Int(end)))")
    }

    // MARK: The window

    private var resolvedWindow: ClosedRange<Double> {
        guard duration > 0 else { return 0...1 }
        let length = min(max(windowLength > 0 ? windowLength : duration,
                             duration / Self.maximumZoom), duration)
        let origin = min(max(0, windowStart), duration - length)
        return origin...(origin + length)
    }

    private func x(for seconds: Double, width: CGFloat, window: ClosedRange<Double>) -> CGFloat {
        let span = window.upperBound - window.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat((seconds - window.lowerBound) / span) * width
    }

    private func time(at x: CGFloat, width: CGFloat, window: ClosedRange<Double>) -> Double {
        guard width > 0 else { return 0 }
        let span = window.upperBound - window.lowerBound
        return window.lowerBound + Double(x / width) * span
    }

    // MARK: Layers

    private func filmstrip(width: CGFloat, window: ClosedRange<Double>) -> some View {
        ZStack(alignment: .topLeading) {
            Palette.pictureInPicture

            if !thumbnails.isEmpty, duration > 0 {
                let slice = duration / Double(thumbnails.count)
                let cellWidth = CGFloat(slice / (window.upperBound - window.lowerBound)) * width

                ForEach(thumbnails) { thumbnail in
                    Image(decorative: thumbnail.image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: max(1, cellWidth), height: Self.height)
                        .clipped()
                        .offset(x: x(for: Double(thumbnail.id) * slice, width: width, window: window))
                }
            }
        }
        .frame(width: width, height: Self.height)
        .clipped()
    }

    /// Drawn over the pictures at low contrast — it is a reading aid, not the
    /// subject.
    private func waveformOverlay(width: CGFloat, window: ClosedRange<Double>) -> some View {
        Canvas { context, size in
            guard !waveform.isEmpty, duration > 0 else { return }

            let step: CGFloat = 3
            var offset: CGFloat = 0
            while offset < size.width {
                let seconds = time(at: offset, width: width, window: window)
                let index = min(waveform.count - 1,
                                max(0, Int(seconds / duration * Double(waveform.count))))
                let height = max(2, CGFloat(waveform[index]) * size.height * 0.72)
                let bar = CGRect(x: offset, y: (size.height - height) / 2,
                                 width: 2, height: height)
                context.fill(
                    Path(roundedRect: bar, cornerRadius: 1),
                    with: .color(Palette.snow.opacity(0.5))
                )
                offset += step
            }
        }
        .frame(width: width, height: Self.height)
        .allowsHitTesting(false)
    }

    private func shading(width: CGFloat, window: ClosedRange<Double>) -> some View {
        let startX = x(for: start, width: width, window: window)
        let endX = x(for: end, width: width, window: window)

        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.58)
                .frame(width: max(0, min(startX, width)), height: Self.height)

            Color.black.opacity(0.58)
                .frame(width: max(0, width - max(0, endX)), height: Self.height)
                .offset(x: max(0, min(endX, width)))
        }
        .allowsHitTesting(false)
    }

    private func selectionFrame(width: CGFloat, window: ClosedRange<Double>) -> some View {
        let startX = x(for: start, width: width, window: window)
        let endX = x(for: end, width: width, window: window)

        return Rectangle()
            .stroke(Palette.firelight, lineWidth: 3)
            .frame(width: max(0, endX - startX), height: Self.height)
            .offset(x: startX)
            .allowsHitTesting(false)
    }

    private func playhead(width: CGFloat, window: ClosedRange<Double>) -> some View {
        Capsule()
            .fill(Palette.snow)
            .frame(width: 2, height: Self.height)
            .shadow(color: .black.opacity(0.6), radius: 3)
            .offset(x: x(for: position, width: width, window: window) - 1)
            .allowsHitTesting(false)
    }

    private func handles(width: CGFloat, window: ClosedRange<Double>) -> some View {
        ZStack(alignment: .topLeading) {
            handle(at: start, width: width, window: window, isLeading: true) { seconds in
                onStartChanged(seconds)
            }
            handle(at: end, width: width, window: window, isLeading: false) { seconds in
                onEndChanged(seconds)
            }
        }
    }

    private func handle(
        at seconds: Double,
        width: CGFloat,
        window: ClosedRange<Double>,
        isLeading: Bool,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        let centre = x(for: seconds, width: width, window: window)
        let grip = isLeading ? centre - Self.handleWidth : centre
        let padding: CGFloat = 15

        // The visible grip stays narrow so it hides as little of the picture as
        // possible; the tap target around it does not have to.
        return Color.clear
            .frame(width: Self.handleWidth + padding * 2, height: Self.height)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Palette.firelight)
                    .frame(width: Self.handleWidth, height: Self.height)
                    .overlay {
                        Capsule()
                            .fill(Palette.onAmber.opacity(0.55))
                            .frame(width: 2, height: 22)
                    }
            }
            .contentShape(.rect)
            .offset(x: grip - padding)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: space)
                    .onChanged { value in
                        onChange(time(at: value.location.x, width: width, window: window))
                    }
            )
            .accessibilityLabel(isLeading ? "Clip start" : "Clip end")
    }

    // MARK: Gestures

    private func panGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: space)
            .onChanged { value in
                let window = resolvedWindow
                let span = window.upperBound - window.lowerBound
                let anchor = panAnchor ?? window.lowerBound
                panAnchor = anchor
                let shift = Double(-value.translation.width / width) * span
                windowStart = min(max(0, anchor + shift), duration - span)
            }
            .onEnded { _ in panAnchor = nil }
    }

    /// Zooms around the middle of what is on screen, which is where a parent is
    /// looking when they pinch.
    private var zoomGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                let window = resolvedWindow
                let anchor = zoomAnchor ?? (window.upperBound - window.lowerBound)
                zoomAnchor = anchor

                let centre = (window.lowerBound + window.upperBound) / 2
                let length = min(max(anchor / value.magnification, duration / Self.maximumZoom),
                                 duration)
                windowLength = length
                windowStart = min(max(0, centre - length / 2), duration - length)
            }
            .onEnded { _ in zoomAnchor = nil }
    }
}
