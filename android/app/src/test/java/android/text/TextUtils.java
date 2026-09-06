package android.text;

/** Pure Android string helper needed by Media3's TrackGroup in local JVM tests. */
public final class TextUtils {
    private TextUtils() {}

    public static boolean isEmpty(CharSequence text) {
        return text == null || text.length() == 0;
    }
}
