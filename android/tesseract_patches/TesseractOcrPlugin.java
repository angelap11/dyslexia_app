package io.paratoner.tesseract_ocr;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import com.googlecode.tesseract.android.TessBaseAPI;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/**
 * Patched tesseract_ocr Android plugin.
 *
 * Defaults to PSM_AUTO for photographed multi-paragraph pages.
 * Callers may override via the pageSegMode argument and timeoutMs.
 */
public class TesseractOcrPlugin implements MethodCallHandler, FlutterPlugin {

    private static final String TAG = "TesseractOcr";
    /** Last-resort only — Dart must preprocess first. */
    private static final long MAX_IMAGE_BYTES = 5L * 1024L * 1024L;
    private static final long DEFAULT_TIMEOUT_MS = 12_000L;

    private MethodChannel channel;
    private Context appContext;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
        appContext = flutterPluginBinding.getApplicationContext();
        channel = new MethodChannel(
            flutterPluginBinding.getBinaryMessenger(),
            "tesseract_ocr"
        );
        channel.setMethodCallHandler(this);
        logAbiDiagnostics("onAttachedToEngine");
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        appContext = null;
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        switch (call.method) {
            case "getAbiInfo":
                result.success(buildAbiInfo());
                break;
            case "extractText":
            case "extractHocr":
            case "extractTextWithLayout":
                handleExtract(call, result);
                break;
            default:
                result.notImplemented();
        }
    }

    private void handleExtract(MethodCall call, Result result) {
        final String tessDataPath = call.argument("tessData");
        final String imagePath = call.argument("imagePath");
        String defaultLanguage = "eng";

        if (call.argument("language") != null) {
            defaultLanguage = call.argument("language");
        } else {
            Object configObj = call.argument("config");
            if (configObj instanceof java.util.Map) {
                @SuppressWarnings("unchecked")
                java.util.Map<String, Object> config =
                    (java.util.Map<String, Object>) configObj;
                Object languageObj = config.get("language");
                if (languageObj != null) {
                    defaultLanguage = languageObj.toString();
                }
            }
        }

        int pageSegMode = TessBaseAPI.PageSegMode.PSM_AUTO;
        Object psmArg = call.argument("pageSegMode");
        if (psmArg instanceof Number) {
            pageSegMode = ((Number) psmArg).intValue();
        } else if (psmArg instanceof String) {
            try {
                pageSegMode = Integer.parseInt((String) psmArg);
            } catch (NumberFormatException ignored) {}
        }

        long timeoutMs = DEFAULT_TIMEOUT_MS;
        Object timeoutArg = call.argument("timeoutMs");
        if (timeoutArg instanceof Number) {
            timeoutMs = ((Number) timeoutArg).longValue();
        }
        // Clamp so fast-pass cannot hang for tens of seconds.
        if (timeoutMs < 3_000L) timeoutMs = 3_000L;
        if (timeoutMs > 25_000L) timeoutMs = 25_000L;

        if (tessDataPath == null) {
            result.error(
                "INVALID_ARGUMENT",
                "Data path must not be null! Ensure tessdata is properly loaded.",
                null
            );
            return;
        }

        if (imagePath == null) {
            result.error(
                "INVALID_ARGUMENT",
                "Image path must not be null.",
                null
            );
            return;
        }

        final File imageFile = new File(imagePath);
        if (!imageFile.exists() || !imageFile.isFile()) {
            result.error(
                "FILE_NOT_FOUND",
                "Image file does not exist: " + imagePath,
                null
            );
            return;
        }

        final long imageBytes = imageFile.length();
        if (imageBytes > MAX_IMAGE_BYTES) {
            Log.e(
                TAG,
                "Rejecting oversized OCR image bytes=" +
                imageBytes +
                " path=" +
                imagePath
            );
            result.error(
                "IMAGE_TOO_LARGE",
                "OCR image too large (" +
                imageBytes +
                " bytes). Resize before recognition.",
                null
            );
            return;
        }

        final String language = defaultLanguage;
        final boolean isHocr = call.method.equals("extractHocr");
        final boolean withLayout = call.method.equals("extractTextWithLayout");
        final int psm = pageSegMode;
        final long watchdogMs = timeoutMs;

        logAbiDiagnostics(call.method);
        Log.d(
            TAG,
            call.method +
            " queued path=" +
            imagePath +
            " size=" +
            imageBytes +
            " lang=" +
            language +
            " psm=" +
            psm +
            " timeoutMs=" +
            watchdogMs +
            " withLayout=" +
            withLayout +
            " runtimeAbis=" +
            Arrays.toString(Build.SUPPORTED_ABIS) +
            " selectedAbi=" +
            selectedAbi()
        );

        Thread worker = new Thread(
            new MyRunnable(
                tessDataPath,
                language,
                imageFile,
                result,
                isHocr,
                withLayout,
                psm,
                watchdogMs
            ),
            "tesseract-ocr-worker"
        );
        worker.start();
    }

    private void logAbiDiagnostics(String where) {
        Map<String, Object> info = buildAbiInfo();
        Log.d(
            TAG,
            "[" +
            where +
            "] runtimeAbis=" +
            info.get("runtimeAbis") +
            " selectedAbi=" +
            info.get("selectedAbi") +
            " packagedAbis=" +
            info.get("packagedAbis") +
            " nativeLibraryDir=" +
            info.get("nativeLibraryDir") +
            " hasArm64=" +
            info.get("hasArm64NativeLib") +
            " hasArmV7=" +
            info.get("hasArmV7NativeLib")
        );
    }

    private String selectedAbi() {
        if (Build.SUPPORTED_ABIS != null && Build.SUPPORTED_ABIS.length > 0) {
            return Build.SUPPORTED_ABIS[0];
        }
        return "unknown";
    }

    private Map<String, Object> buildAbiInfo() {
        Map<String, Object> map = new HashMap<>();
        List<String> runtime = Build.SUPPORTED_ABIS != null
            ? Arrays.asList(Build.SUPPORTED_ABIS)
            : new ArrayList<String>();
        List<String> runtime64 = Build.SUPPORTED_64_BIT_ABIS != null
            ? Arrays.asList(Build.SUPPORTED_64_BIT_ABIS)
            : new ArrayList<String>();
        List<String> runtime32 = Build.SUPPORTED_32_BIT_ABIS != null
            ? Arrays.asList(Build.SUPPORTED_32_BIT_ABIS)
            : new ArrayList<String>();

        map.put("runtimeAbis", runtime);
        map.put("runtime64Abis", runtime64);
        map.put("runtime32Abis", runtime32);
        map.put("selectedAbi", selectedAbi());

        String nativeDir = "";
        List<String> packaged = new ArrayList<>();
        boolean hasArm64 = false;
        boolean hasArmV7 = false;

        if (appContext != null) {
            ApplicationInfo ai = appContext.getApplicationInfo();
            nativeDir = ai.nativeLibraryDir != null ? ai.nativeLibraryDir : "";
            packaged = scanPackagedAbis(ai);
            hasArm64 = packaged.contains("arm64-v8a");
            hasArmV7 = packaged.contains("armeabi-v7a");

            // Also probe extracted native folder name.
            if (nativeDir.contains("arm64")) {
                hasArm64 = true;
            }
            if (nativeDir.contains("arm") && !nativeDir.contains("arm64")) {
                hasArmV7 = true;
            }
        }

        map.put("nativeLibraryDir", nativeDir);
        map.put("packagedAbis", packaged);
        map.put("hasArm64NativeLib", hasArm64);
        map.put("hasArmV7NativeLib", hasArmV7);
        return map;
    }

    private List<String> scanPackagedAbis(ApplicationInfo ai) {
        List<String> found = new ArrayList<>();
        List<String> apkPaths = new ArrayList<>();
        if (ai.sourceDir != null) apkPaths.add(ai.sourceDir);
        if (ai.splitSourceDirs != null) {
            apkPaths.addAll(Arrays.asList(ai.splitSourceDirs));
        }

        for (String apkPath : apkPaths) {
            ZipFile zip = null;
            try {
                zip = new ZipFile(apkPath);
                java.util.Enumeration<? extends ZipEntry> entries = zip.entries();
                while (entries.hasMoreElements()) {
                    ZipEntry entry = entries.nextElement();
                    String name = entry.getName();
                    if (!name.startsWith("lib/") || !name.endsWith(".so")) {
                        continue;
                    }
                    // lib/<abi>/<name>.so
                    String[] parts = name.split("/");
                    if (parts.length >= 3) {
                        String abi = parts[1];
                        if (!found.contains(abi)) {
                            found.add(abi);
                        }
                    }
                }
            } catch (Throwable t) {
                Log.w(TAG, "Failed scanning APK native libs: " + apkPath, t);
            } finally {
                if (zip != null) {
                    try {
                        zip.close();
                    } catch (Throwable ignored) {}
                }
            }
        }
        return found;
    }
}

class MyRunnable implements Runnable {

    private static final String TAG = "TesseractOcr";

    private final String tessDataPath;
    private final String language;
    private final File tempFile;
    private final Result result;
    private final boolean isHocr;
    private final boolean withLayout;
    private final int pageSegMode;
    private final long timeoutMs;

    public MyRunnable(
        String tessDataPath,
        String language,
        File tempFile,
        Result result,
        boolean isHocr,
        boolean withLayout,
        int pageSegMode,
        long timeoutMs
    ) {
        this.tessDataPath = tessDataPath;
        this.language = language;
        this.tempFile = tempFile;
        this.result = result;
        this.isHocr = isHocr;
        this.withLayout = withLayout;
        this.pageSegMode = pageSegMode;
        this.timeoutMs = timeoutMs;
    }

    @Override
    public void run() {
        TessBaseAPI baseApi = null;
        final Handler timeoutHandler = new Handler(Looper.getMainLooper());
        final AtomicBoolean timedOut = new AtomicBoolean(false);
        Runnable watchdog = null;

        try {
            Log.d(
                TAG,
                "OCR worker started file=" +
                tempFile.getAbsolutePath() +
                " selectedAbi=" +
                (Build.SUPPORTED_ABIS.length > 0
                        ? Build.SUPPORTED_ABIS[0]
                        : "?") +
                " timeoutMs=" +
                timeoutMs +
                " withLayout=" +
                withLayout
            );
            baseApi = new TessBaseAPI();
            if (!baseApi.init(tessDataPath, language)) {
                sendError(
                    "INIT_ERROR",
                    "Failed to initialize Tesseract for language: " + language
                );
                return;
            }

            Log.d(TAG, "Tesseract init ok, setImage psm=" + pageSegMode);
            baseApi.setPageSegMode(pageSegMode);
            baseApi.setImage(tempFile);

            final TessBaseAPI apiRef = baseApi;
            final long watchdogMs = timeoutMs;
            watchdog =
                new Runnable() {
                    @Override
                    public void run() {
                        Log.w(
                            TAG,
                            "Native OCR watchdog — calling stop() after " +
                            watchdogMs +
                            "ms"
                        );
                        timedOut.set(true);
                        try {
                            apiRef.stop();
                        } catch (Throwable t) {
                            Log.e(TAG, "TessBaseAPI.stop failed", t);
                        }
                    }
                };
            timeoutHandler.postDelayed(watchdog, timeoutMs);

            Log.d(TAG, "Recognition started…");
            final long startedAt = System.currentTimeMillis();
            String recognizedText;
            if (isHocr) {
                recognizedText = baseApi.getHOCRText(0);
            } else {
                // Must run recognition before ResultIterator is valid.
                recognizedText = baseApi.getUTF8Text();
            }
            final long elapsed = System.currentTimeMillis() - startedAt;

            if (timedOut.get()) {
                Log.e(
                    TAG,
                    "Recognition aborted by watchdog after " + elapsed + "ms"
                );
                sendError(
                    "OCR_TIMEOUT",
                    "Recognition exceeded native timeout (" + timeoutMs + "ms)"
                );
                return;
            }

            final String text = recognizedText != null ? recognizedText : "";
            Log.d(
                TAG,
                "Recognition completed in " +
                elapsed +
                "ms length=" +
                text.length()
            );

            if (withLayout && !isHocr) {
                List<Map<String, Object>> lines = collectTextLines(baseApi);
                Map<String, Object> payload = new HashMap<>();
                payload.put("text", text);
                payload.put("lines", lines);
                Log.d(TAG, "Layout lines collected count=" + lines.size());
                sendSuccessObject(payload);
            } else {
                sendSuccess(text);
            }
        } catch (Throwable t) {
            Log.e(TAG, "OCR worker failed", t);
            sendError(
                "OCR_ERROR",
                t.getClass().getSimpleName() +
                ": " +
                (t.getMessage() != null ? t.getMessage() : "unknown")
            );
        } finally {
            if (watchdog != null) {
                timeoutHandler.removeCallbacks(watchdog);
            }
            if (baseApi != null) {
                try {
                    baseApi.recycle();
                } catch (Throwable recycleError) {
                    Log.w(TAG, "TessBaseAPI.recycle failed", recycleError);
                }
            }
        }
    }

    /**
     * Collects each text line with bounding box via ResultIterator.
     * RIL_PARA is historically unreliable on Android Tess; Dart uses
     * vertical gaps between RIL_TEXTLINE boxes for paragraph breaks.
     */
    private List<Map<String, Object>> collectTextLines(TessBaseAPI baseApi) {
        List<Map<String, Object>> lines = new ArrayList<>();
        com.googlecode.tesseract.android.ResultIterator iterator = null;
        try {
            iterator = baseApi.getResultIterator();
            if (iterator == null) {
                Log.w(TAG, "ResultIterator null — no layout metadata");
                return lines;
            }
            final int level = TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE;
            iterator.begin();
            do {
                String lineText = iterator.getUTF8Text(level);
                if (lineText == null) {
                    continue;
                }
                lineText = lineText.replace('\n', ' ').trim();
                if (lineText.isEmpty()) {
                    continue;
                }
                android.graphics.Rect box = iterator.getBoundingRect(level);
                Map<String, Object> line = new HashMap<>();
                line.put("text", lineText);
                line.put("left", box.left);
                line.put("top", box.top);
                line.put("right", box.right);
                line.put("bottom", box.bottom);
                lines.add(line);
            } while (iterator.next(level));
        } catch (Throwable t) {
            Log.w(TAG, "Failed collecting text-line layout", t);
        } finally {
            if (iterator != null) {
                try {
                    iterator.delete();
                } catch (Throwable ignored) {}
            }
        }
        return lines;
    }

    private void sendSuccess(String msg) {
        final String text = msg;
        final Result res = result;
        new Handler(Looper.getMainLooper()).post(
            new Runnable() {
                @Override
                public void run() {
                    try {
                        res.success(text);
                    } catch (Throwable t) {
                        Log.e(TAG, "Failed to send OCR success to Flutter", t);
                    }
                }
            }
        );
    }

    private void sendSuccessObject(final Object payload) {
        final Result res = result;
        new Handler(Looper.getMainLooper()).post(
            new Runnable() {
                @Override
                public void run() {
                    try {
                        res.success(payload);
                    } catch (Throwable t) {
                        Log.e(TAG, "Failed to send OCR layout to Flutter", t);
                    }
                }
            }
        );
    }

    private void sendError(String code, String message) {
        final Result res = result;
        new Handler(Looper.getMainLooper()).post(
            new Runnable() {
                @Override
                public void run() {
                    try {
                        res.error(code, message, null);
                    } catch (Throwable t) {
                        Log.e(TAG, "Failed to send OCR error to Flutter", t);
                    }
                }
            }
        );
    }
}
