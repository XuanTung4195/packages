package io.flutter.plugins.videoplayer.custom;


import android.content.Context;

import androidx.annotation.NonNull;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DefaultDataSource;
import androidx.media3.datasource.FileDataSource;
import androidx.media3.datasource.TransferListener;
import androidx.media3.datasource.cache.CacheDataSink;
import androidx.media3.datasource.cache.CacheDataSource;
import androidx.media3.datasource.cache.SimpleCache;

@UnstableApi
final class CacheFactory implements DataSource.Factory {
    private static final int CACHE_FLAGS = CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR;

    private final Context context;
    private final TransferListener transferListener;
    private final DataSource.Factory upstreamDataSourceFactory;
    private final SimpleCache cache;

    @UnstableApi
    CacheFactory(final Context context,
                 final TransferListener transferListener,
                 final SimpleCache cache,
                 final DataSource.Factory upstreamDataSourceFactory) {
        this.context = context;
        this.transferListener = transferListener;
        this.cache = cache;
        this.upstreamDataSourceFactory = upstreamDataSourceFactory;
    }

    @NonNull
    @Override
    @UnstableApi
    public DataSource createDataSource() {
        final DefaultDataSource dataSource = new DefaultDataSource.Factory(context,
                upstreamDataSourceFactory)
                .setTransferListener(transferListener)
                .createDataSource();

        final FileDataSource fileSource = new FileDataSource();
        final CacheDataSink dataSink =
                new CacheDataSink(cache, 2 * 1024 * 1024L);
        return new CacheDataSource(cache, dataSource, fileSource, dataSink, CACHE_FLAGS, null);
    }
}
