package com.safewallet.app

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PersistableBundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

class MainActivity : FlutterFragmentActivity() {
    private val cryptoExecutor = Executors.newSingleThreadExecutor()
    private var walletConnectLinkChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "safe_wallet/security"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSensitiveScreenProtection" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (enabled) {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE
                        )
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                "excludeWalletStorageFromBackup" -> result.success(null)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "safe_wallet/sensitive_clipboard"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "copySensitiveText" -> {
                    val text = call.argument<String>("text")
                    if (text == null) {
                        result.error("invalid_arguments", "Missing clipboard text.", null)
                        return@setMethodCallHandler
                    }
                    val clip = ClipData.newPlainText("Sensitive wallet data", text)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        val extras = PersistableBundle()
                        extras.putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
                        clip.description.extras = extras
                    }
                    clipboardManager().setPrimaryClip(clip)
                    result.success(null)
                }
                "clearSensitiveClipboardIfMatches" -> {
                    val expected = call.argument<String>("text")
                    val clipboard = clipboardManager()
                    val current = clipboard.primaryClip
                        ?.takeIf { it.itemCount > 0 }
                        ?.getItemAt(0)
                        ?.coerceToText(this)
                        ?.toString()
                    if (expected != null && current == expected) {
                        clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "safe_wallet/app_info"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersion" -> {
                    val packageInfo = packageManager.getPackageInfo(packageName, 0)
                    val buildNumber = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        packageInfo.longVersionCode
                    } else {
                        @Suppress("DEPRECATION")
                        packageInfo.versionCode.toLong()
                    }
                    result.success(
                        mapOf(
                            "version" to (packageInfo.versionName ?: "1.0.0"),
                            "buildNumber" to buildNumber.toString()
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "safe_wallet/crypto"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "derivePbkdf2HmacSha256" -> {
                    val password = call.argument<String>("password")
                    val salt = call.argument<ByteArray>("salt")
                    val iterations = call.argument<Int>("iterations")
                    val bits = call.argument<Int>("bits")
                    if (
                        password == null ||
                        salt == null ||
                        iterations == null ||
                        iterations <= 0 ||
                        bits == null ||
                        bits < 64 ||
                        bits % 8 != 0
                    ) {
                        result.error(
                            "invalid_arguments",
                            "Invalid PBKDF2 parameters.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    cryptoExecutor.execute {
                        try {
                            val key = derivePbkdf2HmacSha256(
                                password = password,
                                salt = salt,
                                iterations = iterations,
                                keyLengthBytes = bits / 8
                            )
                            runOnUiThread { result.success(key) }
                        } catch (_: Exception) {
                            runOnUiThread {
                                result.error(
                                    "kdf_failed",
                                    "Unable to derive the wallet key.",
                                    null
                                )
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        walletConnectLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "safe_wallet/wallet_connect_link"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> result.success(walletConnectUri(intent?.data))
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = walletConnectUri(intent.data) ?: return
        walletConnectLinkChannel?.invokeMethod("onLink", uri)
    }

    override fun onDestroy() {
        walletConnectLinkChannel?.setMethodCallHandler(null)
        walletConnectLinkChannel = null
        cryptoExecutor.shutdown()
        super.onDestroy()
    }

    private fun walletConnectUri(uri: Uri?): String? {
        if (uri == null) return null
        if (uri.scheme == "wc") return uri.toString()
        if (uri.scheme == "safewallet" && uri.host == "walletconnect") {
            val value = uri.getQueryParameter("uri")
            if (value?.startsWith("wc:") == true) return value
        }
        return null
    }

    private fun clipboardManager(): ClipboardManager {
        return getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    }

    private fun derivePbkdf2HmacSha256(
        password: String,
        salt: ByteArray,
        iterations: Int,
        keyLengthBytes: Int
    ): ByteArray {
        val keySpec = PBEKeySpec(
            password.toCharArray(),
            salt,
            iterations,
            keyLengthBytes * Byte.SIZE_BITS
        )
        return try {
            SecretKeyFactory
                .getInstance("PBKDF2WithHmacSHA256")
                .generateSecret(keySpec)
                .encoded
        } finally {
            keySpec.clearPassword()
        }
    }
}
