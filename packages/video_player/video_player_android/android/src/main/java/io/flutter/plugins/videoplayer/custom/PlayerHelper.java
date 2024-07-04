package io.flutter.plugins.videoplayer.custom;

import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.source.ProgressiveMediaSource;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class PlayerHelper {
    private static final Pattern C_TVHTML5_SIMPLY_EMBEDDED_PLAYER_PATTERN =
            Pattern.compile("&c=TVHTML5_SIMPLY_EMBEDDED_PLAYER");
    private static final Pattern C_WEB_PATTERN = Pattern.compile("&c=WEB");
    private static final Pattern C_ANDROID_PATTERN = Pattern.compile("&c=ANDROID");

    private static final Pattern C_IOS_PATTERN = Pattern.compile("&c=IOS");

    @UnstableApi
    public static int getProgressiveLoadIntervalBytes() {
        return ProgressiveMediaSource.DEFAULT_LOADING_CHECK_INTERVAL_BYTES;
    }

    public static boolean isTvHtml5SimplyEmbeddedPlayerStreamingUrl(final String url) {
        final Pattern pattern = C_TVHTML5_SIMPLY_EMBEDDED_PLAYER_PATTERN;
        final Matcher mat = pattern.matcher(url);
        return mat.find();
    }

    public static boolean isWebStreamingUrl(final String url) {
        final Pattern pattern = C_WEB_PATTERN;
        final Matcher mat = pattern.matcher(url);
        return mat.find();
    }

    public static boolean isAndroidStreamingUrl(final String url) {
        final Pattern pattern = C_ANDROID_PATTERN;
        final Matcher mat = pattern.matcher(url);
        return mat.find();
    }

    /**
     * Check if the streaming URL is a URL from the YouTube {@code IOS} client.
     *
     * @param url the streaming URL on which check if it's a {@code IOS} streaming URL.
     * @return true if it's a {@code IOS} streaming URL, false otherwise
     */
    public static boolean isIosStreamingUrl(final String url) {
        final Pattern pattern = C_IOS_PATTERN;
        final Matcher mat = pattern.matcher(url);
        return mat.find();
    }

    public static long getPreferredCacheSize() {
        return 64 * 1024 * 1024L;
    }
}
