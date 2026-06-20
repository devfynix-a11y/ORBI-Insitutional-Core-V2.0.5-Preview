package com.orbi.mobile

import android.content.pm.ActivityInfo
import android.database.ContentObserver
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Base64
import android.util.Log
import android.view.WindowManager
import androidx.core.content.ContextCompat
import androidx.credentials.CreateCredentialResponse
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialException
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "orbi/passkeys"
    private val allowScreenshotsForPreview = true
    private lateinit var credentialManager: CredentialManager
    private var rotationObserver: ContentObserver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (allowScreenshotsForPreview) {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
        applySystemRotationPreference()
    }

    override fun onResume() {
        super.onResume()
        applySystemRotationPreference()
        registerSystemRotationObserver()
    }

    override fun onPause() {
        unregisterSystemRotationObserver()
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        credentialManager = CredentialManager.create(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "createCredential" -> handleCreateCredential(call, result)
                    "getAssertion" -> handleGetAssertion(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerSystemRotationObserver() {
        if (rotationObserver != null) return
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                applySystemRotationPreference()
            }
        }
        rotationObserver = observer
        contentResolver.registerContentObserver(
            Settings.System.getUriFor(Settings.System.ACCELEROMETER_ROTATION),
            false,
            observer,
        )
    }

    private fun unregisterSystemRotationObserver() {
        val observer = rotationObserver ?: return
        contentResolver.unregisterContentObserver(observer)
        rotationObserver = null
    }

    private fun applySystemRotationPreference() {
        requestedOrientation = if (isSystemAutoRotateEnabled()) {
            ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        } else {
            ActivityInfo.SCREEN_ORIENTATION_LOCKED
        }
    }

    private fun isSystemAutoRotateEnabled(): Boolean {
        return try {
            Settings.System.getInt(
                contentResolver,
                Settings.System.ACCELEROMETER_ROTATION,
                0,
            ) == 1
        } catch (_: Exception) {
            false
        }
    }

    private fun handleCreateCredential(call: MethodCall, result: MethodChannel.Result) {
        val options = call.argument<Any>("options")
        if (options == null) {
            result.error("invalid_args", "Missing createCredential options", null)
            return
        }

        val optionsJson = toJsonString(options)
        Log.i("OrbiPasskey", "createCredential request json length=${optionsJson.length}")

        val request = CreatePublicKeyCredentialRequest(optionsJson)
        credentialManager.createCredentialAsync(
            this,
            request,
            null,
            ContextCompat.getMainExecutor(this),
            object :
                CredentialManagerCallback<CreateCredentialResponse, CreateCredentialException> {
                override fun onResult(response: CreateCredentialResponse) {
                    if (response is CreatePublicKeyCredentialResponse) {
                        val json = response.registrationResponseJson
                        result.success(parseJsonObject(json))
                        return
                    }
                    result.error(
                        "unsupported_response",
                        "Unsupported create credential response type: ${response::class.java.simpleName}",
                        null,
                    )
                }

                override fun onError(e: CreateCredentialException) {
                    Log.e("OrbiPasskey", "createCredential failed: ${e.type} ${e.message}", e)
                    val details = mapOf(
                        "type" to e.type,
                        "message" to e.message,
                        "class" to e::class.java.simpleName,
                    )
                    result.error("create_credential_failed", e.message ?: e.type, details)
                }
            },
        )
    }

    private fun handleGetAssertion(call: MethodCall, result: MethodChannel.Result) {
        val options = call.argument<Any>("options")
        if (options == null) {
            result.error("invalid_args", "Missing getAssertion options", null)
            return
        }

        val optionsJson = normalizeGetOptionsJson(options)
        Log.i("OrbiPasskey", "getAssertion request json length=${optionsJson.length}")

        val request = GetCredentialRequest(
            listOf(GetPublicKeyCredentialOption(optionsJson)),
        )
        credentialManager.getCredentialAsync(
            this,
            request,
            null,
            ContextCompat.getMainExecutor(this),
            object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                override fun onResult(response: GetCredentialResponse) {
                    val credential = response.credential
                    if (credential is PublicKeyCredential) {
                        val json = credential.authenticationResponseJson
                        result.success(parseJsonObject(json))
                        return
                    }
                    result.error(
                        "unsupported_credential",
                        "Unsupported credential type: ${credential::class.java.simpleName}",
                        null,
                    )
                }

                override fun onError(e: GetCredentialException) {
                    Log.e("OrbiPasskey", "getAssertion failed: ${e.type} ${e.message}", e)
                    val details = mapOf(
                        "type" to e.type,
                        "message" to e.message,
                        "class" to e::class.java.simpleName,
                    )
                    result.error("get_assertion_failed", e.message ?: e.type, details)
                }
            },
        )
    }

    private fun toJsonString(value: Any): String {
        return when (value) {
            is String -> value
            is Map<*, *> -> mapToJsonObject(value).toString()
            is List<*> -> listToJsonArray(value).toString()
            else -> JSONObject.wrap(value).toString()
        }
    }

    private fun normalizeGetOptionsJson(value: Any): String {
        val jsonObject = when (value) {
            is String -> JSONObject(value)
            is Map<*, *> -> mapToJsonObject(value)
            else -> {
                val wrapped = JSONObject.wrap(value)
                if (wrapped is JSONObject) wrapped else JSONObject()
            }
        }

        normalizeAllowCredentials(jsonObject)
        if (jsonObject.has("publicKey") && jsonObject.get("publicKey") is JSONObject) {
            normalizeAllowCredentials(jsonObject.getJSONObject("publicKey"))
        }
        return jsonObject.toString()
    }

    private fun normalizeAllowCredentials(jsonObject: JSONObject) {
        val allow = jsonObject.optJSONArray("allowCredentials") ?: return
        for (i in 0 until allow.length()) {
            val item = allow.optJSONObject(i) ?: continue
            val rawId = item.optString("id", "")
            if (rawId.isBlank()) continue
            val normalized = normalizeCredentialId(rawId)
            if (normalized != rawId) {
                item.put("id", normalized)
            }
        }
    }

    private fun normalizeCredentialId(value: String): String {
        return try {
            val bytes = Base64.decode(value, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
            Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
        } catch (_: IllegalArgumentException) {
            try {
                val bytes = Base64.decode(value, Base64.NO_WRAP)
                Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
            } catch (_: IllegalArgumentException) {
                value
            }
        }
    }

    private fun mapToJsonObject(map: Map<*, *>): JSONObject {
        val obj = JSONObject()
        for ((k, v) in map) {
            if (k == null) continue
            obj.put(k.toString(), toJsonValue(v))
        }
        return obj
    }

    private fun listToJsonArray(list: List<*>): JSONArray {
        val arr = JSONArray()
        for (item in list) {
            arr.put(toJsonValue(item))
        }
        return arr
    }

    private fun toJsonValue(value: Any?): Any? {
        return when (value) {
            null -> JSONObject.NULL
            is Map<*, *> -> mapToJsonObject(value)
            is List<*> -> listToJsonArray(value)
            else -> value
        }
    }

    private fun parseJsonObject(json: String): Map<String, Any?> {
        return try {
            jsonObjectToMap(JSONObject(json))
        } catch (_: Exception) {
            mapOf("raw" to json)
        }
    }

    private fun jsonObjectToMap(jsonObject: JSONObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        val keys = jsonObject.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            map[key] = fromJsonValue(jsonObject.opt(key))
        }
        return map
    }

    private fun jsonArrayToList(jsonArray: JSONArray): List<Any?> {
        val list = mutableListOf<Any?>()
        for (i in 0 until jsonArray.length()) {
            list.add(fromJsonValue(jsonArray.opt(i)))
        }
        return list
    }

    private fun fromJsonValue(value: Any?): Any? {
        return when (value) {
            JSONObject.NULL -> null
            is JSONObject -> jsonObjectToMap(value)
            is JSONArray -> jsonArrayToList(value)
            else -> value
        }
    }
}
