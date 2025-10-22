package com.emergency.Resme

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.telephony.SmsManager
import android.content.Context
import android.telephony.TelephonyManager
import android.util.Log
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity: FlutterActivity() {
    private val CHANNEL = "emergency_sms"
    private val SMS_PERMISSION_REQUEST = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")
                    
                    if (phoneNumber != null && message != null) {
                        sendSMS(phoneNumber, message, result)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Phone number and message are required", null)
                    }
                }
                "checkSimCards" -> {
                    checkSimCards(result)
                }
                "checkDeviceCompatibility" -> {
                    checkDeviceCompatibility(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun sendSMS(phoneNumber: String, message: String, result: MethodChannel.Result) {
        try {
            Log.d("EmergencySMS", "Attempting to send SMS to: $phoneNumber")
            
            // Check permissions first
            if (!hasRequiredPermissions()) {
                result.error("PERMISSION_DENIED", "SMS permissions not granted", null)
                return
            }
            
            // Check device compatibility
            val deviceInfo = getDeviceInfo()
            Log.d("EmergencySMS", "Device: ${deviceInfo["manufacturer"]} ${deviceInfo["model"]}")
            
            var success = false
            var lastError = ""

            // Method 1: Try with subscription ID first (more reliable on dual-SIM or custom OS)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                try {
                    Log.d("EmergencySMS", "Trying subscription-based SMS first...")
                    val subscriptionManager = android.telephony.SubscriptionManager.from(this)
                    val activeSubscriptions = subscriptionManager.activeSubscriptionInfoList
                    
                    if (activeSubscriptions != null && activeSubscriptions.isNotEmpty()) {
                        // Use the first active subscription
                        val subscription = activeSubscriptions[0]
                        try {
                            Log.d("EmergencySMS", "Using subscription ID: ${subscription.subscriptionId}")
                            val smsManager = SmsManager.getSmsManagerForSubscriptionId(subscription.subscriptionId)
                            
                            val parts = smsManager.divideMessage(message)
                            if (parts.size == 1) {
                                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                            } else {
                                smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                            }
                            
                            Log.d("EmergencySMS", "SMS sent successfully via subscription ID: ${subscription.subscriptionId}")
                            success = true
                        } catch (e: Exception) {
                            lastError = "Subscription ${subscription.subscriptionId} failed: ${e.message}"
                            Log.e("EmergencySMS", lastError)
                        }
                    }
                } catch (e: Exception) {
                    lastError = "Subscription manager failed: ${e.message}"
                    Log.e("EmergencySMS", lastError)
                }
            }
            
            // Method 2: Fallback to default SmsManager
            if (!success) {
                try {
                    Log.d("EmergencySMS", "Falling back to default SmsManager...")
                    val smsManager = SmsManager.getDefault()
                    
                    // Split long messages if needed
                    val parts = smsManager.divideMessage(message)
                    if (parts.size == 1) {
                        smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                    } else {
                        smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                    }
                    
                    Log.d("EmergencySMS", "SMS sent successfully via default SmsManager")
                    success = true
                } catch (e: Exception) {
                    lastError = "Default SmsManager failed: ${e.message}"
                    Log.e("EmergencySMS", lastError)
                }
            }
            
            if (success) {
                result.success("SMS sent successfully")
            } else {
                result.error("SMS_FAILED", "All SMS sending methods failed. Last error: $lastError", null)
            }
            
        } catch (e: Exception) {
            Log.e("EmergencySMS", "SMS sending error: ${e.message}")
            result.error("SMS_ERROR", e.message, null)
        }
    }

    private fun checkSimCards(result: MethodChannel.Result) {
        try {
            val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            val simState = telephonyManager.simState
            
            val simInfo = mutableMapOf<String, Any>()
            simInfo["simState"] = simState
            simInfo["hasSimCard"] = simState == TelephonyManager.SIM_STATE_READY
            simInfo["deviceInfo"] = getDeviceInfo()
            
            // Check for dual SIM
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                try {
                    val subscriptionManager = android.telephony.SubscriptionManager.from(this)
                    val activeSubscriptions = subscriptionManager.activeSubscriptionInfoList
                    
                    simInfo["activeSimCount"] = activeSubscriptions?.size ?: 0
                    simInfo["isDualSim"] = (activeSubscriptions?.size ?: 0) > 1
                    
                    if (activeSubscriptions != null) {
                        val simDetails = mutableListOf<Map<String, Any>>()
                        for (subscription in activeSubscriptions) {
                            val simDetail = mapOf(
                                "subscriptionId" to subscription.subscriptionId,
                                "displayName" to (subscription.displayName?.toString() ?: "Unknown"),
                                "simSlotIndex" to subscription.simSlotIndex,
                                "carrierName" to (subscription.carrierName?.toString() ?: "Unknown")
                            )
                            simDetails.add(simDetail)
                        }
                        simInfo["simDetails"] = simDetails
                    }
                } catch (e: Exception) {
                    Log.e("EmergencySMS", "Error checking dual SIM: ${e.message}")
                    simInfo["dualSimError"] = e.message ?: "Unknown error"
                }
            }
            
            result.success(simInfo)
        } catch (e: Exception) {
            Log.e("EmergencySMS", "Error checking SIM cards: ${e.message}")
            result.error("SIM_CHECK_ERROR", e.message, null)
        }
    }

    private fun checkDeviceCompatibility(result: MethodChannel.Result) {
        try {
            val deviceInfo = getDeviceInfo()
            val compatibility = mutableMapOf<String, Any>()
            
            compatibility["deviceInfo"] = deviceInfo
            compatibility["hasRequiredPermissions"] = hasRequiredPermissions()
            compatibility["supportsSMS"] = packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
            
            // Check for known problematic manufacturers
            val manufacturer = Build.MANUFACTURER.lowercase()
            val isProblematic = when {
                manufacturer.contains("mediatek") -> "MediaTek devices often have SMS restrictions"
                manufacturer.contains("xiaomi") -> "MIUI may have SMS restrictions"
                manufacturer.contains("huawei") -> "EMUI may have SMS restrictions"
                manufacturer.contains("oppo") -> "ColorOS may have SMS restrictions"
                manufacturer.contains("vivo") -> "FuntouchOS may have SMS restrictions"
                else -> null
            }
            
            if (isProblematic != null) {
                compatibility["knownIssues"] = isProblematic
            }
            
            compatibility["recommendedAction"] = if (isProblematic != null) {
                "Use URL launcher method for SMS sending"
            } else {
                "Device should support silent SMS"
            }
            
            result.success(compatibility)
        } catch (e: Exception) {
            result.error("COMPATIBILITY_CHECK_ERROR", e.message, null)
        }
    }

    private fun getDeviceInfo(): Map<String, String> {
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "brand" to Build.BRAND,
            "device" to Build.DEVICE,
            "androidVersion" to Build.VERSION.RELEASE,
            "apiLevel" to Build.VERSION.SDK_INT.toString()
        )
    }

    private fun hasRequiredPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(this, android.Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED &&
               ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
    }
}
