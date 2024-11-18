import Queues
import MongoKitten
import Vapor

public struct MongoQueue: AsyncQueue, Sendable {
    
    public var context: QueueContext
    let collection: MongoCollection
    let preservesCompletedJobs: Bool
    
    public func get(_ id: JobIdentifier) async throws -> JobData {
        guard let job = try await collection.findOne(
            "id" == id.string &&
            "queueName" == context.queueName.string &&
            "state" == StoredJobState.processing.rawValue,
            as: MongoJob.self
        ) else {
            throw QueuesMongoError.missingJob(id)
        }
        
        return JobData(
            payload: [UInt8](job.payload),
            maxRetryCount: job.maxRetryCount,
            jobName: job.jobName,
            delayUntil: job.delayUntil,
            queuedAt: job.queuedAt,
            attempts: job.attempts
        )
    }
    
    public func set(_ id: JobIdentifier, to data: JobData) async throws {
        let job = MongoJob(id: id, queue: context.queueName, jobData: data)
        let document = try BSONEncoder().encode(job)
        try await collection.insert(document)
    }
    
    public func clear(_ id: JobIdentifier) async throws {
        
        let query: Document = [
            "id": id.string,
            "queueName": context.queueName.string,
            "state": StoredJobState.processing.rawValue
        ]

        if preservesCompletedJobs {
            _ = try await collection.findOneAndUpdate(
                where: query,
                to: [
                    "$set": [
                        "state": StoredJobState.completed.rawValue,
                        "updatedAt": Date()
                    ] as Document
                ]
            ).execute()
        } else {
            _ = try await collection.deleteOne(where: query)
        }
    }
    
    public func pop() async throws -> JobIdentifier? {
        
        let query = "queueName" == context.queueName.string &&
            "state" == StoredJobState.pending.rawValue &&
            ("delayUntil" == nil || "delayUntil" <= Date())
        
        let update: Document = [
            "$set": [
                "state": StoredJobState.processing.rawValue,
                "updatedAt": Date()
            ] as Document,
            "$inc": ["attempts": 1]
        ]

        let reply = try await collection.findAndModify(
            where: query,
            update: update
        )
        .sort(["queuedAt": .ascending])
        .execute()
        
        guard let document = reply.value else {
            return nil
        }
        
        guard let job = try? BSONDecoder().decode(MongoJob.self, from: document) else {
            return nil
        }
        
        return JobIdentifier(string: job.id)
    }
    
    public func push(_ id: JobIdentifier) async throws {

        let query = "id" == id.string &&
            "queueName" == context.queueName.string
        
        let update: Document = [
            "$set": [
                "state": StoredJobState.pending.rawValue,
                "updatedAt": Date()
            ] as Document,
            "$inc": ["attempts": 1]
        ]
        
        _ = try await collection.findOneAndUpdate(
            where: [query],
            to: update
        ).execute()
    }
}
