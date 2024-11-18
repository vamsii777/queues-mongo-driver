import class Vapor.Application
import Queues
import MongoKitten

extension Application.Queues.Provider {
    /// Retrieve a queues provider which specifies use of the MongoDB driver with a given database.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// func configure(_ app: Application) async throws {
    ///     // ...
    ///     app.databases.use(.mongo(connectionString: "mongodb://localhost:27017/myapp"), as: .mongo)
    ///     app.queues.use(.mongodb(database))
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - database: A MongoDB database connection to use for job storage.
    ///   - preservesCompletedJobs: Defaults to `false`. If `true`, completed jobs are marked with a completed
    ///     state rather than being removed from the database.
    ///   - collectionName: The name of the MongoDB collection in which jobs data is stored. Defaults to `queues_jobs`.
    /// - Returns: An appropriately configured provider for `Application.Queues.use(_:)`.
    public static func mongodb(
        _ database: MongoDatabase,
        preservesCompletedJobs: Bool = false,
        collectionName: String = "vapor_queues_jobs"
    ) -> Self {
        .init {
            $0.queues.use(custom: MongoQueuesDriver(
                database: database,
                preservesCompletedJobs: preservesCompletedJobs,
                collectionName: collectionName
            ))
        }
    }
}
