import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import sb/forms/task.{type Task}

pub type Job {
  Requested(requested: RequestedJob)
  Started(requested: RequestedJob, started: StartedJob)
  Finished(requested: RequestedJob, started: StartedJob, finished: FinishedJob)
}

pub fn task(job: Job) -> Task {
  job.requested.task
}

pub type RequestedJob {
  RequestedJob(id: String, task: Task, time: Timestamp)
}

pub type StartedJob {
  StartedJob(
    requested: RequestedJob,
    time: Timestamp,
    approved_by: Option(String),
    started_by: String,
  )
}

pub type FinishedJob {
  Succeeded(started: StartedJob, time: Timestamp)

  Failed(
    started: StartedJob,
    time: Timestamp,
    exit_status: Int,
    error_message: String,
  )
}
