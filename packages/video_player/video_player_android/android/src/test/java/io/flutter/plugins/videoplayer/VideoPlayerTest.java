// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static org.junit.Assert.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import android.graphics.SurfaceTexture;
import androidx.media3.common.AudioAttributes;
import androidx.media3.common.C;
import androidx.media3.common.PlaybackParameters;
import androidx.media3.common.Player;
import androidx.media3.exoplayer.ExoPlayer;
import io.flutter.view.TextureRegistry;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnit;
import org.mockito.junit.MockitoRule;
import org.robolectric.RobolectricTestRunner;

/**
 * Unit tests for {@link VideoPlayer}.
 *
 * <p>This test suite <em>narrowly verifies</em> that {@link VideoPlayer} interfaces with the {@link
 * ExoPlayer} interface <em>exactly</em> as it did when the test suite was created. That is, if the
 * behavior changes, this test will need to change. However, this suite should catch bugs related to
 * <em>"this is a safe refactor with no behavior changes"</em>.
 *
 * <p>It's hypothetically possible to write better tests using {@link
 * androidx.media3.test.utils.FakeMediaSource}, but you really need a PhD in the Android media APIs
 * in order to figure out how to set everything up so the player "works".
 */
@RunWith(RobolectricTestRunner.class)
public final class VideoPlayerTest {
  private static final String FAKE_ASSET_URL = "https://flutter.dev/movie.mp4";
  private FakeVideoAsset fakeVideoAsset;

  @Mock private VideoPlayerCallbacks mockEvents;
  @Mock private TextureRegistry.SurfaceTextureEntry mockTexture;
  @Mock private ExoPlayer.Builder mockBuilder;
  @Mock private ExoPlayer mockExoPlayer;
  @Captor private ArgumentCaptor<AudioAttributes> attributesCaptor;

  @Rule public MockitoRule initRule = MockitoJUnit.rule();

  @Before
  public void setUp() {
    fakeVideoAsset = new FakeVideoAsset(FAKE_ASSET_URL);
    when(mockBuilder.build()).thenReturn(mockExoPlayer);
    when(mockTexture.surfaceTexture()).thenReturn(mock(SurfaceTexture.class));
  }

  private VideoPlayer createVideoPlayer() {
    return createVideoPlayer(new VideoPlayerOptions());
  }

  private VideoPlayer createVideoPlayer(VideoPlayerOptions options) {
    return new VideoPlayer(
            null, null, mockBuilder, mockEvents, mockTexture, fakeVideoAsset.getMediaItem(), null, options);
  }

  @Test
  public void loadsAndPreparesProvidedMediaEnablesAudioFocusByDefault() {
    VideoPlayer videoPlayer = createVideoPlayer();

    verify(mockExoPlayer).setMediaItem(fakeVideoAsset.getMediaItem());
    verify(mockExoPlayer).prepare();
    verify(mockTexture).surfaceTexture();
    verify(mockExoPlayer).setVideoSurface(any());

    verify(mockExoPlayer).setAudioAttributes(attributesCaptor.capture(), eq(true));
    assertEquals(attributesCaptor.getValue().contentType, C.AUDIO_CONTENT_TYPE_MOVIE);

    videoPlayer.dispose();
  }

  @Test
  public void loadsAndPreparesProvidedMediaDisablesAudioFocusWhenMixModeSet() {
    VideoPlayerOptions options = new VideoPlayerOptions();
    options.mixWithOthers = true;

    VideoPlayer videoPlayer = createVideoPlayer(options);

    verify(mockExoPlayer).setAudioAttributes(attributesCaptor.capture(), eq(false));
    assertEquals(attributesCaptor.getValue().contentType, C.AUDIO_CONTENT_TYPE_MOVIE);

    videoPlayer.dispose();
  }

  @Test
  public void playsAndPausesProvidedMedia() {
    VideoPlayer videoPlayer = createVideoPlayer();

    videoPlayer.play();
    verify(mockExoPlayer).setPlayWhenReady(true);

    videoPlayer.pause();
    verify(mockExoPlayer).setPlayWhenReady(false);

    videoPlayer.dispose();
  }

  @Test
  public void sendsBufferingUpdatesOnDemand() {
    VideoPlayer videoPlayer = createVideoPlayer();

    when(mockExoPlayer.getBufferedPosition()).thenReturn(10L);
    videoPlayer.sendBufferingUpdate();
    verify(mockEvents).onBufferingUpdate(10L);

    videoPlayer.dispose();
  }

  @Test
  public void togglesLoopingEnablesAndDisablesRepeatMode() {
    VideoPlayer videoPlayer = createVideoPlayer();

    videoPlayer.setLooping(true);
    verify(mockExoPlayer).setRepeatMode(Player.REPEAT_MODE_ALL);

    videoPlayer.setLooping(false);
    verify(mockExoPlayer).setRepeatMode(Player.REPEAT_MODE_OFF);

    videoPlayer.dispose();
  }

  @Test
  public void setVolumeIsClampedBetween0and1() {
    VideoPlayer videoPlayer = createVideoPlayer();

    videoPlayer.setVolume(-1.0);
    verify(mockExoPlayer).setVolume(0f);

    videoPlayer.setVolume(2.0);
    verify(mockExoPlayer).setVolume(1f);

    videoPlayer.setVolume(0.5);
    verify(mockExoPlayer).setVolume(0.5f);

    videoPlayer.dispose();
  }

  @Test
  public void setPlaybackSpeedSetsPlaybackParametersWithValue() {
    VideoPlayer videoPlayer = createVideoPlayer();

    videoPlayer.setPlaybackSpeed(2.5);
    verify(mockExoPlayer).setPlaybackParameters(new PlaybackParameters(2.5f));

    videoPlayer.dispose();
  }

  @Test
  public void seekAndGetPosition() {
    VideoPlayer videoPlayer = createVideoPlayer();

    videoPlayer.seekTo(10);
    verify(mockExoPlayer).seekTo(10);

    when(mockExoPlayer.getCurrentPosition()).thenReturn(20L);
    assertEquals(20L, videoPlayer.getPosition());
  }

  @Test
  public void disposeReleasesTextureAndPlayer() {
    VideoPlayer videoPlayer = createVideoPlayer();
    videoPlayer.dispose();

    verify(mockTexture).release();
    verify(mockExoPlayer).release();
  }
}
