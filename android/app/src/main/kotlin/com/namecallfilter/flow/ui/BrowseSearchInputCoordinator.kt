package com.namecallfilter.flow.ui

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.namecallfilter.flow.data.BrowseSearchRepository
import com.namecallfilter.flow.data.BrowseSearchState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Mirrors Flutter's search-field timer ownership: the route owns only the pending debounce, while
 * a request that has already started belongs to the retained repository and is allowed to finish.
 */
internal class BrowseSearchInputCoordinator(
    private val repository: BrowseSearchRepository,
    private val debounceScope: CoroutineScope,
    private val requestScope: CoroutineScope,
    private val debounceMillis: Long = 300L,
) {
    var query by mutableStateOf(repository.state.value.query)
        private set

    var isDebouncing by mutableStateOf(false)
        private set

    private var debounceJob: Job? = null

    fun updateQuery(value: String) {
        debounceJob?.cancel()
        debounceJob = null
        query = value

        val normalized = value.trim()
        if (normalized.isEmpty()) {
            isDebouncing = false
            repository.clearSearch()
            return
        }

        // Flutter invalidates any older generation and enters its skeleton state synchronously in
        // the text-change callback, before the next frame can reuse the previous results.
        repository.invalidatePendingSearch()
        isDebouncing = true
        debounceJob = debounceScope.launch {
            delay(debounceMillis)
            // Start undispatched so repository.isSearching becomes true before isDebouncing is
            // cleared. The request itself is a sibling in the app-lived scope and survives this
            // route being popped, just like Flutter's unawaited store request.
            requestScope.launch(start = CoroutineStart.UNDISPATCHED) {
                repository.search(normalized)
            }
            isDebouncing = false
        }
    }

    fun showsLoading(state: BrowseSearchState): Boolean {
        val normalized = query.trim()
        return normalized.isNotEmpty() && (
            isDebouncing || state.isSearching || normalized != state.query.trim()
            )
    }

    /** Cancels only a timer that has not fired. Started repository requests intentionally survive. */
    fun dispose() {
        debounceJob?.cancel()
        debounceJob = null
    }
}
