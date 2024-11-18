import protocol Queues.QueuesDriver
import protocol Queues.Queue
import protocol Queues.AsyncQueue
import struct Queues.QueueContext
import struct Queues.JobIdentifier
import struct Queues.JobData
import MongoKitten

public struct MongoQueuesDriver: QueuesDriver {
    let database: MongoDatabase
    let preservesCompletedJobs: Bool
    let collectionName: String
    
    public init(
        database: MongoDatabase,
        preservesCompletedJobs: Bool = false,
        collectionName: String = "vapor_queues_jobs"
    ) {
        self.database = database
        self.preservesCompletedJobs = preservesCompletedJobs
        self.collectionName = collectionName
    }
    
    public func makeQueue(with context: QueueContext) -> any Queue {
        MongoQueue(
            context: context,
            collection: database[collectionName],
            preservesCompletedJobs: preservesCompletedJobs
        )
    }
    
    public func shutdown() {}
}

/*private*/ struct FailingQueue: AsyncQueue {
    let failure: any Error
    let context: QueueContext

    func get(_: JobIdentifier) async throws -> JobData   { throw self.failure }
    func set(_: JobIdentifier, to: JobData) async throws { throw self.failure }
    func clear(_: JobIdentifier) async throws            { throw self.failure }
    func push(_: JobIdentifier) async throws             { throw self.failure }
    func pop() async throws -> JobIdentifier?            { throw self.failure }
}
