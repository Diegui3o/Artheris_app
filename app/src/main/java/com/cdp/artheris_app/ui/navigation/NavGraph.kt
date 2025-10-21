package com.cdp.artheris_app.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.cdp.artheris_app.ui.screens.AngleScreen
import com.cdp.artheris_app.ui.screens.WifiScreen
import com.cdp.artheris_app.ui.screens.CameraScreen
import com.cdp.artheris_app.ui.screens.GpsScreen
import com.cdp.artheris_app.ui.screens.SettingsScreen
import com.cdp.artheris_app.ui.screens.StatusScreen

@Composable
fun AppNavGraph(
    navController: NavHostController,
    modifier: Modifier = Modifier
) {
    NavHost(
        navController = navController,
        startDestination = Routes.ANGLE,
        modifier = modifier
    ) {
        composable(Routes.ANGLE)    { AngleScreen() }
        composable(Routes.WIFI)     { WifiScreen() }
        composable(Routes.CAMERA)   { CameraScreen() }
        composable(Routes.GPS)      { GpsScreen() }
        composable(Routes.SETTINGS) { SettingsScreen() }
        composable(Routes.STATUS)   { StatusScreen() }
    }
}
