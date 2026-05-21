import AVKit
import Flutter

class PipManager: NSObject {

    var currentPlayer: FVPVideoPlayer?
    var pipController: AVPictureInPictureController?
    var avPlayerLayer: AVPlayerLayer?
    weak var registrar: FlutterPluginRegistrar?
    var placeHolderPlayer: AVPlayer?

    var enablePlaceholderVideo: Bool = false
    var pipEnabled: Bool = false

    func setCurrentPlayer(_ player: FVPVideoPlayer?) {
        if let current = currentPlayer, current !== player {
            current.setEnableFrameUpdate(true)
            currentPlayer = nil
        }

        currentPlayer = player

        if let playerLayer = avPlayerLayer {
            if let player = player {
                playerLayer.player = player.player
            } else {
                if enablePlaceholderVideo {
                    playBlackScreenVideo()
                } else {
                    playerLayer.player = nil
                }
            }
        }
    }

    func onPipDidStart() {
        currentPlayer?.setEnableFrameUpdate(false)
    }

    func onPipDidStop() {
        if currentPlayer != nil {
            setCurrentPlayer(nil)
        }

        avPlayerLayer?.removeFromSuperlayer()
        disposeBlackScreenVideo()
    }

    func onDisposePlayer(_ player: FVPVideoPlayer) {
        if currentPlayer === player {
            currentPlayer = nil

            if let playerLayer = avPlayerLayer,
               playerLayer.player === player.player,
               !enablePlaceholderVideo {
                playerLayer.player = nil
            }
        }

        if enablePlaceholderVideo && pipEnabled {
            playBlackScreenVideo()
        }
    }

    func playBlackScreenVideo() {
        #if os(iOS)
        guard let registrar = registrar else { return }

        let assetPath = registrar.lookupKey(forAsset: "assets/mp4/pip_black.mp4")
        let bundlePath = Bundle.main.path(forResource: assetPath, ofType: nil)

        guard let path = bundlePath,
              let playerLayer = avPlayerLayer,
              pipController != nil else {
            return
        }

        if let placeholder = placeHolderPlayer {
            placeholder.pause()
            placeHolderPlayer = nil
        }

        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let playerItem = AVPlayerItem(asset: asset)
        let placeholder = AVPlayer(playerItem: playerItem)

        placeholder.isMuted = true
        placeholder.allowsExternalPlayback = true
        placeholder.isAccessibilityElement = false

        placeholder.play()
        placeHolderPlayer = placeholder
        playerLayer.player = placeholder

        if let current = currentPlayer {
            current.setEnableFrameUpdate(true)
            currentPlayer = nil
        }
        #endif
    }

    func disposeBlackScreenVideo() {
        if let placeholder = placeHolderPlayer {
            if avPlayerLayer?.player === placeholder {
                avPlayerLayer?.player = nil
            }

            placeholder.pause()
            placeholder.replaceCurrentItem(with: nil)
            placeHolderPlayer = nil
        }
    }
}