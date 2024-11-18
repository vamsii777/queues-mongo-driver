import struct Queues.JobIdentifier

enum QueuesMongoError: Error {
    /// The queues system attempted to act on a job identifier which could not be found.
    case missingJob(JobIdentifier)
}
