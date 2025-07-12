package io.flutter.plugins.videoplayer.custom;

import androidx.annotation.Nullable;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.hls.playlist.DefaultHlsPlaylistParserFactory;
import androidx.media3.exoplayer.hls.playlist.HlsMediaPlaylist;
import androidx.media3.exoplayer.hls.playlist.HlsMultivariantPlaylist;
import androidx.media3.exoplayer.hls.playlist.HlsPlaylist;
import androidx.media3.exoplayer.hls.playlist.HlsPlaylistParserFactory;
import androidx.media3.exoplayer.upstream.ParsingLoadable;
import io.flutter.plugins.videoplayer.custom.HlsPlaylistParser;

@UnstableApi
public class CustomHlsPlaylistParserFactory implements HlsPlaylistParserFactory {

    @Override
    public ParsingLoadable.Parser<HlsPlaylist> createPlaylistParser() {
        return new HlsPlaylistParser();
    }

    @Override
    public ParsingLoadable.Parser<HlsPlaylist> createPlaylistParser(
            HlsMultivariantPlaylist multivariantPlaylist,
            @Nullable HlsMediaPlaylist previousMediaPlaylist) {
        return new HlsPlaylistParser(multivariantPlaylist, previousMediaPlaylist);
    }
}