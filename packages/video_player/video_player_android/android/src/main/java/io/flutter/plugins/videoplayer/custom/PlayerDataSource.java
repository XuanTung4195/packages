package io.flutter.plugins.videoplayer.custom;

import android.content.Context;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.database.StandaloneDatabaseProvider;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DefaultDataSource;
import androidx.media3.datasource.DefaultHttpDataSource;
import androidx.media3.datasource.TransferListener;
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor;
import androidx.media3.datasource.cache.SimpleCache;
import androidx.media3.exoplayer.dash.DashMediaSource;
import androidx.media3.exoplayer.dash.DefaultDashChunkSource;
import androidx.media3.exoplayer.hls.HlsMediaSource;
import androidx.media3.exoplayer.hls.playlist.DefaultHlsPlaylistTracker;
import androidx.media3.exoplayer.smoothstreaming.DefaultSsChunkSource;
import androidx.media3.exoplayer.smoothstreaming.SsMediaSource;
import androidx.media3.exoplayer.source.ProgressiveMediaSource;
import androidx.media3.exoplayer.source.SingleSampleMediaSource;

import java.io.File;

public class PlayerDataSource {
    static boolean DEBUG = true;

    public static final String USER_AGENT =
            "Mozilla/5.0 (Windows NT 10.0; rv:91.0) Gecko/20100101 Firefox/91.0";
    public static final String TAG = PlayerDataSource.class.getSimpleName();

    public static final int LIVE_STREAM_EDGE_GAP_MILLIS = 10000;

    private static final double PLAYLIST_STUCK_TARGET_DURATION_COEFFICIENT = 15;

    private static final int MAX_MANIFEST_CACHE_SIZE = 500;

    /**
     * The folder name in which the ExoPlayer cache will be written.
     */
    private static final String CACHE_FOLDER_NAME = "exoplayer";

    private static SimpleCache cache;


    private final int progressiveLoadIntervalBytes;

    // Generic Data Source Factories (without or with cache)
    private final DataSource.Factory cachelessDataSourceFactory;
    private final DataSource.Factory cacheDataSourceFactory;

    // YouTube-specific Data Source Factories (with cache)
    // They use YoutubeHttpDataSource.Factory, with different parameters each
    private final DataSource.Factory ytHlsCacheDataSourceFactory;
    private final DataSource.Factory ytDashCacheDataSourceFactory;
    private final DataSource.Factory ytProgressiveDashCacheDataSourceFactory;


    @UnstableApi
    public PlayerDataSource(final Context context,
                            final TransferListener transferListener) {

        progressiveLoadIntervalBytes = PlayerHelper.getProgressiveLoadIntervalBytes();

        // make sure the static cache was created: needed by CacheFactories below
        instantiateCacheIfNeeded(context);

        // generic data source factories use DefaultHttpDataSource.Factory
        cachelessDataSourceFactory = new DefaultDataSource.Factory(context,
                new DefaultHttpDataSource.Factory().setUserAgent(USER_AGENT))
                .setTransferListener(transferListener);
//        cacheDataSourceFactory = new CacheFactory(context, transferListener, cache,
//                new DefaultHttpDataSource.Factory().setUserAgent(USER_AGENT));
        cacheDataSourceFactory = cachelessDataSourceFactory;

        // YouTube-specific data source factories use getYoutubeHttpDataSourceFactory()
//        ytHlsCacheDataSourceFactory = new CacheFactory(context, transferListener, cache,
//                getYoutubeHttpDataSourceFactory(false, false));

        ytHlsCacheDataSourceFactory = new DefaultDataSource.Factory(context,
                getYoutubeHttpDataSourceFactory(false, false));

//        ytDashCacheDataSourceFactory = new CacheFactory(context, transferListener, cache,
//                getYoutubeHttpDataSourceFactory(true, true));

        ytDashCacheDataSourceFactory = new DefaultDataSource.Factory(context,
                getYoutubeHttpDataSourceFactory(true, true));


//        ytProgressiveDashCacheDataSourceFactory = new CacheFactory(context, transferListener, cache,
//                getYoutubeHttpDataSourceFactory(false, true));

        ytProgressiveDashCacheDataSourceFactory = new DefaultDataSource.Factory(context,
                getYoutubeHttpDataSourceFactory(false, true));

        // set the maximum size to manifest creators
//        YoutubeProgressiveDashManifestCreator.getCache().setMaximumSize(MAX_MANIFEST_CACHE_SIZE);
//        YoutubeOtfDashManifestCreator.getCache().setMaximumSize(MAX_MANIFEST_CACHE_SIZE);
//        YoutubePostLiveStreamDvrDashManifestCreator.getCache().setMaximumSize(
//                MAX_MANIFEST_CACHE_SIZE);
    }


    //region Live media source factories
    @OptIn(markerClass = UnstableApi.class) public SsMediaSource.Factory getLiveSsMediaSourceFactory() {
        return getSSMediaSourceFactory().setLivePresentationDelayMs(LIVE_STREAM_EDGE_GAP_MILLIS);
    }

    @OptIn(markerClass = UnstableApi.class) public HlsMediaSource.Factory getLiveHlsMediaSourceFactory() {
        return new HlsMediaSource.Factory(cachelessDataSourceFactory)
                .setAllowChunklessPreparation(true)
                .setPlaylistTrackerFactory((dataSourceFactory, loadErrorHandlingPolicy,
                                            playlistParserFactory) ->
                        new DefaultHlsPlaylistTracker(dataSourceFactory, loadErrorHandlingPolicy,
                                playlistParserFactory,
                                PLAYLIST_STUCK_TARGET_DURATION_COEFFICIENT));
    }

    @UnstableApi
    public DashMediaSource.Factory getLiveDashMediaSourceFactory() {
        return new DashMediaSource.Factory(
                getDefaultDashChunkSourceFactory(cachelessDataSourceFactory),
                cachelessDataSourceFactory);
    }
    //endregion


    //region Generic media source factories
    @OptIn(markerClass = UnstableApi.class)
    public HlsMediaSource.Factory getHlsMediaSourceFactory(
            @Nullable final NonUriHlsDataSourceFactory.Builder hlsDataSourceFactoryBuilder) {
        if (hlsDataSourceFactoryBuilder != null) {
            hlsDataSourceFactoryBuilder.setDataSourceFactory(cacheDataSourceFactory);
            return new HlsMediaSource.Factory(hlsDataSourceFactoryBuilder.build());
        }

        return new HlsMediaSource.Factory(cacheDataSourceFactory);
    }

    @OptIn(markerClass = UnstableApi.class)
    public DashMediaSource.Factory getDashMediaSourceFactory() {
        return new DashMediaSource.Factory(
                getDefaultDashChunkSourceFactory(cacheDataSourceFactory),
                cacheDataSourceFactory);
    }

    @OptIn(markerClass = UnstableApi.class) public ProgressiveMediaSource.Factory getProgressiveMediaSourceFactory() {
        return new ProgressiveMediaSource.Factory(cacheDataSourceFactory)
                .setContinueLoadingCheckIntervalBytes(progressiveLoadIntervalBytes);
    }

    @OptIn(markerClass = UnstableApi.class)
    public SsMediaSource.Factory getSSMediaSourceFactory() {
        return new SsMediaSource.Factory(
                new DefaultSsChunkSource.Factory(cachelessDataSourceFactory),
                cachelessDataSourceFactory);
    }

    @OptIn(markerClass = UnstableApi.class) public SingleSampleMediaSource.Factory getSingleSampleMediaSourceFactory() {
        return new SingleSampleMediaSource.Factory(cacheDataSourceFactory);
    }
    //endregion


    //region YouTube media source factories
    @OptIn(markerClass = UnstableApi.class) public HlsMediaSource.Factory getYoutubeHlsMediaSourceFactory() {
        return new HlsMediaSource.Factory(ytHlsCacheDataSourceFactory);
    }

    @OptIn(markerClass = UnstableApi.class) public DashMediaSource.Factory getYoutubeDashMediaSourceFactory() {
        return new DashMediaSource.Factory(
                getDefaultDashChunkSourceFactory(ytDashCacheDataSourceFactory),
                ytDashCacheDataSourceFactory);
    }

    @OptIn(markerClass = UnstableApi.class) public ProgressiveMediaSource.Factory getYoutubeProgressiveMediaSourceFactory() {
        return new ProgressiveMediaSource.Factory(ytProgressiveDashCacheDataSourceFactory)
                .setContinueLoadingCheckIntervalBytes(progressiveLoadIntervalBytes);
    }
    //endregion


    //region Static methods
    @OptIn(markerClass = UnstableApi.class) private static DefaultDashChunkSource.Factory getDefaultDashChunkSourceFactory(
            final DataSource.Factory dataSourceFactory) {
        return new DefaultDashChunkSource.Factory(dataSourceFactory);
    }

    @OptIn(markerClass = UnstableApi.class) private static YoutubeHttpDataSource.Factory getYoutubeHttpDataSourceFactory(
            final boolean rangeParameterEnabled,
            final boolean rnParameterEnabled) {
        return new YoutubeHttpDataSource.Factory()
                .setRangeParameterEnabled(rangeParameterEnabled)
                .setRnParameterEnabled(rnParameterEnabled);
    }

    @OptIn(markerClass = UnstableApi.class) private static void instantiateCacheIfNeeded(final Context context) {
        if (cache == null) {
            final File cacheDir = new File(context.getExternalCacheDir(), CACHE_FOLDER_NAME);
            if (DEBUG) {
                Log.d(TAG, "instantiateCacheIfNeeded: cacheDir = " + cacheDir.getAbsolutePath());
            }
            if (!cacheDir.exists() && !cacheDir.mkdir()) {
                Log.w(TAG, "instantiateCacheIfNeeded: could not create cache dir");
            }

            final LeastRecentlyUsedCacheEvictor evictor =
                    new LeastRecentlyUsedCacheEvictor(PlayerHelper.getPreferredCacheSize());
            cache = new SimpleCache(cacheDir, evictor, new StandaloneDatabaseProvider(context));
        }
    }
    //endregion
}
