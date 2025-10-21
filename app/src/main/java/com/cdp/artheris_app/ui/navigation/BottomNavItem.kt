package com.cdp.artheris_app.ui.navigation

import androidx.annotation.StringRes
import androidx.compose.ui.graphics.vector.ImageVector

data class BottomNavItem(
    val route: String,
    @StringRes val labelRes: Int,
    val icon: ImageVector
)

object Routes {
    const val ANGLE = "angle"
    const val WIFI = "wifi"
    const val CAMERA = "camera"
    const val GPS = "gps"
    const val SETTINGS = "settings"
    const val STATUS = "status"
}
