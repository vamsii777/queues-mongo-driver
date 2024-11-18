import Queues
import MongoKitten
import Vapor

extension Application.Queues {
    /// Sets up MongoDB indexes for optimizing queues performance and data management.
    ///
    /// This function creates indexes on the MongoDB collection used for storing queue jobs:
    /// - A unique index on job IDs to prevent duplicates
    /// - A unique index on queue names for efficient queue-specific queries
    ///
    /// Example usage:
    /// ```swift
    /// let database = try await MongoDatabase.connect(to: "mongodb://localhost:27017/myapp")
    /// try await app.queues.setupMongo(using: database)
    /// ```
    ///
    /// - Parameter database: The MongoDB database connection to use for creating indexes
    /// - Throws: An error if index creation fails
    public func setupMongo(using database: MongoDatabase) async throws {
        let collection = database["vapor_queues"]
        
        try await collection.buildIndexes {
            UniqueIndex(
                named: "job_index",
                field: "jobid"
            )
            
            UniqueIndex(
                named: "queue_index",
                field: "queue"
            )
        }
    }
}
