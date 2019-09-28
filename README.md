
# Multiplexer Utilities - *Work in progress*
### Async utilities with caching for Swift

#### Table of contents

- [Introduction](#intro)
- [Multiplexer](#multiplexer)
- [MultiplexerMap](#multiplexer-map)
- [Media downloaders](#media-downloaders)
- [MuxRepository](#mux-repository)
- [Authors](#authors)

<a name="intro"></a>
## 1. Introduction

The Swift Multiplexer utility suite provides a browser-like request/caching layer for network objects, all based on callbacks. Its interfaces are pretty straightforward and (hopefully) pretty well documented here and in the source files.

Here are the scenarios that are covered by the Multiplexer utilities:

**Scenario 1:** execute an async block, typically a network call, and return the result to one or more callers. Various parts of your app may be requesting e.g. the user's profile simultaneously at program startup; you want to make sure the network request is performed only once, then the result is returned to all parts of the app that requested the object. We call it **multiplexing** (not to be confused with multiplexing in networking).

Additionally, provide caching of the result in memory for a certain period of time. Subsequent calls to this multiplexer may return the cached result unless some time-to-live (TTL) elapses, in which case a new network call is made transparently.

This multiplexer can be configured to use disk caching in addition to memory caching. Another possibility is to have this multiplexer return a previously known result regardless of its TTL if the latest network call resulted in one of the specific types of failures, such as network connectivity errors.

Support "soft" and "hard" refreshes, like the browser's Cmd-R and related functions.

**Scenario 2:** have a dictionary of multiplexers that request and cache objects of the same type by their symbolic ID, e.g. user profiles.

**Scenario 3:** provide media file downloading, multiplexing and disk caching. In addition to disk caching, some limited number of media objects can be cached in memory for faster access.

**Scenario 4:** combine various multiplexers into a single async call; return the results to the caller when all of them are available. Useful when e.g. you need to combine different object types in a single UI element, such as a table, i.e. if the UI element can be displayed only when all of the network objects are available at once.

And some bonus utilities, such as the Debouncer.

<a name="multiplexer"></a>
## Multiplexer<T>

`Multiplexer<T>` is an asynchronous, callback-based caching facility for client apps. Each multiplxer instance can manage retrieval, multiplexing and caching of one object of type `T: Codable`, therefore it is best to define each multiplexer instance in your app as a singleton.

For each multiplexer singleton you define a block that implements asynchronous retrieval of the object, which in your app will likely be a network request to your backend system.

A multiplexer singleton guarantees that there will only be one fetch/retrieval operation made, and that subsequently a memory-cached object will be returned to the callers of its `request(...)` method , unless the cached object expires according to the `timeToLive` setting (defaults to 30 minutes). Additionally, Multiplexer can store the object on disk - see `flush()` and also the discussion on `request(refresh:completion:)`.

Suppose you have a `UserProfile` class and a method of retrieving the current user's profile object from the backend, whose signature looks like this:

```swift
class Backend {
	static func fetchMyProfile(completion: (Result<UserProfile, Error>) -> Void)
}
```

Then an instantiation of a multiplexer singleton will look like:

```swift
let myProfile = Multiplexer<UserProfile>(onFetch: { onResult in
	Backend.fetchMyProfile(onResult)
})
```

Or even shorter:

```swift
let myProfile = Multiplexer<UserProfile>(onFetch: Backend.fetchMyProfile)
```

To use `myProfile` to fetch the profile object, you call the `request(refresh:completion:)` method like so:

```swift
myProfile.request(refresh: false) { result in
	switch result {
	case .failure(let error)
		print("Error:", error)
	case .success(let profile)
		print("My profile:", profile)
	}
}
```

When called for the first time, `request(...)` calls your `onFetch` block, returns it to your completion block as `Result<T, Error>`, and also caches the result in memory. Subsequent calls to `request(...)` will return immediately with the stored object. The `refresh` parameter tells the multiplexer to try to retrieve the object again, similarly to the browser's Cmd-R function.

Most importantly, `request(...)` can handle multiple simultaneous calls and ensures only one `onFetch` operation is initiated at a time.

See also:

- `init(onFetch: @escaping (@escaping OnResult) -> Void)`
- `func request(refresh: Bool, completion: @escaping OnResult)`
- `MultiplexerMap`

### Caching

By default, `Multiplexer<T>` can store objects as JSON files in the local cache directory. This is done by explicitly calling `flush()` on the multiplexer object, or alternatively `flushAll()` on the global repository `MuxRepository` if the multiplexer object is registered there.

In the current implementation, the objects stored on disk can be reused only in one case: when your `onFetch` fails due to a connectivity problem. This behavior is defined in the `useCachedResultOn(error:)` class method that can be overridden in your subclass of `Multiplexer`. For the memory cache, the expiration logic is defined by the class variable `timeToLive`, which defaults to 30 minutes and can also be overridden in your subclass.

The storage method can be changed by defining a class that conforms to `Cacher`, possibly with a generic parameter for the basic object type. For example you can define your own cacher that uses CoreData, called `CDCacher<T>`, then define your new multiplexer class as:

```swift
typealias MyCDMultiplexer<T: Codable> = MultiplexerBase<T, CDCacher<T>>
```

At run time, you can invalidate the cached object using one of the following methods:

- "Soft refresh": use the `refresh` argument in your call to `request(refresh:completion:)`: the multiplexer will attempt to fetch the object again, but will not discard the existing cached objects in memory or on disk. In case of a failure the older cached object may be used again as a result.
- "Hard refresh": call `clear()` to discard both memory and disk caches for the given object. The next call to `request(...)` will attempt to fetch the object and will fail in case of an error.

See also:

- `flush()`
- `clear()`
- `MuxRepository`
- `Zipper`

More detailed descriptions on each method can be found in the source file [Multiplexer.swift](Multiplexer/Multiplexer.swift).

<a name="multiplexer-map"></a>
## MultiplexerMap<T>

`MultiplexerMap<T>` is similar to `Multiplexer<T>` in many ways except it maintains a dictionary of objects of the same type. One example would be e.g. user profile objects in your social app.

The hash key for the MultiplexerMap interface is not generic and is assumed to be `String`. This is because object ID's are mostly strings in modern backend systems, plus it simplifies the `Cacher`'s job of storing objects on disk or a database.

The examples given for the Multiplexer above will look as follows. Firstly, suppose you have a method for retrieving a user profile by a user ID:

```swift
class Backend {
	static func fetchUserProfile(id: String, completion: (Result<UserProfile, Error>) -> Void)
}
```

Further, the MultiplexerMap singleton can be defined as follows:

```swift
let userProfiles = MultiplexerMap<UserProfile>(onKeyFetch: Backend.fetchUserProfile)
```

And used in the app like so:

```swift
userProfiles.request(refresh: false, key: "user_8cJOiRXbugFccrUhmCX2") { result in
	switch result {
	case .failure(let error)
		print("Error:", error)
	case .success(let profile)
		print("My profile:", profile)
	}
}
```

Like Multiplexer, MultiplexerMap defines its own methods `clear()`, `flush()`, as well as the overridable  `useCachedResultOn(error:)` and `timeToLive` class entities.

An important thing to note is that internally MultiplexerMap maintains a map of Multiplexer objects, meaning that fetching and caching of each object by its ID is done independently.

See also:

- `init(onKeyFetch: @escaping (String, @escaping OnResult) -> Void)`
- `func request(refresh: Bool, key: String, completion: @escaping OnResult)`
- `flush()`
- `clear()`
- `Multiplexer<T>`
- `MuxRepository`
- `Zipper`

More detailed descriptions on each method can be found in the source file [MultiplexerMap.swift](Multiplexer/MultiplexerMap.swift).

<a name="media-downloaders"></a>
## Media downloaders

`ImageLoader` and `MediaLoader` are two multiplexing and caching interfaces designed specifically for media files used in your app. The difference between them is in that ImageLoader returns UIImage (or NSImage on macOS). Up to a certain number of UIImage/NSImage objects are cached in memory for faster access. By contrast, MediaLoader is for larger media files that are supposed to be streamed from a local file; therefore the result type returned by this interface is a path to a local cache file.

Both interfaces provide singleton objects called `main` that should be used in your app.

Examples:

```swift
let imageURL = "https://i.imgur.com/QXYqnI9.jpg"

ImageLoader.main.request(url: URL(string: imageURL)!) { result in
	self.imageView.image = try? result.get()
}

let audioURL = "https://freesound.org/people/mojuba/sounds/474800/download/474800__mojuba__sacre-cur-paris-ambient-sound.mp3"

MediaLoader.main.request(url: URL(string: audioURL)!) { result in
	switch result {
	case .failure(let error)
		print(error)
	case .success(let object):
		self.player = AVPlayer(url: object.fileURL)
		self.player.play()
	}
}
```

Like MultiplexerMap, the media loader interfaces ensure only one download process can be initiated at a time.

These two interfaces don't support "soft refresh" as it is assumed that media files are immutable, i.e. one URL can point to an object that never changes and therefore can be cached indefinitely.

In addition, both ImageLoader and MediaLoader can be added to the MuxRepository for `clearAll()` calls; both are also supported by the Zipper interface.

More information on each interface and their methods can be found in the source file [CachingLoader.swift](Multiplexer/CachingLoader.swift).

<a name="mux-repository"></a>
## MuxRepository

`MuxRepository` is a static interface that can be used for centralized operations such as `clearAll()` and `flushAll()` on all multiplexer/downloader instances in your app. You should register each instance using the `register()` method on each multiplexer or downloader instance. Note that MuxRepository retains the objects, which generally should not be a problem for singletons. Use `unregister()` in case you need to release an instance previously registered with the repository.

By default, the Multiplexer and MultiplexerMap interfaces don't store objects on disk. If you want to keep the objects to ensure they can survive app reboots, call `MuxRepository.flushAll()` in your app's `applicationWillResignActive(_:)` and `applicationWillTerminate(_:)` (both, because the former is not called in certain scenarios, such as a low battery shutdown). Make sure `flushAll()` is performed only once, since in some scenarios both - applicationWillTerminate and applicationWillResignActive - can be called by the system.

`MuxRepository.clearAll()` discards all memory and disk objects. This is useful when e.g. the user signs out of your system and you need to make sure no traces are left of data related to the given user in memory or disk.

Registration example:

```swift
let myProfile = Multiplexer<UserProfile>(onFetch: Backend.fetchMyProfile).register()
```

<a name="intro"></a>
## Authors

MuxUtils is developed by Hovik Melikyan. The source code is free to use, fork and modify; "free" as in "free as a bird".

---


*Documentation for Zipper and Debouncer are coming soon*
