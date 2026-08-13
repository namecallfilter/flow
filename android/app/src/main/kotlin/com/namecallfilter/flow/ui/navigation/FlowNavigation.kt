package com.namecallfilter.flow.ui.navigation

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.runtime.toMutableStateList
import androidx.lifecycle.ViewModel
import com.namecallfilter.flow.data.BrowseCategory
import com.namecallfilter.flow.data.StreamChannel

enum class FlowTab {
    FOLLOWING,
    BROWSE,
    SETTINGS,
}

data class ChannelSeed(
    val login: String,
    val displayName: String,
    val avatarImageUrl: String? = null,
    val isLive: Boolean = false,
)

sealed interface FlowDestination {
    data object Following : FlowDestination
    data object Browse : FlowDestination
    data object Settings : FlowDestination
    data object Search : FlowDestination
    data class Category(
        val category: BrowseCategory,
        val reuseBrowseRepository: Boolean = false,
    ) : FlowDestination
    data class Channel(val channel: ChannelSeed) : FlowDestination
}

internal data class FlowNavigationEntry(
    val id: Long,
    val destination: FlowDestination,
)

internal data class FlowBackPreview(
    val tab: FlowTab,
    val entry: FlowNavigationEntry,
)

internal class FlowPlayerFrame(
    val id: Long,
    val channel: StreamChannel,
    val tab: FlowTab,
) {
    val destinations = mutableStateListOf<FlowNavigationEntry>()
    val currentDestinationEntry: FlowNavigationEntry?
        get() = destinations.lastOrNull()
}

class FlowNavigationState : ViewModel() {
    var currentTab by mutableStateOf(FlowTab.FOLLOWING)
        private set

    private var nextEntryId = 0L

    private val stacks = mapOf(
        FlowTab.FOLLOWING to listOf(newEntry(FlowDestination.Following)).toMutableStateList(),
        FlowTab.BROWSE to listOf(newEntry(FlowDestination.Browse)).toMutableStateList(),
        FlowTab.SETTINGS to listOf(newEntry(FlowDestination.Settings)).toMutableStateList(),
    )
    internal val playerFrames = mutableStateListOf<FlowPlayerFrame>()

    internal val currentStack: SnapshotStateList<FlowNavigationEntry>
        get() = stackFor(currentTab)

    internal fun stackFor(tab: FlowTab): SnapshotStateList<FlowNavigationEntry> =
        requireNotNull(stacks[tab])

    internal val currentEntry: FlowNavigationEntry
        get() = currentStack.last()

    val currentDestination: FlowDestination
        get() = currentEntry.destination

    val activePlayer: StreamChannel?
        get() = playerFrames.lastOrNull()?.channel

    internal val currentPlayerFrame: FlowPlayerFrame?
        get() = playerFrames.lastOrNull()

    internal val currentPlayerDestinationEntry: FlowNavigationEntry?
        get() = currentPlayerFrame?.currentDestinationEntry

    internal val playerCoveredByDestination: Boolean
        get() = currentPlayerDestinationEntry != null

    internal val backPreview: FlowBackPreview?
        get() = when {
            playerFrames.isNotEmpty() -> null
            currentStack.size > 1 -> FlowBackPreview(
                tab = currentTab,
                entry = currentStack[currentStack.lastIndex - 1],
            )
            currentTab != FlowTab.FOLLOWING -> FlowBackPreview(
                tab = FlowTab.FOLLOWING,
                entry = requireNotNull(stacks[FlowTab.FOLLOWING]).last(),
            )
            else -> null
        }

    internal val activeEntryIds: Set<Long>
        get() = stacks.values.flatMapTo(mutableSetOf()) { stack -> stack.map { it.id } }
            .also { ids ->
                playerFrames.forEach { frame ->
                    ids += frame.id
                    frame.destinations.mapTo(ids) { it.id }
                }
            }

    fun selectTab(tab: FlowTab) {
        currentTab = tab
    }

    fun push(destination: FlowDestination) {
        currentStack += newEntry(destination)
    }

    fun replace(destination: FlowDestination) {
        currentStack[currentStack.lastIndex] = newEntry(destination)
    }

    internal fun pushPlayerDestination(destination: FlowDestination) {
        val frame = currentPlayerFrame
        if (frame == null) {
            push(destination)
        } else {
            frame.destinations += newEntry(destination)
        }
    }

    fun openPlayer(channel: StreamChannel) {
        val login = channel.login.trim()
        if (login.isEmpty()) return
        val normalized = if (login == channel.login) channel else channel.copy(login = login)
        playerFrames += FlowPlayerFrame(
            id = ++nextEntryId,
            channel = normalized,
            tab = currentTab,
        )
    }

    fun closePlayer() {
        if (playerFrames.isNotEmpty()) playerFrames.removeAt(playerFrames.lastIndex)
    }

    fun canNavigateBack(): Boolean =
        activePlayer != null || currentStack.size > 1 || currentTab != FlowTab.FOLLOWING

    fun navigateBack(): Boolean {
        val playerFrame = currentPlayerFrame
        if (playerFrame?.destinations?.isNotEmpty() == true) {
            playerFrame.destinations.removeAt(playerFrame.destinations.lastIndex)
            return true
        }
        if (playerFrame != null) {
            closePlayer()
            return true
        }
        if (currentStack.size > 1) {
            currentStack.removeAt(currentStack.lastIndex)
            return true
        }
        if (currentTab != FlowTab.FOLLOWING) {
            currentTab = FlowTab.FOLLOWING
            return true
        }
        return false
    }

    private fun newEntry(destination: FlowDestination): FlowNavigationEntry =
        FlowNavigationEntry(id = ++nextEntryId, destination = destination)
}
