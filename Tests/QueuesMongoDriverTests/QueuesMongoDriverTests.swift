import Queues
import XCTVapor
import MongoKitten
@testable import QueuesMongoDriver

final class QueuesMongoDriverTests: XCTestCase {
    var app: Application!
    
    override func tearDown() async throws {
        try await app?.asyncShutdown()
        app = nil
    }
    
    private func withEachDatabase(
        preserveJobs: Bool = false,
        collectionName: String = "queues_jobs",
        _ closure: () async throws -> Void
    ) async throws {
        func run(_ url: String, _ dbName: String) async throws {
            self.app = try await Application.make(.testing)
            self.app.logger[metadataKey: "test-db"] = "\(dbName)"
            
            let mongoDatabase = try await MongoDatabase.connect(
                to: "\(url)/\(dbName)",
                logger: self.app.logger
            )
            
            try await app.queues.setupMongo(using: mongoDatabase)
            app.queues.use(.mongodb(
                mongoDatabase,
                preservesCompletedJobs: preserveJobs,
                collectionName: collectionName
            ))
            
            do { try await closure() }
            catch {
                try? await mongoDatabase[collectionName].drop()
                try? await app.asyncShutdown()
                self.app = nil
                throw error
            }
            
            try await mongoDatabase[collectionName].drop()
            try await app.asyncShutdown()
            self.app = nil
        }
        
        try await run("mongodb://localhost:27017", "queuesdriver_test")
    }
    
    func testApplication() async throws { try await self.withEachDatabase {
        let email = Email()
        
        self.app.queues.add(email)
        self.app.get("send-email") { req in
            try await req.queue.dispatch(Email.self, .init(to: "vamsi@vapor.codes"))
            return HTTPStatus.ok
        }
        
        try await self.app.testable().test(.GET, "send-email") { res async in
            XCTAssertEqual(res.status, .ok)
        }
        
        await XCTAssertEqualAsync(await email.sent, [])
        try await self.app.queues.queue.worker.run().get()
        await XCTAssertEqualAsync(await email.sent, [.init(to: "vamsi@vapor.codes")])
    } }
    
    
    func testFailedJobLoss() async throws { try await self.withEachDatabase {
        let jobID = JobIdentifier()
        
        self.app.queues.add(FailingJob())
        self.app.get("test") { req in
            try await req.queue.dispatch(FailingJob.self, ["foo": "bar"], id: jobID)
            return HTTPStatus.ok
        }
        
        try await self.app.testable().test(.GET, "test") { res async in
            XCTAssertEqual(res.status, .ok)
        }
        
        await XCTAssertThrowsErrorAsync(try await self.app.queues.queue.worker.run().get()) {
            XCTAssert($0 is FailingJob.Failure)
        }
        
        // Verify the failed job still exists in MongoDB
        guard let queue = self.app.queues.queue as? MongoQueue else {
            XCTFail("Queue is not a MongoQueue")
            return
        }
        
        let failedJob = try await queue.collection.findOne(
            "id" == jobID.string &&
            "queueName" == queue.context.queueName.string &&
            "state" == StoredJobState.processing.rawValue,
            as: MongoJob.self
        )
        
        XCTAssertNotNil(failedJob, "Failed job should still exist in database")
    } }
    
    func testDelayedJobIsRemovedFromProcessingQueue() async throws { try await self.withEachDatabase {
        let jobID = JobIdentifier()
        
        self.app.queues.add(DelayedJob())
        self.app.get("delay-job") { req in
            try await req.queue.dispatch(DelayedJob.self, .init(name: "vapor"), delayUntil: .init(timeIntervalSinceNow: 3600.0), id: jobID)
            return HTTPStatus.ok
        }
        
        try await self.app.testable().test(.GET, "delay-job") { res async in
            XCTAssertEqual(res.status, .ok)
        }
        
        // Verify the delayed job is in pending state
        guard let queue = self.app.queues.queue as? MongoQueue else {
            XCTFail("Queue is not a MongoQueue")
            return
        }
        
        let delayedJob = try await queue.collection.findOne(
            "id" == jobID.string &&
            "queueName" == queue.context.queueName.string &&
            "state" == StoredJobState.pending.rawValue,
            as: MongoJob.self
        )
        
        XCTAssertNotNil(delayedJob, "Delayed job should exist in pending state")
    } }
    
    func testJobPreservation() async throws { try await self.withEachDatabase(preserveJobs: true) {
        let email = Email()
        
        self.app.queues.add(email)
        self.app.get("send-email") { req in
            try await req.queue.dispatch(Email.self, .init(to: "vamsi@vapor.codes"))
            return HTTPStatus.ok
        }
        
        try await self.app.testable().test(.GET, "send-email") { res async in
            XCTAssertEqual(res.status, .ok)
        }
        
        await XCTAssertEqualAsync(await email.sent, [])
        try await self.app.queues.queue.worker.run().get()
        await XCTAssertEqualAsync(await email.sent, [.init(to: "vamsi@vapor.codes")])
        
        // Verify job is preserved in MongoDB
        guard let queue = self.app.queues.queue as? MongoQueue else {
            XCTFail("Queue is not a MongoQueue")
            return
        }
        
        let jobCount = try await queue.collection.count(
            "queueName" == queue.context.queueName.string &&
            "state" == StoredJobState.completed.rawValue
        )
        
        XCTAssertEqual(jobCount, 1, "Completed job should be preserved in the database")
    } }
    
    func testCoverageForFailingQueue() async throws {
        self.app = try await Application.make(.testing)
        let queue = FailingQueue(
            failure: QueuesMongoError.missingJob(JobIdentifier()),
            context: .init(queueName: .default, configuration: .init(), application: self.app, logger: self.app.logger, on: self.app.eventLoopGroup.any())
        )
        await XCTAssertThrowsErrorAsync(try await queue.get(.init()))
        await XCTAssertThrowsErrorAsync(try await queue.set(.init(), to: JobData(payload: [], maxRetryCount: 0, jobName: "", delayUntil: nil, queuedAt: .init())))
        await XCTAssertThrowsErrorAsync(try await queue.clear(.init()))
        await XCTAssertThrowsErrorAsync(try await queue.push(.init()))
        await XCTAssertThrowsErrorAsync(try await queue.pop())
        try await self.app.asyncShutdown()
        self.app = nil
    }
    
    func testCoverageForJobModel() {
        let date = Date()
        let model = MongoJob(id: .init(string: "test"), queue: .init(string: "test"), jobData: .init(payload: [], maxRetryCount: 0, jobName: "", delayUntil: nil, queuedAt: date))
        
        XCTAssertEqual(model.id, "test")
        XCTAssertEqual(model.queueName, "test")
        XCTAssertEqual(model.jobName, "")
        XCTAssertEqual(model.queuedAt, date)
        XCTAssertNil(model.delayUntil)
        XCTAssertEqual(model.state, .pending)
        XCTAssertEqual(model.maxRetryCount, 0)
        XCTAssertEqual(model.attempts, 0)
        XCTAssertEqual(model.payload, Data())
        XCTAssertNotNil(model.updatedAt)
    }
    
    actor Email: AsyncJob {
        struct Message: Codable, Equatable {
            let to: String
        }
        
        var sent: [Message] = []
        
        func dequeue(_ context: QueueContext, _ message: Message) async throws {
            self.sent.append(message)
            context.logger.info("sending email", metadata: ["message": "\(message)"])
        }
    }
    
    struct DelayedJob: AsyncJob {
        struct Message: Codable, Equatable {
            let name: String
        }
        
        func dequeue(_ context: QueueContext, _ message: Message) async throws {
            context.logger.info("Hello", metadata: ["name": "\(message.name)"])
        }
    }
    
    struct FailingJob: AsyncJob {
        struct Failure: Error {}
        
        func dequeue(_ context: QueueContext, _ message: [String: String]) async throws { throw Failure() }
        func error(_ context: QueueContext, _ error: any Error, _ payload: [String: String]) async throws { throw Failure() }
    }
    
    func XCTAssertEqualAsync<T>(
        _ expression1: @autoclosure () async throws -> T,
        _ expression2: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath, line: UInt = #line
    ) async where T: Equatable {
        do {
            let expr1 = try await expression1(), expr2 = try await expression2()
            return XCTAssertEqual(expr1, expr2, message(), file: file, line: line)
        } catch {
            return XCTAssertEqual(try { () -> Bool in throw error }(), false, message(), file: file, line: line)
        }
    }
    
    func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath, line: UInt = #line,
        _ callback: (any Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTAssertThrowsError({}(), message(), file: file, line: line, callback)
        } catch {
            XCTAssertThrowsError(try { throw error }(), message(), file: file, line: line, callback)
        }
    }
    
    func XCTAssertNoThrowAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath, line: UInt = #line
    ) async {
        do {
            _ = try await expression()
        } catch {
            XCTAssertNoThrow(try { throw error }(), message(), file: file, line: line)
        }
    }
    
    func XCTAssertNotNilAsync(
        _ expression: @autoclosure () async throws -> Any?,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath, line: UInt = #line
    ) async {
        do {
            let result = try await expression()
            XCTAssertNotNil(result, message(), file: file, line: line)
        } catch {
            return XCTAssertNotNil(try { throw error }(), message(), file: file, line: line)
        }
    }
}
