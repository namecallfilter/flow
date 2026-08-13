package com.namecallfilter.flow.data

/** Raw operation text kept in-app so the native client has no generated Dart dependency. */
internal object TwitchGraphQlDocuments {
    val currentUser = """
        query FlowCurrentUser {
          currentUser { id login displayName profileImageURL(width: 300) }
        }
    """.trimIndent()

    val followedLiveUsers = """
        query FlowFollowedLiveUsers(${D}first: Int, ${D}after: Cursor) {
          currentUser {
            followedLiveUsers(first: ${D}first, after: ${D}after) {
              edges {
                cursor
                node {
                  id login displayName profileImageURL(width: 300)
                  stream {
                    id createdAt freeformTags { name }
                    game { id displayName }
                    previewImageURL viewersCount
                    broadcaster { broadcastSettings { title } }
                  }
                }
              }
              pageInfo { hasNextPage }
            }
          }
        }
    """.trimIndent()

    val followedUsers = """
        query FlowFollowedUsers(${D}first: Int, ${D}after: Cursor) {
          currentUser {
            follows(first: ${D}first, after: ${D}after, order: ASC) {
              edges {
                cursor followedAt
                node { id login displayName profileImageURL(width: 300) }
              }
              pageInfo { hasNextPage }
            }
          }
        }
    """.trimIndent()

    val users = """
        query FlowUsers(${D}ids: [ID!], ${D}logins: [String!]) {
          users(ids: ${D}ids, logins: ${D}logins) {
            id login displayName profileImageURL(width: 300)
            broadcastSettings { title game { id displayName } }
            stream {
              id createdAt freeformTags { name }
              game { id displayName }
              previewImageURL viewersCount
              broadcaster { broadcastSettings { title } }
            }
          }
        }
    """.trimIndent()

    val topGames = """
        query FlowTopGames(${D}first: Int, ${D}after: Cursor) {
          games(first: ${D}first, after: ${D}after) {
            edges { cursor node { id displayName boxArtURL viewersCount } }
            pageInfo { hasNextPage }
          }
        }
    """.trimIndent()

    val topStreams = """
        query FlowTopStreams(${D}first: Int, ${D}after: Cursor) {
          streams(first: ${D}first, after: ${D}after) {
            edges {
              cursor
              node {
                id
                broadcaster {
                  id login displayName profileImageURL(width: 300)
                  broadcastSettings { title }
                }
                createdAt freeformTags { name }
                game { id displayName }
                previewImageURL viewersCount
              }
            }
            pageInfo { hasNextPage }
          }
        }
    """.trimIndent()

    val searchCategories = """
        query FlowSearchCategories(${D}query: String!, ${D}first: Int, ${D}after: Cursor) {
          searchCategories(query: ${D}query, first: ${D}first, after: ${D}after) {
            edges { cursor node { id displayName boxArtURL viewersCount } }
            pageInfo { hasNextPage }
          }
        }
    """.trimIndent()

    val searchChannels = """
        query FlowSearchChannels(
          ${D}queryFragment: String!
          ${D}requestID: ID
          ${D}withOfflineChannelContent: Boolean
        ) {
          searchSuggestions(
            queryFragment: ${D}queryFragment
            requestID: ${D}requestID
            withOfflineChannelContent: ${D}withOfflineChannelContent
          ) {
            edges {
              node {
                content {
                  __typename
                  ... on SearchSuggestionChannel {
                    id isLive isVerified login profileImageURL(width: 50)
                    user {
                      id
                      stream {
                        id viewersCount createdAt game { id displayName }
                        broadcaster { id broadcastSettings { id title } }
                      }
                    }
                  }
                }
                id text
              }
            }
          }
        }
    """.trimIndent()

    val gameStreams = """
        query FlowGameStreams(${D}id: ID, ${D}first: Int, ${D}after: Cursor) {
          game(id: ${D}id) {
            streams(first: ${D}first, after: ${D}after) {
              edges {
                cursor
                node {
                  id
                  broadcaster {
                    id login displayName profileImageURL(width: 300)
                    broadcastSettings { title }
                  }
                  createdAt freeformTags { name }
                  game { id displayName }
                  previewImageURL viewersCount
                }
              }
              pageInfo { hasNextPage }
            }
          }
        }
    """.trimIndent()

    val channelDetails = """
        query FlowChannelDetails(${D}login: String!, ${D}videosFirst: Int, ${D}videosAfter: Cursor) {
          user(login: ${D}login) {
            id login displayName description profileImageURL(width: 300)
            followers { totalCount }
            stream {
              id createdAt game { id displayName name }
              previewImageURL(width: 320, height: 180) viewersCount
              broadcaster { broadcastSettings { title } }
            }
            videos(first: ${D}videosFirst, after: ${D}videosAfter, sort: TIME, type: ARCHIVE) {
              edges {
                cursor
                node {
                  id title game { id displayName name } lengthSeconds
                  previewThumbnailURL(width: 320, height: 180)
                  publishedAt createdAt viewCount
                }
              }
              pageInfo { hasNextPage }
            }
          }
        }
    """.trimIndent()

    val playbackAccessToken = """
        query FlowPlaybackAccessToken(${D}login: String!, ${D}platform: String!, ${D}playerType: String!) {
          streamPlaybackAccessToken(
            channelName: ${D}login
            params: { platform: ${D}platform playerBackend: "mediaplayer" playerType: ${D}playerType }
          ) {
            value signature authorization { isForbidden forbiddenReasonCode }
          }
        }
    """.trimIndent()

    val channelSubscription = """
        query FlowChannelSubscription(${D}login: String!) {
          user(login: ${D}login) { self { subscriptionBenefit { id } } }
        }
    """.trimIndent()

    private const val D = '$'
}
