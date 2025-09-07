import gleam/uri.{type Uri}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import sb/frontend/pages/designer
import sb/frontend/pages/help
import sb/frontend/pages/job
import sb/frontend/pages/jobs
import sb/frontend/pages/task
import sb/frontend/pages/tasks

pub opaque type Model {
  Tasks(tasks.Model)
  Task(task.Model)
  Designer(designer.Model)

  Jobs(jobs.Model)
  Job(job.Model)

  Help(help.Model)

  NotFound(Uri)
}

pub type Message {
  TasksMessage(tasks.Message)
  TaskMessage(task.Message)
  DesignerMessage(designer.Message)

  JobsMessage(jobs.Message)
  JobMessage(job.Message)

  HelpMessage(help.Message)
}

pub fn init(uri: Uri) -> #(Model, Effect(Message)) {
  case uri.path_segments(uri.path) {
    ["oppgaver"] -> {
      let #(model, effect) = tasks.init(uri)
      #(Tasks(model), effect.map(effect, TasksMessage))
    }

    ["oppgave", task_id] -> {
      let #(model, effect) = task.init(task_id)
      #(Task(model), effect.map(effect, TaskMessage))
    }

    ["designer"] -> {
      let #(model, effect) = designer.init()
      #(Designer(model), effect.map(effect, DesignerMessage))
    }

    ["jobber"] -> {
      let #(model, effect) = jobs.init(uri)
      #(Jobs(model), effect.map(effect, JobsMessage))
    }

    ["jobb", job_id] -> {
      let #(model, effect) = job.init(job_id)
      #(Job(model), effect.map(effect, JobMessage))
    }

    ["hjelp"] -> {
      let #(model, effect) = help.init()
      #(Help(model), effect.map(effect, HelpMessage))
    }

    _else -> #(NotFound(uri), effect.none())
  }
}

pub fn update(model: Model, message: Message) {
  case model, message {
    Tasks(model), TasksMessage(message) -> {
      let #(model, effect) = tasks.update(model, message)
      #(Tasks(model), effect.map(effect, TasksMessage))
    }

    Tasks(..), _message -> #(model, effect.none())

    Task(model), TaskMessage(message) -> {
      let #(model, effect) = task.update(model, message)
      #(Task(model), effect.map(effect, TaskMessage))
    }

    Task(..), _message -> #(model, effect.none())

    Designer(model), DesignerMessage(message) -> {
      let #(model, effect) = designer.update(model, message)
      #(Designer(model), effect.map(effect, DesignerMessage))
    }

    Designer(..), _message -> #(model, effect.none())

    Jobs(model), JobsMessage(message) -> {
      let #(model, effect) = jobs.update(model, message)
      #(Jobs(model), effect.map(effect, JobsMessage))
    }

    Jobs(..), _message -> #(model, effect.none())

    Job(model), JobMessage(message) -> {
      let #(model, effect) = job.update(model, message)
      #(Job(model), effect.map(effect, JobMessage))
    }

    Job(..), _message -> #(model, effect.none())

    Help(model), HelpMessage(message) -> {
      let #(model, effect) = help.update(model, message)
      #(Help(model), effect.map(effect, HelpMessage))
    }

    Help(..), _message -> #(model, effect.none())

    NotFound(..), _message -> #(model, effect.none())
  }
}

pub fn view(model: Model, uri: Uri) -> Element(Message) {
  case model {
    Tasks(model) ->
      tasks.view(model, uri)
      |> element.map(TasksMessage)

    Task(model) ->
      task.view(model)
      |> element.map(TaskMessage)

    Designer(model) ->
      designer.view(model)
      |> element.map(DesignerMessage)

    Jobs(model) ->
      jobs.view(model)
      |> element.map(JobsMessage)

    Job(model) ->
      job.view(model)
      |> element.map(JobMessage)

    Help(model) ->
      help.view(model)
      |> element.map(HelpMessage)

    NotFound(_uri) -> element.none()
  }
}
