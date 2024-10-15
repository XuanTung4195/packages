// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static androidx.media3.common.Player.REPEAT_MODE_ALL;
import static androidx.media3.common.Player.REPEAT_MODE_OFF;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RestrictTo;
import androidx.annotation.VisibleForTesting;
import androidx.media3.common.AudioAttributes;
import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackParameters;
import androidx.media3.exoplayer.ExoPlayer;
import io.flutter.view.TextureRegistry;
import androidx.media3.common.util.UnstableApi;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import io.flutter.plugins.videoplayer.custom.BuildDataSourceHelper;
import io.flutter.plugins.videoplayer.custom.PlayerDataSource;
import androidx.media3.exoplayer.source.TrackGroupArray;
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector;
import androidx.media3.exoplayer.trackselection.MappingTrackSelector;
import androidx.media3.exoplayer.trackselection.TrackSelector;
import androidx.media3.exoplayer.upstream.DefaultBandwidthMeter;
import androidx.media3.common.TrackGroup;
import androidx.media3.common.util.UnstableApi;
import androidx.annotation.OptIn;
import androidx.media3.exoplayer.source.MediaSource;
import androidx.media3.common.Format;

final class VideoPlayer implements TextureRegistry.SurfaceProducer.Callback {
  @NonNull private final ExoPlayerProvider exoPlayerProvider;
  @NonNull private final MediaItem mediaItem;
  @NonNull private final TextureRegistry.SurfaceProducer surfaceProducer;
  @NonNull private final VideoPlayerCallbacks videoPlayerEvents;
  @NonNull private final VideoPlayerOptions options;
  @NonNull private ExoPlayer exoPlayer;
  @Nullable private ExoPlayerState savedStateDuring;

  List<Map<String, String>> extraDatasource;
  private final DefaultTrackSelector trackSelector;
  private PlayerDataSource playerDataSource;
  VideoAsset asset;
  Context context;

  /**
   * Creates a video player.
   *
   * @param context application context.
   * @param events event callbacks.
   * @param surfaceProducer produces a texture to render to.
   * @param asset asset to play.
   * @param options options for playback.
   * @return a video player instance.
   */
  @NonNull
  static VideoPlayer create(
          @NonNull Context context,
          @NonNull VideoPlayerCallbacks events,
          @NonNull TextureRegistry.SurfaceProducer surfaceProducer,
          @NonNull VideoAsset asset,
          List<Map<String, String>> extraDatasource,
          @NonNull VideoPlayerOptions options) {
    DefaultTrackSelector trackSelector = new DefaultTrackSelector(context);
    return new VideoPlayer(
            context,
            () -> {
              ExoPlayer.Builder builder =
                      new ExoPlayer.Builder(context)
                              .setMediaSourceFactory(asset.getMediaSourceFactory(context));
              builder.setTrackSelector(trackSelector);
              return builder.build();
            },
            events,
            surfaceProducer,
            asset.getMediaItem(),
            asset,
            extraDatasource,
            trackSelector,
            options);
  }

  /** A closure-compatible signature since {@link java.util.function.Supplier} is API level 24. */
  interface ExoPlayerProvider {
    /**
     * Returns a new {@link ExoPlayer}.
     *
     * @return new instance.
     */
    ExoPlayer get();
  }

  @VisibleForTesting
  VideoPlayer(
          Context context,
          @NonNull ExoPlayerProvider exoPlayerProvider,
          @NonNull VideoPlayerCallbacks events,
          @NonNull TextureRegistry.SurfaceProducer surfaceProducer,
          @NonNull MediaItem mediaItem,
          VideoAsset asset,
          List<Map<String, String>> extraDatasource,
          DefaultTrackSelector trackSelector,
          @NonNull VideoPlayerOptions options) {
    this.context = context;
    this.exoPlayerProvider = exoPlayerProvider;
    this.videoPlayerEvents = events;
    this.surfaceProducer = surfaceProducer;
    this.mediaItem = mediaItem;
    this.options = options;
    this.extraDatasource = extraDatasource;
    this.trackSelector = trackSelector;
    this.asset = asset;
    this.exoPlayer = createVideoPlayer();
    surfaceProducer.setCallback(this);
  }

  @RestrictTo(RestrictTo.Scope.LIBRARY)
  // TODO(matanlurey): https://github.com/flutter/flutter/issues/155131.
  @SuppressWarnings({"deprecation", "removal"})
  public void onSurfaceCreated() {
    if (savedStateDuring != null) {
      exoPlayer = createVideoPlayer();
      savedStateDuring.restore(exoPlayer);
      savedStateDuring = null;
    }
  }

  @RestrictTo(RestrictTo.Scope.LIBRARY)
  public void onSurfaceDestroyed() {
    // Intentionally do not call pause/stop here, because the surface has already been released
    // at this point (see https://github.com/flutter/flutter/issues/156451).
    savedStateDuring = ExoPlayerState.save(exoPlayer);
    exoPlayer.release();
  }

  private ExoPlayer createVideoPlayer() {
    ExoPlayer exoPlayer = exoPlayerProvider.get();

    if (extraDatasource == null || extraDatasource.isEmpty()) {
      String dataSource = asset.assetUrl;
      if (dataSource != null && dataSource.endsWith(".m3u8")) {
        playerDataSource = new PlayerDataSource(context, new DefaultBandwidthMeter.Builder(context).build());
        MediaSource mediaSource = BuildDataSourceHelper.getHlsMediaSource(playerDataSource, dataSource);
        exoPlayer.setMediaSource(mediaSource);
      } else {
        exoPlayer.setMediaItem(mediaItem);
      }
    } else {
      playerDataSource = new PlayerDataSource(context, new DefaultBandwidthMeter.Builder(context).build());
      MediaSource mediaSource = BuildDataSourceHelper.getMediaSource(playerDataSource, extraDatasource);
      exoPlayer.setMediaSource(mediaSource);
    }

    // exoPlayer.setMediaItem(mediaItem);
    exoPlayer.prepare();

    exoPlayer.setVideoSurface(surfaceProducer.getSurface());

    boolean wasInitialized = savedStateDuring != null;
    exoPlayer.addListener(new ExoPlayerEventListener(exoPlayer, videoPlayerEvents, wasInitialized));
    setAudioAttributes(exoPlayer, options.mixWithOthers);

    return exoPlayer;
  }

  void sendBufferingUpdate() {
    videoPlayerEvents.onBufferingUpdate(exoPlayer.getBufferedPosition());
  }

  private static void setAudioAttributes(ExoPlayer exoPlayer, boolean isMixMode) {
    exoPlayer.setAudioAttributes(
            new AudioAttributes.Builder().setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(),
            !isMixMode);
  }

  void play() {
    exoPlayer.play();
  }

  void pause() {
    exoPlayer.pause();
  }

  void setLooping(boolean value) {
    exoPlayer.setRepeatMode(value ? REPEAT_MODE_ALL : REPEAT_MODE_OFF);
  }

  void setVolume(double value) {
    float bracketedValue = (float) Math.max(0.0, Math.min(1.0, value));
    exoPlayer.setVolume(bracketedValue);
  }

  void setPlaybackSpeed(double value) {
    // We do not need to consider pitch and skipSilence for now as we do not handle them and
    // therefore never diverge from the default values.
    final PlaybackParameters playbackParameters = new PlaybackParameters(((float) value));

    exoPlayer.setPlaybackParameters(playbackParameters);
  }

  void seekTo(int location) {
    exoPlayer.seekTo(location);
  }

  long getPosition() {
    return exoPlayer.getCurrentPosition();
  }

  void dispose() {
    exoPlayer.release();
    surfaceProducer.release();

    // TODO(matanlurey): Remove when embedder no longer calls-back once released.
    // https://github.com/flutter/flutter/issues/156434.
    surfaceProducer.setCallback(null);
  }

  @OptIn(markerClass = UnstableApi.class)
  public void changeDataSource(Context context,
                               String dataSource,
                               String audioDataSource,
                               List<Map<String, String>> extraDatasource,
                               String formatHint,
                               @NonNull Map<String, String> httpHeaders,
                               VideoPlayerOptions options) {
    if (extraDatasource == null || extraDatasource.isEmpty()) {
      if (dataSource.endsWith(".m3u8")) {
        if (playerDataSource == null) {
          playerDataSource = new PlayerDataSource(context, new DefaultBandwidthMeter.Builder(context).build());
        }
        MediaSource mediaSource = BuildDataSourceHelper.getHlsMediaSource(playerDataSource, dataSource);
        exoPlayer.setMediaSource(mediaSource);
      } else {
        MediaItem mediaItem = new MediaItem.Builder()
                .setUri(dataSource)
                .build();
        exoPlayer.setMediaItem(mediaItem);
      }
    } else {
      playerDataSource = new PlayerDataSource(context, new DefaultBandwidthMeter.Builder(context).build());
      MediaSource mediaSource = BuildDataSourceHelper.getMediaSource(playerDataSource, extraDatasource);
      if (mediaSource != null) {
        exoPlayer.setMediaSource(mediaSource, false);
      }
    }
  }

  @OptIn(markerClass = UnstableApi.class)
  public void selectResolution(int width, int height) {
    if (trackSelector == null) {
      return;
    }
    DefaultTrackSelector.Parameters.Builder builder = trackSelector.buildUponParameters()
            .setMaxVideoSize(width, height)
            .setMinVideoSize(width, height);
    trackSelector.setParameters(builder);
  }

  @OptIn(markerClass = UnstableApi.class)
  public List<Messages.VideoResolutionData> getAvailableVideoResolutions() {
    List<Messages.VideoResolutionData> ret = new ArrayList<>();
    if (trackSelector == null) {
      return ret;
    }
    MappingTrackSelector.MappedTrackInfo mappedTrackInfo = trackSelector.getCurrentMappedTrackInfo();
    if (mappedTrackInfo == null) {
      return ret;
    }
    for (int rendererIndex = 0; rendererIndex < Objects.requireNonNull(mappedTrackInfo).getRendererCount(); rendererIndex++) {
      if (mappedTrackInfo.getRendererType(rendererIndex) == C.TRACK_TYPE_VIDEO) {
        TrackGroupArray trackGroups = mappedTrackInfo.getTrackGroups(rendererIndex);
        for (int groupIndex = 0; groupIndex < trackGroups.length; groupIndex++) {
          TrackGroup trackGroup = trackGroups.get(groupIndex);
          for (int trackIndex = 0; trackIndex < trackGroup.length; trackIndex++) {
            Format format = trackGroup.getFormat(trackIndex);
            int width = format.width;
            int height = format.height;
            Messages.VideoResolutionData data = new Messages.VideoResolutionData();
            data.setWidth((long) width);
            data.setHeight((long) height);
            ret.add(data);
          }
        }
      }
    }
    return ret;
  }
}