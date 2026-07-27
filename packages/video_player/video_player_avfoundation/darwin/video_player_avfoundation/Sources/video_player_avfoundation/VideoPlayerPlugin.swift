// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation
import AVKit

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#else
  #error("Unsupported platform.")
#endif

#if canImport(video_player_avfoundation_objc)
  import video_player_avfoundation_objc
#endif

// Protocol for an display link factory. Used for injecting display links in tests.
protocol DisplayLinkFactory {
  func displayLink(
    with viewProvider: FVPViewProvider,
    callback: @escaping () -> Void
  ) -> FVPDisplayLink
}

/// Non-test implementation of the display link factory.
final class DefaultDisplayLinkFactory: DisplayLinkFactory {
  func displayLink(
    with viewProvider: FVPViewProvider,
    callback: @escaping () -> Void
  ) -> FVPDisplayLink {
    #if os(iOS)
      return FVPCADisplayLink(viewProvider: viewProvider, callback: callback)
    #elseif os(macOS)
      if #available(macOS 14.0, *) {
        return FVPCADisplayLink(viewProvider: viewProvider, callback: callback)
      }
      return FVPCoreVideoDisplayLink(viewProvider: viewProvider, callback: callback)
    #endif
  }
}

/// Non-test implementation of FVPAssetProvider, wrapping a Flutter plugin
/// registrar.
final class DefaultAssetProvider: NSObject, FVPAssetProvider {
  private weak var registrar: FlutterPluginRegistrar?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  func lookupKey(forAsset asset: String) -> String? {
    return registrar?.lookupKey(forAsset: asset)
  }

  func lookupKey(forAsset asset: String, fromPackage package: String) -> String? {
    return registrar?.lookupKey(forAsset: asset, fromPackage: package)
  }
}

public final class VideoPlayerPlugin: NSObject, FlutterPlugin, AVFoundationVideoPlayerApi {
  private let binaryMessenger: FlutterBinaryMessenger
  private let textureRegistry: FlutterTextureRegistry
  private let displayLinkFactory: DisplayLinkFactory
  private let avFactory: FVPAVFactory
  private let viewProvider: FVPViewProvider
  private let assetProvider: FVPAssetProvider
  private var nextPlayerIdentifier: Int64 = 1
  var playersByIdentifier: [Int64: FVPVideoPlayer] = [:]

/// TUNGPX
    var mainPlayers: [FVPVideoPlayer] = []
    var pipManager: PipManager? = nil
    var registrar: FlutterPluginRegistrar? = nil
///

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = VideoPlayerPlugin(registrar: registrar)
    // Publish the instance so that it receives detachFromEngine.
    registrar.publish(instance)

    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let factory = NativeVideoViewFactory(
      messenger: messenger,
      playerByIdentifierProvider: {
        [weak instance] (playerIdentifier: Int64) -> FVPVideoPlayer? in
        return instance?.playersByIdentifier[playerIdentifier]
      }
    )
    registrar.register(factory, withId: "plugins.flutter.dev/video_player_ios")

    AVFoundationVideoPlayerApiSetup.setUp(binaryMessenger: messenger, api: instance)
  }

  convenience init(registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
      let textures = registrar.textures()
    #else
      let messenger = registrar.messenger
      let textures = registrar.textures
    #endif
    self.init(
      avFactory: FVPDefaultAVFactory(),
      displayLinkFactory: DefaultDisplayLinkFactory(),
      binaryMessenger: messenger,
      textureRegistry: textures,
      viewProvider: FVPDefaultViewProvider(registrar: registrar),
      assetProvider: DefaultAssetProvider(registrar: registrar)
    )
    self.registrar = registrar;
  }

  init(
    avFactory: FVPAVFactory,
    displayLinkFactory: DisplayLinkFactory,
    binaryMessenger: FlutterBinaryMessenger,
    textureRegistry: FlutterTextureRegistry,
    viewProvider: FVPViewProvider,
    assetProvider: FVPAssetProvider
  ) {
    self.binaryMessenger = binaryMessenger
    self.textureRegistry = textureRegistry
    self.assetProvider = assetProvider
    self.viewProvider = viewProvider
    self.displayLinkFactory = displayLinkFactory
    self.avFactory = avFactory
    super.init()
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    for player in playersByIdentifier.values {
      // Remove the channel and texture cleanup, and the event listener, to ensure that the player
      // doesn't message the engine that is no longer connected.
      player.onDisposed = nil
      player.eventListener = nil
      var error: FlutterError?
      player.disposeWithError(&error)
    }
    playersByIdentifier.removeAll()
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    AVFoundationVideoPlayerApiSetup.setUp(binaryMessenger: messenger, api: nil)
  }

  func initialize() throws {
    #if os(iOS)
      // Allow audio playback when the Ring/Silent switch is set to silent
      upgradeAudioSessionCategory(
        session: avFactory.sharedAudioSession(),
        requestedCategory: .playback,
        options: [],
        clearOptions: []
      )
    #endif

    for player in playersByIdentifier.values {
      var error: FlutterError?
      player.disposeWithError(&error)
    }
    playersByIdentifier.removeAll()
    mainPlayers.removeAll();
  }

func _onCreatedNewMainPlayer(_ player: FVPVideoPlayer, _ options: CreationOptions) {
    if options.extraOption != nil &&
       options.extraOption?["playerType"] as? String == "main" {
        mainPlayers.append(player)

        // Show in pip player
        _showInPipWhenReady(player)
    }
}

private func _showInPipWhenReady(_ player: FVPVideoPlayer) {
    if pipManager == nil ||
       !pipManager!.pipEnabled ||
       pipManager!.pipController == nil ||
       !pipManager!.pipController!.isPictureInPictureActive ||
       mainPlayers.last !== player {
        return
    }
    if player.getAVPlayerLayer() == nil {
        return
    }
    let avPlayer = player.player
    if avPlayer.currentItem?.status == .readyToPlay {
        let wasPlaying = avPlayer.rate > 0
        player.getAVPlayerLayer()?.player = nil
        player.setEnableFrameUpdate(false)
        pipManager!.setCurrentPlayer(player)
        if wasPlaying {
            avPlayer.pause()
            avPlayer.play()
        }
        return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak player] in
        guard let self = self,
              let player = player else { return }
            self._showInPipWhenReady(player)
    }
}

  func createPlatformViewPlayer(options params: CreationOptions) throws -> Int64 {
    let item = try playerItem(with: params)
    let player = FVPVideoPlayer(playerItem: item, avFactory: avFactory, viewProvider: viewProvider)
    _onCreatedNewMainPlayer(player, params);
    return configurePlayer(player, extraDisposeHandler: nil)
  }

  func createTexturePlayer(options creationOptions: CreationOptions) throws -> TexturePlayerIds {
    let item = try playerItem(with: creationOptions)
    let frameUpdater = FVPFrameUpdater(registry: textureRegistry)
    let displayLink = displayLinkFactory.displayLink(with: viewProvider) {
      frameUpdater.displayLinkFired()
    }

    let player = FVPTextureBasedVideoPlayer(
      playerItem: item,
      frameUpdater: frameUpdater,
      displayLink: displayLink,
      avFactory: avFactory,
      viewProvider: viewProvider
    )

    let textureId = textureRegistry.register(player)
    player.setTextureIdentifier(textureId)

    let playerId = configurePlayer(player) { [weak self] in
      self?.textureRegistry.unregisterTexture(textureId)
    }
    _onCreatedNewMainPlayer(player, creationOptions);
    return TexturePlayerIds(playerId: playerId, textureId: textureId)
  }

  func setMixWithOthers(_ mixWithOthers: Bool) throws {
    #if os(iOS)
      let session = avFactory.sharedAudioSession()
      if mixWithOthers {
        upgradeAudioSessionCategory(
          session: session,
          requestedCategory: session.category,
          options: .mixWithOthers,
          clearOptions: []
        )
      } else {
        upgradeAudioSessionCategory(
          session: session,
          requestedCategory: session.category,
          options: [],
          clearOptions: .mixWithOthers
        )
      }
    #endif
    // AVAudioSession doesn't exist on macOS, and audio always mixes, so just no-op.
  }

  func fileURLForAsset(name asset: String, package: String?) throws -> String? {
    let resource =
      if let package = package {
        assetProvider.lookupKey(forAsset: asset, fromPackage: package)
      } else {
        assetProvider.lookupKey(forAsset: asset)
      }

    var path = Bundle.main.path(forResource: resource, ofType: nil)
    #if os(macOS)
      // See https://github.com/flutter/flutter/issues/135302
      // TODO(stuartmorgan): Remove this if the asset APIs are adjusted to work better for macOS.
      if path == nil, let resource = resource {
        path = URL(string: resource, relativeTo: Bundle.main.bundleURL)?.path
      }
    #endif

    guard let validPath = path else {
      return nil
    }
    return URL(fileURLWithPath: validPath).absoluteString
  }

  // MARK: - Private

  private func configurePlayer(
    _ player: FVPVideoPlayer,
    extraDisposeHandler: (() -> Void)?
  ) -> Int64 {
    let playerId = nextPlayerIdentifier
    nextPlayerIdentifier += 1
    playersByIdentifier[playerId] = player

    let channelSuffix = "\(playerId)"
    // Set up the player-specific API handler, and its onDispose unregistration.
    SetUpFVPVideoPlayerInstanceApiWithSuffix(binaryMessenger, player, channelSuffix)
    /// TUNGPX
    player.beforeDisposed = { [weak self, weak player] in
      guard let strongSelf = self , let player = player else { return }
      if strongSelf.pipManager != nil && strongSelf.mainPlayers.contains(where: { $0 === player }) {
          strongSelf.pipManager!.onDisposePlayer(player)
      }
      strongSelf.mainPlayers.removeAll { $0 === player }
    }
    ///
    player.onDisposed = { [weak self] in
      guard let strongSelf = self else { return }
      SetUpFVPVideoPlayerInstanceApiWithSuffix(strongSelf.binaryMessenger, nil, channelSuffix)
      extraDisposeHandler?()
      strongSelf.playersByIdentifier.removeValue(forKey: playerId)
    }

    // Set up the event channel.
    let eventBridge = FVPEventBridge(
      messenger: binaryMessenger,
      channelName: "flutter.dev/videoPlayer/videoEvents\(channelSuffix)"
    )
    player.eventListener = eventBridge

    return playerId
  }

  private func playerItem(with options: CreationOptions) throws -> FVPAVPlayerItem {
    let headers = options.httpHeaders
    let itemOptions = headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers]
    guard let url = URL(string: options.uri) else {
      throw PigeonError(code: "video_player", message: "Invalid URI", details: nil)
    }
    let asset = avFactory.urlAsset(with: url, options: itemOptions)
    return avFactory.playerItem(with: asset, extraOption: options.extraOption)
  }

    /// TUNGPX
    func FVPActiveWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else {
                    continue
                }

                if scene.activationState == .foregroundActive {
                    for candidate in windowScene.windows {
                        if candidate.isKeyWindow {
                            return candidate
                        }
                    }
                }
            }

            for window in UIApplication.shared.windows {
                if window.isKeyWindow {
                    return window
                }
            }
        }

        return UIApplication.shared.keyWindow
    }

    func enablePictureInPicture(command: String, data: [String?: Any?]?) throws -> Int64 {
    #if os(iOS)
        NSLog("enablePictureInPicture command: %@", command)

        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            NSLog("PictureInPicture IS NOT Supported")
            return 0
        }

        guard let rootWindow = FVPActiveWindow(),
              let rootViewController = rootWindow.rootViewController else {
            return 0
        }

        var shouldDisable = false

        if pipManager == nil {
            let manager = PipManager()
            manager.enablePlaceholderVideo = true
            manager.registrar = registrar

            let playerLayer = AVPlayerLayer(player: nil)
            playerLayer.isHidden = true
            manager.avPlayerLayer = playerLayer

            let pipController = AVPictureInPictureController(playerLayer: playerLayer)
            pipController?.delegate = self
            manager.pipController = pipController
            manager.pipEnabled = false

            pipManager = manager
        } else {
            shouldDisable = true
        }

        guard let pipManager = pipManager else { return 0 }

        if pipManager.avPlayerLayer?.superlayer !== rootViewController.view.layer {
            shouldDisable = false
            pipManager.avPlayerLayer?.removeFromSuperlayer()
            if let playerLayer = pipManager.avPlayerLayer {
                rootViewController.view.layer.addSublayer(playerLayer)
            }
        }

        switch command {
        case "disable":
            if let controller = pipManager.pipController {
                pipManager.onPipDidStop()
                controller.stopPictureInPicture()
            }

        case "enable":
            if shouldDisable {
                if let controller = pipManager.pipController,
                   controller.isPictureInPictureActive,
                   mainPlayers.count > 0 {
                    controller.stopPictureInPicture()
                    return 1
                }
            }

            var x: CGFloat = 0
            var y: CGFloat = 30
            var width: CGFloat = UIScreen.main.bounds.width
            var height: CGFloat = width * 9 / 16

            if let left = data?["left"] as? NSNumber {
                x = CGFloat(left.doubleValue)
            }
            if let top = data?["top"] as? NSNumber {
                y = CGFloat(top.doubleValue)
            }
            if let mWidth = data?["width"] as? NSNumber {
                width = CGFloat(mWidth.doubleValue)
            }
            if let mHeight = data?["height"] as? NSNumber {
                height = CGFloat(mHeight.doubleValue)
            }

            pipManager.avPlayerLayer?.frame = CGRect(x: x, y: y, width: width, height: height)

            if mainPlayers.count > 0,
               let player = mainPlayers.last {
                if let playerLayer = player.getAVPlayerLayer() {
                    playerLayer.player = nil
                }
                pipManager.setCurrentPlayer(player)
            } else {
                pipManager.avPlayerLayer?.player = nil
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NSLog("pipController startPictureInPicture")
                self.pipManager?.pipController?.startPictureInPicture()
            }

            return 1

        case "enablePlaceholderVideo":
            pipManager.enablePlaceholderVideo = true

        case "disablePlaceholderVideo":
            pipManager.enablePlaceholderVideo = false

        case "playBlackScreenVideo":
            pipManager.playBlackScreenVideo()

        case "disposeBlackScreenVideo":
            pipManager.disposeBlackScreenVideo()

        default:
            break
        }

        return 1

    #else
        return 0
    #endif
    }
}

#if os(iOS)
  // This function, although slightly modified, is also in camera_avfoundation.
  // Both need to do the same thing and run on the same thread (for example main thread).
  // Do not overwrite PlayAndRecord with Playback which causes inability to record
  // audio, do not overwrite all options.
  // Only change category if it is considered an upgrade which means it can only enable
  // ability to play in silent mode or ability to record audio but never disables it,
  // that could affect other plugins which depend on this global state. Only change
  // category or options if there is change to prevent unnecessary lags and silence.
  private func upgradeAudioSessionCategory(
    session: FVPAVAudioSession,
    requestedCategory: AVAudioSession.Category,
    options: AVAudioSession.CategoryOptions,
    clearOptions: AVAudioSession.CategoryOptions
  ) {
    let playCategories: Set<AVAudioSession.Category> = [.playback, .playAndRecord]
    let recordCategories: Set<AVAudioSession.Category> = [.record, .playAndRecord]
    let requiredCategories: Set<AVAudioSession.Category> = [requestedCategory, session.category]

    let requiresPlay = !requiredCategories.isDisjoint(with: playCategories)
    let requiresRecord = !requiredCategories.isDisjoint(with: recordCategories)

    var finalCategory = requestedCategory
    if requiresPlay && requiresRecord {
      finalCategory = .playAndRecord
    } else if requiresPlay {
      finalCategory = .playback
    } else if requiresRecord {
      finalCategory = .record
    }

    let newOptions = session.categoryOptions.subtracting(clearOptions).union(options)

    if finalCategory == session.category && newOptions == session.categoryOptions {
      return
    }

    try? session.setCategory(finalCategory, with: newOptions)
  }
#endif


/// TUNGPX
extension VideoPlayerPlugin: AVPictureInPictureControllerDelegate {
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        NSLog("pictureInPictureControllerWillStartPictureInPicture")
        pipManager?.pipEnabled = true
    }

    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        NSLog("pictureInPictureControllerDidStartPictureInPicture")
        pipManager?.pipEnabled = true
        pipManager?.onPipDidStart()
    }

    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        NSLog("failedToStartPictureInPictureWithError %@", error.localizedDescription)
        pipManager?.pipEnabled = false
        pipManager?.onPipDidStop()
    }

    public func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        NSLog("pictureInPictureControllerWillStopPictureInPicture")
        pipManager?.pipEnabled = false
    }

    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        NSLog("pictureInPictureControllerDidStopPictureInPicture")
        pipManager?.pipEnabled = false
        pipManager?.onPipDidStop()
    }

    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        NSLog("restoreUserInterfaceForPictureInPictureStopWithCompletionHandler")
        completionHandler(true)
    }
}
///
