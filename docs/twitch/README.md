# Twitch GraphQL references

`graphql/` preserves the reference queries, mutations, and fragments previously
stored under `lib/graphql/docs/`. They are searchable examples, not app assets
or inputs to code generation. Their original collection date is not recorded.

When adding a feature:

1. Search these documents for the relevant fields and follow their fragments.
2. Validate the operation and required authentication against Twitch.
3. Add only the operation Flow needs under `lib/graphql/`, updating the inferred
   `lib/graphql/schema.graphqls` when necessary.
4. Run `dart run build_runner build` and test the API mapping and feature.

Keep newly verified findings and their verification date with the relevant
reference. Saved documents can become stale as Twitch changes its API.
