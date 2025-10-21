package com.cdp.artheris_app.ui.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Explore
import androidx.compose.material.icons.outlined.Wifi
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material.icons.outlined.GpsFixed
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavDestination
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.NavHostController
import com.cdp.artheris_app.R
import com.cdp.artheris_app.ui.navigation.BottomNavItem
import com.cdp.artheris_app.ui.navigation.Routes

@Composable
fun BottomBar(navController: NavHostController) {
    val items = listOf(
        BottomNavItem(Routes.ANGLE,    R.string.tab_angle,    Icons.Outlined.Explore),
        BottomNavItem(Routes.WIFI,     R.string.tab_wifi,     Icons.Outlined.Wifi),
        BottomNavItem(Routes.CAMERA,   R.string.tab_camera,   Icons.Outlined.PhotoCamera),
        BottomNavItem(Routes.GPS,      R.string.tab_gps,      Icons.Outlined.GpsFixed),
        BottomNavItem(Routes.SETTINGS, R.string.tab_settings, Icons.Outlined.Settings),
        BottomNavItem(Routes.STATUS,   R.string.tab_status,   Icons.Outlined.Speed)
    )

    NavigationBar {
        val navBackStackEntry by navController.currentBackStackEntryAsState()
        val currentDestination: NavDestination? = navBackStackEntry?.destination

        items.forEach { item ->
            val selected = currentDestination?.hierarchy?.any { it.route == item.route } == true
            NavigationBarItem(
                selected = selected,
                onClick = {
                    navController.navigate(item.route) {
                        launchSingleTop = true
                        restoreState = true
                        popUpTo(navController.graph.startDestinationId) { saveState = true }
                    }
                },
                icon = { Icon(item.icon, contentDescription = null) },
                label = { Text(text = stringResource(id = item.labelRes)) }
            )
        }
    }
}
