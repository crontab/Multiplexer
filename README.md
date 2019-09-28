
# Multiplexer Utilities
## Async utilities with caching for Swift 5.1+. Work in progress.

The Swift Multiplexer utility suite provides a browser-like request/caching layer for network objects, all based on callbacks. Its implementation is pretty straightforward and (hopefully) pretty well documented here and in the source files.

Most importantly, you will be surprised how simple Multiplexer's interfaces are. No, probably even simpler than you think.

Firstly, let's see what scenarios are covered by the Multiplexer utilities:

**Scenario 1:** execute an async block, typically a network call, and return the result to one or more callers. Various parts of your app may be requesting e.g. the user's profile simultaneously at program startup; you want to make sure the network request is performed only once, then return the result to all parts of the app that requested the object.

Additionally, provide caching of the result in memory for a certain period of time. Subsequent calls to this multiplexer may return the cached result unless some time-to-live expires, in which case a new network call is made transparently.

This multiplexer can be configured to use disk caching in addition to memory caching. Another possibility is to have this multiplexer return a previously known result regardless of its TTL if the latest network call resulted in one of a specific types of errors, such as network connectivity/reachability.

Support "soft" and "hard" refreshes, like the browser's Cmd-R and related functions.

**Scenario 2:** have a dictionary of multiplexers that request and cache objects of the same type by their symbolic ID, e.g. user profiles.

**Scenario 3:** combine various multiplexers into a single async call; return the results to the caller when all of them are available. Useful when e.g. you need to combine different object types in a single UI element, such as a table, i.e. if the UI element can be displayed only when all of the network objects are available at once.

And some bonus utilities, such as a debouncer.

*More detailed description of the interfaces coming soon*
