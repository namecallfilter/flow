package com.namecallfilter.flow.ui

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class StartupAccountCoordinatorTest {
    @Test fun `unconfigured auth guidance matches Flutter`() {
        assertEquals(
            "Set TWITCH_CLIENT_ID with --dart-define-from-file=.env to start Twitch auth.",
            TWITCH_AUTH_NOT_CONFIGURED_MESSAGE,
        )
    }

    @Test fun `profile request waits for complete startup restoration`() = runTest {
        var reloads = 0
        var loggedIn = false
        val coordinator = StartupAccountCoordinator(
            loadSavedConnection = {
                reloads += 1
                loggedIn = true
            },
            isLoggedIn = { loggedIn },
        )

        val request = async {
            coordinator.resolveMeRequest(isStartupOfferShowing = { false })
        }
        runCurrent()

        assertFalse(request.isCompleted)
        assertEquals(0, reloads)

        coordinator.completeInitialRestore()
        assertEquals(MeRequestResolution.OPEN_SETTINGS, request.await())
        assertEquals(1, reloads)
    }

    @Test fun `profile request reloads after startup and opens login only when still logged out`() = runTest {
        var reloads = 0
        val coordinator = StartupAccountCoordinator(
            loadSavedConnection = { reloads += 1 },
            isLoggedIn = { false },
        )
        coordinator.completeInitialRestore()

        assertEquals(
            MeRequestResolution.OPEN_LOGIN,
            coordinator.resolveMeRequest(isStartupOfferShowing = { false }),
        )
        assertEquals(1, reloads)
    }

    @Test fun `startup offer wins over account navigation after reload`() = runTest {
        val coordinator = StartupAccountCoordinator(
            loadSavedConnection = {},
            isLoggedIn = { true },
        )
        coordinator.completeInitialRestore()

        assertEquals(
            MeRequestResolution.STARTUP_OFFER_ACTIVE,
            coordinator.resolveMeRequest(isStartupOfferShowing = { true }),
        )
    }

    @Test fun `overlapping profile request is ignored while first awaits startup`() = runTest {
        val coordinator = StartupAccountCoordinator(
            loadSavedConnection = {},
            isLoggedIn = { false },
        )
        val first = async {
            coordinator.resolveMeRequest(isStartupOfferShowing = { false })
        }
        runCurrent()

        assertEquals(
            MeRequestResolution.ALREADY_HANDLING,
            coordinator.resolveMeRequest(isStartupOfferShowing = { false }),
        )

        coordinator.completeInitialRestore()
        assertEquals(MeRequestResolution.OPEN_LOGIN, first.await())
    }

    @Test fun `guest continuation keeps exact persistent message when session clear fails`() = runTest {
        var saved = false

        val result = continueAsGuest(
            signOut = { error("clear failed") },
            saveDismissedChoice = { saved = true },
        )

        assertEquals(
            GuestContinuationResult.Failed(CLEAR_TWITCH_SESSION_FAILURE_MESSAGE),
            result,
        )
        assertFalse(saved)
    }

    @Test fun `guest continuation keeps exact persistent message when choice save fails`() = runTest {
        var signedOut = false

        val result = continueAsGuest(
            signOut = { signedOut = true },
            saveDismissedChoice = { error("save failed") },
        )

        assertTrue(signedOut)
        assertEquals(
            GuestContinuationResult.Failed(SAVE_GUEST_CHOICE_FAILURE_MESSAGE),
            result,
        )
    }

    @Test fun `guest continuation succeeds only after clear and save complete in order`() = runTest {
        val calls = mutableListOf<String>()

        val result = continueAsGuest(
            signOut = { calls += "clear" },
            saveDismissedChoice = { calls += "save" },
        )

        assertEquals(GuestContinuationResult.Completed, result)
        assertEquals(listOf("clear", "save"), calls)
    }

    @Test fun `guest continuation does not swallow cancellation`() = runTest {
        var caught: Throwable? = null
        try {
            continueAsGuest(
                signOut = { throw CancellationException("cancelled") },
                saveDismissedChoice = {},
            )
        } catch (error: Throwable) {
            caught = error
        }

        assertTrue(caught is CancellationException)
    }
}
