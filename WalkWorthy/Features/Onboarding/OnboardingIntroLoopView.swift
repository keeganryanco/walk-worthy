import AVFoundation
import SwiftUI

struct OnboardingIntroLoopView: View {
    var size: CGFloat = 220

    private var videoURL: URL? {
        let resolver = Bundle.main
        let supportedExtensions = ["mov", "mp4", "m4v"]

        for ext in supportedExtensions {
            if let url = resolver.url(forResource: "OnboardingIntroLoop", withExtension: ext) {
                return url
            }
        }
        return nil
    }

    var body: some View {
        Group {
            if let videoURL {
                LoopingVideoPlayerView(url: videoURL)
                    .accessibilityHidden(true)
            } else {
                Image("TendMark")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(
            Text(
                L10n.string(
                    "onboarding.intro.logo_accessibility",
                    default: "Tend logo animation"
                )
            )
        )
    }
}

private struct LoopingVideoPlayerView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> LoopingPlayerContainerView {
        let view = LoopingPlayerContainerView()
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        let looper = AVPlayerLooper(player: player, templateItem: item)

        player.isMuted = true
        player.playImmediately(atRate: 1.0)

        view.playerLayer.player = player

        context.coordinator.player = player
        context.coordinator.looper = looper

        return view
    }

    func updateUIView(_ uiView: LoopingPlayerContainerView, context: Context) {
        if context.coordinator.player?.timeControlStatus != .playing {
            context.coordinator.player?.play()
        }
    }

    static func dismantleUIView(_ uiView: LoopingPlayerContainerView, coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.player = nil
        coordinator.looper = nil
        uiView.playerLayer.player = nil
    }

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }
}

private final class LoopingPlayerContainerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        guard let layer = self.layer as? AVPlayerLayer else {
            fatalError("Expected AVPlayerLayer backing layer.")
        }
        return layer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        playerLayer.videoGravity = .resizeAspect
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
