# ``QueuesMongoDriver``

@Metadata {
    @TitleHeading("Package")
}

A driver for [Queues]. Uses [MongoKitten] to store job metadata in a MongoDB database.

[Queues]: https://github.com/vapor/queues
[MongoKitten]: https://github.com/OpenKitten/MongoKitten

## Overview

This package provides a MongoDB-based driver for Vapor's Queues system, allowing you to store and manage job metadata in a MongoDB database.

## Compatibility

This driver depends on [MongoKitten](https://github.com/OpenKitten/MongoKitten) and is compatible with:

- MongoDB 5.0+
- Vapor 4.x 
- Swift 5.9+

## Getting started

#### Adding the dependency

Add `queues-mongo-driver` as dependency to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/vapor-community/queues-mongo-driver.git", branch: "master")
]
```
Add `QueuesMongoDriver` to the target you want to use it in:
```swift
targets: [
    .target(
        name: "MyFancyTarget",
        dependencies: [
            .product(name: "QueuesMongoDriver", package: "queues-mongo-driver"),
            ...
        ]
    ),
]
```

### Configuration

To configure the MongoDB driver, you'll need a `MongoDatabase` instance:

```swift
let database = try await MongoDatabase.connect(to: "mongodb://localhost:27017/myapp")
```

Then, pass it to the `setupMongo` method on `Application.Queues`:

```swift
try await app.queues.setupMongo(using: database)
``` 

This will create the necessary indexes on the MongoDB collection used for storing queue jobs.   

## Options

### Job Preservation

By default, completed jobs are removed from the database. You can preserve completed jobs by setting the `preservesCompletedJobs` parameter:

```swift
app.queues.use(.mongodb(
    mongoDatabase,
    preservesCompletedJobs: true
))
``` 

### Custom Collection Name

By default, the driver uses the collection `vapor_queues`. You can specify a custom collection name using the `collectionName` parameter:

```swift
app.queues.use(.mongodb(
    mongoDatabase,
    collectionName: "my_custom_collection"
))
``` 

## Performance Considerations

The driver creates several indexes on the MongoDB collection to optimize performance. The driver creates two indexes to optimize job lookup and processing:

- `job_index` (unique) on `jobid`: This index prevents duplicate jobs from being added to the queue.
- `queue_index` (unique) on `queue`: This index allows for efficient queue-specific queries.