package io.flutter.plugins.videoplayer.custom;

import android.net.Uri;

import androidx.annotation.OptIn;
import androidx.media3.common.MediaItem;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.dash.DashMediaSource;
import androidx.media3.exoplayer.dash.manifest.DashManifest;
import androidx.media3.exoplayer.dash.manifest.DashManifestParser;
import androidx.media3.exoplayer.source.MediaSource;
import androidx.media3.exoplayer.source.MergingMediaSource;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class BuildDataSourceHelper {

    @OptIn(markerClass = UnstableApi.class)
    static DashManifest createDashManifest(String string) throws IOException {
        return new DashManifestParser().parse(Uri.parse(""),
                new ByteArrayInputStream(string.getBytes(StandardCharsets.UTF_8)));
    }

    @OptIn(markerClass = UnstableApi.class)
    private static DashMediaSource buildYoutubeManualDashMediaSource(
            final PlayerDataSource dataSource,
            final DashManifest dashManifest,
            final String contentUrl) {
        return dataSource.getYoutubeDashMediaSourceFactory().createMediaSource(dashManifest,
                new MediaItem.Builder()
                        .setUri(Uri.parse(contentUrl))
                        // .setTag(metadata)
                        // .setCustomCacheKey(cacheKey)
                        .build());
    }


    @OptIn(markerClass = UnstableApi.class)
    public static MediaSource getMediaSource(PlayerDataSource playerDataSource, List<Map<String, String>> extraDatasource) {
        List<MediaSource> mediaSources = new ArrayList<>();
        for (Map<String, String> map : extraDatasource) {
            String dashManifest = map.get("dashManifest");
            String type = map.get("type");
            String contentUrl = map.get("contentUrl");
            if (dashManifest != null && contentUrl != null) {
                DashMediaSource dashMediaSource = null;
                try {
                    dashMediaSource = buildYoutubeManualDashMediaSource(playerDataSource, createDashManifest(dashManifest),
                            contentUrl);
                    mediaSources.add(dashMediaSource);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
        if (mediaSources.isEmpty()) {
            return null;
        }
        if (mediaSources.size() == 1) {
            return mediaSources.get(0);
        }
        MediaSource[] arraySource = new MediaSource[mediaSources.size()];
        arraySource = mediaSources.toArray(arraySource);
        return  new MergingMediaSource(true, arraySource);
    }

    @OptIn(markerClass = UnstableApi.class)
    public static MediaSource getHlsMediaSource(PlayerDataSource playerDataSource, String sourceUrl) {
        final MediaSource.Factory factory;
        factory = playerDataSource.getLiveHlsMediaSourceFactory();
        return factory.createMediaSource(
                new MediaItem.Builder()
                        // .setTag(metadata)
                        .setUri(Uri.parse(sourceUrl))
                        .setLiveConfiguration(
                                new MediaItem.LiveConfiguration.Builder()
                                        .setTargetOffsetMs(PlayerDataSource.LIVE_STREAM_EDGE_GAP_MILLIS)
                                        .build())
                        .build());
    }
}
