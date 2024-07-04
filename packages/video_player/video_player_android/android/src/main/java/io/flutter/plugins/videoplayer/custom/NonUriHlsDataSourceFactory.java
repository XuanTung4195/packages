package io.flutter.plugins.videoplayer.custom;


import androidx.annotation.NonNull;
import androidx.annotation.OptIn;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.ByteArrayDataSource;
import androidx.media3.datasource.DataSource;
import androidx.media3.exoplayer.hls.HlsDataSourceFactory;
import androidx.media3.common.C;


import java.nio.charset.StandardCharsets;


@UnstableApi
public final class NonUriHlsDataSourceFactory implements HlsDataSourceFactory {

    /**
     * Builder class of {@link NonUriHlsDataSourceFactory} instances.
     */
    public static final class Builder {
        private DataSource.Factory dataSourceFactory;
        private String playlistString;

        /**
         * Set the {@link DataSource.Factory} which will be used to create non manifest contents
         * {@link DataSource}s.
         *
         * @param dataSourceFactoryForNonManifestContents the {@link DataSource.Factory} which will
         *                                                be used to create non manifest contents
         *                                                {@link DataSource}s, which cannot be null
         */
        public void setDataSourceFactory(
                @NonNull final DataSource.Factory dataSourceFactoryForNonManifestContents) {
            this.dataSourceFactory = dataSourceFactoryForNonManifestContents;
        }

        /**
         * Set the HLS playlist which will be used for manifests requests.
         *
         * @param hlsPlaylistString the string which correspond to the response of the HLS
         *                          manifest, which cannot be null or empty
         */
        public void setPlaylistString(@NonNull final String hlsPlaylistString) {
            this.playlistString = hlsPlaylistString;
        }

        /**
         * Create a new {@link NonUriHlsDataSourceFactory} with the given data source factory and
         * the given HLS playlist.
         *
         * @return a {@link NonUriHlsDataSourceFactory}
         * @throws IllegalArgumentException if the data source factory is null or if the HLS
         * playlist string set is null or empty
         */
        @NonNull
        public NonUriHlsDataSourceFactory build() {
            if (dataSourceFactory == null) {
                throw new IllegalArgumentException(
                        "No DataSource.Factory valid instance has been specified.");
            }

            if (playlistString == null || playlistString.isEmpty()) {
                throw new IllegalArgumentException("No HLS valid playlist has been specified.");
            }

            return new NonUriHlsDataSourceFactory(dataSourceFactory,
                    playlistString.getBytes(StandardCharsets.UTF_8));
        }
    }

    private final DataSource.Factory dataSourceFactory;
    private final byte[] playlistStringByteArray;

    /**
     * Create a {@link NonUriHlsDataSourceFactory} instance.
     *
     * @param dataSourceFactory       the {@link DataSource.Factory} which will be used to build
     *                                non manifests {@link DataSource}s, which must not be null
     * @param playlistStringByteArray a byte array of the HLS playlist, which must not be null
     */
    private NonUriHlsDataSourceFactory(@NonNull final DataSource.Factory dataSourceFactory,
                                       @NonNull final byte[] playlistStringByteArray) {
        this.dataSourceFactory = dataSourceFactory;
        this.playlistStringByteArray = playlistStringByteArray;
    }

    /**
     * Create a {@link DataSource} for the given data type.
     *
     * <p>
     * This change allow playback of non-URI HLS contents, when the manifest is not a master
     * manifest/playlist (otherwise, endless loops should be encountered because the
     * {@link DataSource}s created for media playlists should use the master playlist response
     * instead).
     * </p>
     *
     * @param dataType the data type for which the {@link DataSource} will be used, which is one of
     *                 {@code .DATA_TYPE_*} constants
     * @return a {@link DataSource} for the given data type
     */
    @OptIn(markerClass = UnstableApi.class)
    @NonNull
    @Override
    public DataSource createDataSource(final int dataType) {
        // The manifest is already downloaded and provided with playlistStringByteArray, so we
        // don't need to download it again and we can use a ByteArrayDataSource instead
        if (dataType == C.DATA_TYPE_MANIFEST) {
            return new ByteArrayDataSource(playlistStringByteArray);
        }

        return dataSourceFactory.createDataSource();
    }
}
