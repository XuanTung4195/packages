// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static androidx.media3.common.Player.REPEAT_MODE_ALL;
import static androidx.media3.common.Player.REPEAT_MODE_OFF;

import android.content.Context;
import android.view.Surface;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.annotation.VisibleForTesting;
import androidx.media3.common.AudioAttributes;
import androidx.media3.common.C;
import androidx.media3.common.Format;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.PlaybackParameters;
import androidx.media3.common.TrackGroup;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DefaultDataSource;
import androidx.media3.datasource.DefaultHttpDataSource;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory;
import androidx.media3.exoplayer.source.MediaSource;
import androidx.media3.exoplayer.source.TrackGroupArray;
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector;
import androidx.media3.exoplayer.trackselection.MappingTrackSelector;
import androidx.media3.exoplayer.trackselection.TrackSelector;
import androidx.media3.exoplayer.upstream.DefaultBandwidthMeter;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;

import io.flutter.plugins.videoplayer.custom.BuildDataSourceHelper;
import io.flutter.plugins.videoplayer.custom.PlayerDataSource;
import io.flutter.view.TextureRegistry;

final class VideoPlayer {
  private static final String FORMAT_SS = "ss";
  private static final String FORMAT_DASH = "dash";
  private static final String FORMAT_HLS = "hls";
  private static final String FORMAT_OTHER = "other";

  private ExoPlayer exoPlayer;

  private Surface surface;

  private final TextureRegistry.SurfaceTextureEntry textureEntry;

  private final VideoPlayerCallbacks videoPlayerEvents;

  private static final String USER_AGENT = "User-Agent";

  private final VideoPlayerOptions options;

  private final DefaultHttpDataSource.Factory httpDataSourceFactory;
  private PlayerDataSource playerDataSource;

  private DefaultTrackSelector trackSelector;

  @OptIn(markerClass = UnstableApi.class)
  VideoPlayer(
      Context context,
      VideoPlayerCallbacks events,
      TextureRegistry.SurfaceTextureEntry textureEntry,
      String dataSource,
      String audioDataSource,
      List<Map<String, String>> extraDatasource,
      String formatHint,
      @NonNull Map<String, String> httpHeaders,
      VideoPlayerOptions options) {
    this.videoPlayerEvents = events;
    this.textureEntry = textureEntry;
    this.options = options;

    httpDataSourceFactory = new DefaultHttpDataSource.Factory();
    configureHttpDataSourceFactory(httpHeaders);

    trackSelector = new DefaultTrackSelector(context);

    ExoPlayer exoPlayer = buildExoPlayer(context, httpDataSourceFactory, trackSelector);

    if (extraDatasource == null || extraDatasource.isEmpty()) {
      if (dataSource.endsWith(".m3u8")) {
        playerDataSource = new PlayerDataSource(context, new DefaultBandwidthMeter.Builder(context).build());
        MediaSource mediaSource = BuildDataSourceHelper.getHlsMediaSource(playerDataSource, dataSource);
        exoPlayer.setMediaSource(mediaSource);
      } else {
        MediaItem mediaItem = new MediaItem.Builder()
                .setUri(dataSource)
                .setMimeType(mimeFromFormatHint(formatHint))
                .build();
        exoPlayer.setMediaItem(mediaItem);
      }
    } else {
      playerDataSource = new PlayerDataSource(context, new DefaultBandwidthMeter.Builder(context).build());
      MediaSource mediaSource = BuildDataSourceHelper.getMediaSource(playerDataSource, extraDatasource);
      exoPlayer.setMediaSource(mediaSource);
    }

    exoPlayer.prepare();

    setUpVideoPlayer(exoPlayer);
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
                .setMimeType(mimeFromFormatHint(formatHint))
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

  // Constructor used to directly test members of this class.
  @VisibleForTesting
  VideoPlayer(
      ExoPlayer exoPlayer,
      VideoPlayerCallbacks events,
      TextureRegistry.SurfaceTextureEntry textureEntry,
      VideoPlayerOptions options,
      DefaultHttpDataSource.Factory httpDataSourceFactory) {
    this.videoPlayerEvents = events;
    this.textureEntry = textureEntry;
    this.options = options;
    this.httpDataSourceFactory = httpDataSourceFactory;

    setUpVideoPlayer(exoPlayer);
  }

  @VisibleForTesting
  @UnstableApi
  public void configureHttpDataSourceFactory(@NonNull Map<String, String> httpHeaders) {
    httpDataSourceFactory.setConnectTimeoutMs(10 * 1000);
    httpDataSourceFactory.setReadTimeoutMs(15 * 1000);
    final boolean httpHeadersNotEmpty = !httpHeaders.isEmpty();
    final String userAgent =
        httpHeadersNotEmpty && httpHeaders.containsKey(USER_AGENT)
            ? httpHeaders.get(USER_AGENT)
            : "ExoPlayer";

    unstableUpdateDataSourceFactory(
        httpDataSourceFactory, httpHeaders, userAgent, httpHeadersNotEmpty);
  }

  private void setUpVideoPlayer(ExoPlayer exoPlayer) {
    this.exoPlayer = exoPlayer;

    surface = new Surface(textureEntry.surfaceTexture());
    exoPlayer.setVideoSurface(surface);
    setAudioAttributes(exoPlayer, options.mixWithOthers);
    exoPlayer.addListener(new ExoPlayerEventListener(exoPlayer, videoPlayerEvents));
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
    exoPlayer.setPlayWhenReady(true);
  }

  void pause() {
    exoPlayer.setPlayWhenReady(false);
  }

  void setLooping(boolean value) {
    exoPlayer.setRepeatMode(value ? REPEAT_MODE_ALL : REPEAT_MODE_OFF);
  }

  void setVolume(double value) {
    float bracketedValue = (float) Math.max(0.0, Math.min(1.0, value));
    exoPlayer.setVolume(bracketedValue);
  }
int count = 0;
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
    textureEntry.release();
    if (surface != null) {
      surface.release();
    }
    if (exoPlayer != null) {
      exoPlayer.release();
    }
  }

  @NonNull
  @UnstableApi
  private static ExoPlayer buildExoPlayer(
      Context context, DataSource.Factory baseDataSourceFactory, TrackSelector trackSelector) {
    DataSource.Factory dataSourceFactory =
        new DefaultDataSource.Factory(context, baseDataSourceFactory);
    DefaultMediaSourceFactory mediaSourceFactory =
        new DefaultMediaSourceFactory(context).setDataSourceFactory(dataSourceFactory);
    return new ExoPlayer.Builder(context).setTrackSelector(trackSelector).setMediaSourceFactory(mediaSourceFactory).build();
  }

  @Nullable
  private static String mimeFromFormatHint(@Nullable String formatHint) {
    if (formatHint == null) {
      return null;
    }
    switch (formatHint) {
      case FORMAT_SS:
        return MimeTypes.APPLICATION_SS;
      case FORMAT_DASH:
        return MimeTypes.APPLICATION_MPD;
      case FORMAT_HLS:
        return MimeTypes.APPLICATION_M3U8;
      case FORMAT_OTHER:
      default:
        return null;
    }
  }

  // TODO: migrate to stable API, see https://github.com/flutter/flutter/issues/147039
  @OptIn(markerClass = UnstableApi.class)
  private static void unstableUpdateDataSourceFactory(
      DefaultHttpDataSource.Factory factory,
      @NonNull Map<String, String> httpHeaders,
      String userAgent,
      boolean httpHeadersNotEmpty) {
    factory.setUserAgent(userAgent).setAllowCrossProtocolRedirects(true);

    if (httpHeadersNotEmpty) {
      factory.setDefaultRequestProperties(httpHeaders);
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
