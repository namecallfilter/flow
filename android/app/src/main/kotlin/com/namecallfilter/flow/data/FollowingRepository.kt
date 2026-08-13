package com.namecallfilter.flow.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

enum class TwitchSessionStatus { UNINITIALIZED, RESTORING, AUTHENTICATED, LOGGED_OUT, RESTORE_FAILED }

data class FollowingState(
    val connection: TwitchAuthConnection? = null,
    val sessionStatus: TwitchSessionStatus = TwitchSessionStatus.UNINITIALIZED,
    val isLoadingFollowing: Boolean = false,
    val followingError: String? = null,
    val offlineExpandedOverride: Boolean? = null,
) {
    // Mapping the authenticated payload allocates and sorts. Cache it for this immutable state
    // snapshot so recomposition never repeats the work merely because a derived value is read.
    val liveChannels: List<StreamChannel> by lazy(LazyThreadSafetyMode.NONE) {
        connection?.let(::liveChannelsFromConnection).orEmpty()
    }
    val offlineChannels: List<OfflineChannel> by lazy(LazyThreadSafetyMode.NONE) {
        connection?.let(::offlineChannelsFromConnection).orEmpty()
    }
    val profileUser: TwitchUser? by lazy(LazyThreadSafetyMode.NONE) {
        connection?.let { it.usersById[it.user.id] ?: it.user }
    }
    val offlineExpanded: Boolean get() = offlineExpandedOverride ?: liveChannels.isEmpty()
    val showLiveEmptyState: Boolean get() = liveChannels.isEmpty() && offlineChannels.isEmpty()
    val isLoggedIn: Boolean get() = connection != null
}

class FollowingRepository(
    val authController: TwitchAuthController,
    private val apiCache: TwitchApiCache? = null,
) {
    private val lock = Any()
    private var attemptedSavedConnection = false
    private var sessionRevision = 0
    private var savedConnectionLoad: CompletableDeferred<Unit>? = null
    private var savedConnectionRefresh: CompletableDeferred<Unit>? = null
    private val mutableState = MutableStateFlow(FollowingState())
    val state: StateFlow<FollowingState> = mutableState.asStateFlow()

    suspend fun loadSavedConnection(refresh: Boolean = false) {
        when (val start = synchronized(lock) { prepareLoad(refresh) }) {
            LoadStart.Return -> return
            is LoadStart.Await -> {
                start.operation.await()
                return
            }
            is LoadStart.QueueRefresh -> {
                try {
                    start.activeLoad.await()
                    if (isCurrent(start.revision)) loadSavedConnection(refresh = true)
                } finally {
                    synchronized(lock) {
                        if (savedConnectionRefresh === start.operation) savedConnectionRefresh = null
                    }
                    start.operation.complete(Unit)
                }
                return
            }
            is LoadStart.Run -> runSavedConnectionLoad(start)
        }
    }

    private suspend fun runSavedConnectionLoad(start: LoadStart.Run) {
        val revision = start.revision
        val previous = start.previousConnection
        val hadAttempted = start.hadAttempted

        try {
            if (!authController.config.isConfigured) {
                if (isCurrent(revision)) {
                    mutableState.update {
                        it.copy(
                            connection = null,
                            sessionStatus = TwitchSessionStatus.LOGGED_OUT,
                        )
                    }
                }
                return
            }
            mutableState.update {
                it.copy(
                    sessionStatus = if (it.connection == null && !hadAttempted) {
                        TwitchSessionStatus.RESTORING
                    } else {
                        it.sessionStatus
                    },
                    isLoadingFollowing = true,
                    followingError = null,
                )
            }
            val saved = authController.loadSavedConnection()
            if (!isCurrent(revision)) return
            if (hadAttempted && previous?.user?.id != saved?.user?.id) apiCache?.clear()
            mutableState.update {
                it.copy(
                    connection = saved,
                    sessionStatus = if (saved == null) {
                        TwitchSessionStatus.LOGGED_OUT
                    } else {
                        TwitchSessionStatus.AUTHENTICATED
                    },
                    isLoadingFollowing = false,
                    followingError = null,
                )
            }
        } catch (error: CancellationException) {
            throw error
        } catch (error: Throwable) {
            if (!isCurrent(revision)) return
            mutableState.update {
                it.copy(
                    isLoadingFollowing = false,
                    followingError = error.toString(),
                    sessionStatus = if (it.connection == null) {
                        TwitchSessionStatus.RESTORE_FAILED
                    } else {
                        TwitchSessionStatus.AUTHENTICATED
                    },
                )
            }
        } finally {
            if (isCurrent(revision)) mutableState.update { it.copy(isLoadingFollowing = false) }
            synchronized(lock) {
                if (savedConnectionLoad === start.operation) savedConnectionLoad = null
            }
            start.operation.complete(Unit)
        }
    }

    private fun prepareLoad(refresh: Boolean): LoadStart {
        val activeLoad = savedConnectionLoad
        if (activeLoad != null) {
            if (!refresh) return LoadStart.Await(activeLoad)
            savedConnectionRefresh?.let { return LoadStart.Await(it) }
            return LoadStart.QueueRefresh(
                activeLoad = activeLoad,
                operation = CompletableDeferred<Unit>().also { savedConnectionRefresh = it },
                revision = sessionRevision,
            )
        }
        val current = mutableState.value
        if (!refresh && (attemptedSavedConnection || current.connection != null)) {
            if (current.connection != null) {
                mutableState.value = current.copy(sessionStatus = TwitchSessionStatus.AUTHENTICATED)
            }
            return LoadStart.Return
        }
        val hadAttempted = attemptedSavedConnection
        attemptedSavedConnection = true
        sessionRevision += 1
        return LoadStart.Run(
            operation = CompletableDeferred<Unit>().also { savedConnectionLoad = it },
            revision = sessionRevision,
            hadAttempted = hadAttempted,
            previousConnection = current.connection,
        )
    }

    fun applyConnection(connection: TwitchAuthConnection) {
        synchronized(lock) {
            sessionRevision += 1
            attemptedSavedConnection = true
            savedConnectionRefresh = null
        }
        apiCache?.clear()
        mutableState.update {
            it.copy(
                connection = connection,
                sessionStatus = TwitchSessionStatus.AUTHENTICATED,
                isLoadingFollowing = false,
                followingError = null,
            )
        }
    }

    suspend fun signOut() {
        val revision = synchronized(lock) {
            sessionRevision += 1
            attemptedSavedConnection = true
            savedConnectionRefresh = null
            sessionRevision
        }
        apiCache?.clear()
        mutableState.update { it.copy(isLoadingFollowing = false) }
        try {
            authController.signOut()
        } catch (error: Throwable) {
            if (isCurrent(revision)) {
                mutableState.update {
                    it.copy(
                        followingError = error.toString(),
                        sessionStatus = if (it.connection == null) {
                            TwitchSessionStatus.RESTORE_FAILED
                        } else {
                            TwitchSessionStatus.AUTHENTICATED
                        },
                    )
                }
            }
            throw error
        }
        if (!isCurrent(revision)) return
        mutableState.update {
            it.copy(
                connection = null,
                sessionStatus = TwitchSessionStatus.LOGGED_OUT,
                isLoadingFollowing = false,
                followingError = null,
            )
        }
    }

    fun toggleOfflineExpanded() = mutableState.update { current ->
        val expanded = current.offlineExpandedOverride ?: current.liveChannels.isEmpty()
        current.copy(offlineExpandedOverride = !expanded)
    }

    private fun isCurrent(revision: Int) = synchronized(lock) { revision == sessionRevision }

    private sealed interface LoadStart {
        data object Return : LoadStart
        data class Await(val operation: CompletableDeferred<Unit>) : LoadStart
        data class QueueRefresh(
            val activeLoad: CompletableDeferred<Unit>,
            val operation: CompletableDeferred<Unit>,
            val revision: Int,
        ) : LoadStart
        data class Run(
            val operation: CompletableDeferred<Unit>,
            val revision: Int,
            val hadAttempted: Boolean,
            val previousConnection: TwitchAuthConnection?,
        ) : LoadStart
    }
}
