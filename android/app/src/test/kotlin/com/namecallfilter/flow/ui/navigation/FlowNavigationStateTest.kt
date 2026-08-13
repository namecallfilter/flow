package com.namecallfilter.flow.ui.navigation

import com.namecallfilter.flow.data.StreamChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FlowNavigationStateTest {
    @Test fun `player overlay preserves entry but reopening a popped channel gets a new entry`() {
        val navigation = FlowNavigationState()
        val destination = FlowDestination.Channel(ChannelSeed("creator", "Creator"))
        navigation.push(destination)
        val firstEntryId = navigation.currentEntry.id

        navigation.openPlayer(stream("creator"))
        assertEquals(firstEntryId, navigation.currentEntry.id)
        assertTrue(firstEntryId in navigation.activeEntryIds)

        navigation.closePlayer()
        assertEquals(firstEntryId, navigation.currentEntry.id)
        assertTrue(navigation.navigateBack())
        assertFalse(firstEntryId in navigation.activeEntryIds)

        navigation.push(destination)
        assertNotEquals(firstEntryId, navigation.currentEntry.id)
    }

    @Test fun `player rejects blank login and normalizes a valid login`() {
        val navigation = FlowNavigationState()

        navigation.openPlayer(stream("   "))
        assertNull(navigation.activePlayer)

        navigation.openPlayer(stream("  creator  "))
        assertEquals("creator", navigation.activePlayer?.login)
    }

    @Test fun `player child destination pops back to player and gets a fresh route id when reopened`() {
        val navigation = FlowNavigationState()
        navigation.openPlayer(stream("creator"))
        val destination = FlowDestination.Channel(ChannelSeed("other", "Other"))

        navigation.pushPlayerDestination(destination)
        val firstChildId = requireNotNull(navigation.currentPlayerDestinationEntry).id
        assertTrue(navigation.playerCoveredByDestination)
        assertTrue(firstChildId in navigation.activeEntryIds)

        assertTrue(navigation.navigateBack())
        assertNull(navigation.currentPlayerDestinationEntry)
        assertEquals("creator", navigation.activePlayer?.login)
        assertFalse(firstChildId in navigation.activeEntryIds)

        navigation.pushPlayerDestination(destination)
        assertNotEquals(firstChildId, navigation.currentPlayerDestinationEntry?.id)
    }

    @Test fun `player opened from a player child unwinds to child and prior player`() {
        val navigation = FlowNavigationState()
        navigation.openPlayer(stream("first"))
        navigation.pushPlayerDestination(
            FlowDestination.Category(
                com.namecallfilter.flow.data.BrowseCategory(
                    id = "game",
                    name = "Game",
                    viewerCount = 1,
                    viewers = "1",
                    imageUrl = null,
                    colors = emptyList(),
                ),
            ),
        )
        val childId = requireNotNull(navigation.currentPlayerDestinationEntry).id

        navigation.openPlayer(stream("second"))
        assertEquals("second", navigation.activePlayer?.login)
        assertEquals(2, navigation.playerFrames.size)
        assertNull(navigation.currentPlayerDestinationEntry)
        assertTrue(childId in navigation.activeEntryIds)

        assertTrue(navigation.navigateBack())
        assertEquals("first", navigation.activePlayer?.login)
        assertEquals(childId, navigation.currentPlayerDestinationEntry?.id)

        assertTrue(navigation.navigateBack())
        assertEquals("first", navigation.activePlayer?.login)
        assertNull(navigation.currentPlayerDestinationEntry)
    }

    private fun stream(login: String) = StreamChannel(
        login = login,
        name = "Creator",
        initials = "CR",
        title = "Live",
        category = "Game",
        viewers = "1",
        avatarColors = emptyList(),
        thumbnailColors = emptyList(),
    )
}
