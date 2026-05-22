package io.flutter.plugins.videoplayer.custom;

import android.content.Context;
import android.net.Uri;

import androidx.annotation.Nullable;
import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.util.Assertions;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.common.util.Util;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DefaultDataSource;
import androidx.media3.exoplayer.dash.DashMediaSource;
import androidx.media3.exoplayer.drm.DrmSessionManagerProvider;
import androidx.media3.exoplayer.drm.DefaultDrmSessionManagerProvider;
import androidx.media3.exoplayer.hls.HlsMediaSource;
import androidx.media3.exoplayer.smoothstreaming.SsMediaSource;
import androidx.media3.exoplayer.source.MediaSource;
import androidx.media3.exoplayer.source.ProgressiveMediaSource;
import androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy;
import androidx.media3.exoplayer.upstream.LoadErrorHandlingPolicy;
import androidx.media3.extractor.DefaultExtractorsFactory;
import androidx.media3.exoplayer.upstream.DefaultBandwidthMeter;

import io.flutter.plugins.videoplayer.CreationOptions;
import java.util.List;
import java.util.Map;

@UnstableApi
public final class CustomMediaSourceFactory implements MediaSource.Factory {

    private final DataSource.Factory dataSourceFactory;
    private CreationOptions options = null;
    private Context context = null;

    private DrmSessionManagerProvider drmSessionManagerProvider =
            new DefaultDrmSessionManagerProvider();

    private LoadErrorHandlingPolicy loadErrorHandlingPolicy =
            new DefaultLoadErrorHandlingPolicy();

    public CustomMediaSourceFactory(Context context, CreationOptions options) {
        this(new DefaultDataSource.Factory(context));
        this.options = options;
        this.context = context;
    }

    public CustomMediaSourceFactory(DataSource.Factory dataSourceFactory) {
        this.dataSourceFactory = Assertions.checkNotNull(dataSourceFactory);
    }

    @Override
    public MediaSource createMediaSource(MediaItem mediaItem) {
        if (options != null) {
            List<Map<String, String>> extraDatasource = options.getExtraDatasource();
            if (extraDatasource == null || extraDatasource.isEmpty()) {
                String dataSource = null;
                if (mediaItem.localConfiguration != null) {
                    dataSource = mediaItem.localConfiguration.uri.toString();
                }
                if (dataSource != null && (dataSource.endsWith(".m3u8") || dataSource.contains("index.m3u8"))) {
                    PlayerDataSource playerDataSource = new PlayerDataSource(context, new DefaultBandwidthMeter.Builder(context).build());
                    MediaSource mediaSource = BuildDataSourceHelper.getHlsMediaSource(playerDataSource, dataSource);
                    return mediaSource;
                } else {
                    // exoPlayer.setMediaItem(mediaItem);
                }
            } else {
                PlayerDataSource playerDataSource = new PlayerDataSource(context, new DefaultBandwidthMeter.Builder(context).build());
                MediaSource mediaSource = BuildDataSourceHelper.getMediaSource(playerDataSource, extraDatasource);
                return mediaSource;
            }
        }

        Assertions.checkNotNull(mediaItem.localConfiguration);

        Uri uri = mediaItem.localConfiguration.uri;

        @C.ContentType int contentType = Util.inferContentTypeForUriAndMimeType(
                uri,
                mediaItem.localConfiguration.mimeType
        );

        MediaSource mediaSource;

        switch (contentType) {
            case C.CONTENT_TYPE_HLS:
                mediaSource = new HlsMediaSource.Factory(dataSourceFactory)
                        .setDrmSessionManagerProvider(drmSessionManagerProvider)
                        .setLoadErrorHandlingPolicy(loadErrorHandlingPolicy)
                        .createMediaSource(mediaItem);
                break;

            case C.CONTENT_TYPE_DASH:
                mediaSource = new DashMediaSource.Factory(dataSourceFactory)
                        .setDrmSessionManagerProvider(drmSessionManagerProvider)
                        .setLoadErrorHandlingPolicy(loadErrorHandlingPolicy)
                        .createMediaSource(mediaItem);
                break;

            case C.CONTENT_TYPE_SS:
                mediaSource = new SsMediaSource.Factory(dataSourceFactory)
                        .setDrmSessionManagerProvider(drmSessionManagerProvider)
                        .setLoadErrorHandlingPolicy(loadErrorHandlingPolicy)
                        .createMediaSource(mediaItem);
                break;

            case C.CONTENT_TYPE_OTHER:
            default:
                mediaSource = new ProgressiveMediaSource.Factory(
                        dataSourceFactory,
                        new DefaultExtractorsFactory()
                )
                        .setDrmSessionManagerProvider(drmSessionManagerProvider)
                        .setLoadErrorHandlingPolicy(loadErrorHandlingPolicy)
                        .createMediaSource(mediaItem);
                break;
        }

        return mediaSource;
    }

    @Override
    public MediaSource.Factory setDrmSessionManagerProvider(
            DrmSessionManagerProvider drmSessionManagerProvider
    ) {
        this.drmSessionManagerProvider = Assertions.checkNotNull(drmSessionManagerProvider);
        return this;
    }

    @Override
    public MediaSource.Factory setLoadErrorHandlingPolicy(
            LoadErrorHandlingPolicy loadErrorHandlingPolicy
    ) {
        this.loadErrorHandlingPolicy = Assertions.checkNotNull(loadErrorHandlingPolicy);
        return this;
    }

    @Override
    public int[] getSupportedTypes() {
        return new int[] {
                C.CONTENT_TYPE_DASH,
                C.CONTENT_TYPE_SS,
                C.CONTENT_TYPE_HLS,
                C.CONTENT_TYPE_OTHER
        };
    }
}