package com.namecallfilter.flow.ui.components

internal fun shouldConsumePullMovement(
    refreshing: Boolean,
    intercepting: Boolean,
    atTop: Boolean,
    deltaY: Float,
): Boolean = refreshing || intercepting || (atTop && deltaY > 0f)
