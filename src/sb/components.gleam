import gleam/erlang/process
import gleam/otp/factory_supervisor as factory
import gleam/otp/static_supervisor.{type Supervisor} as supervisor
import gleam/otp/supervision.{type ChildSpecification}
import lustre
import lustre/effect
import sb/extra/function.{nil, return}
import sb/extra/reader
import sb/extra_server
import sb/forms/evaluate
import sb/forms/handlers.{type Handlers}
import sb/forms/task
import sb/frontend/components/errors as errors_component
import sb/frontend/components/task as task_component
import sb/frontend/components/tasks as tasks_component
import sb/store

pub type Component(argument, message) =
  process.Name(
    factory.Message(argument, process.Subject(lustre.RuntimeMessage(message))),
  )

pub type Components {
  Components(
    tasks: Component(Nil, tasks_component.Message),
    errors: Component(Nil, errors_component.Message),
    task: Component(Nil, task_component.Message),
  )
}

pub fn supervised(
  components components: Components,
  store store: process.Subject(store.Message),
  store_interval store_interval: Int,
  handlers handlers: Handlers,
) -> ChildSpecification(Supervisor) {
  let tasks_spec =
    tasks_component(store:, store_interval:)
    |> lustre.factory
    |> factory.named(components.tasks)
    |> factory.supervised

  let errors_spec =
    errors_component(store:, store_interval:)
    |> lustre.factory
    |> factory.named(components.errors)
    |> factory.supervised

  let task_spec =
    task_component(store:, handlers:)
    |> lustre.factory
    |> factory.named(components.task)
    |> factory.supervised

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(tasks_spec)
  |> supervisor.add(errors_spec)
  |> supervisor.add(task_spec)
  |> supervisor.supervised
}

fn tasks_component(
  store store: process.Subject(store.Message),
  store_interval store_interval: Int,
) -> lustre.App(Nil, tasks_component.Model, tasks_component.Message) {
  tasks_component.app(
    schedule: extra_server.schedule(store_interval, _),
    load: fn(message: tasks_component.LoadMessage) {
      use dispatch <- effect.from
      let tasks = store.get_tasks(store)
      dispatch(message(tasks))
    },
  )
}

fn errors_component(
  store store: process.Subject(store.Message),
  store_interval store_interval: Int,
) -> lustre.App(Nil, errors_component.Model, errors_component.Message) {
  errors_component.app(
    schedule: extra_server.schedule(store_interval, _),
    load: fn(message: errors_component.LoadMessage) {
      use dispatch <- effect.from
      let reports = store.get_reports(store)
      dispatch(message(reports))
    },
  )
}

fn task_component(
  store store: process.Subject(store.Message),
  handlers handlers: Handlers,
) -> lustre.App(Nil, task_component.Model, task_component.Message) {
  task_component.app(
    schedule: extra_server.schedule,
    load: fn(task_id, message: task_component.LoadMessage) {
      use dispatch <- effect.from
      let task = store.get_task(store, task_id)
      dispatch(message(task))
    },
    // TODO: Avbryte ved reload/navigering
    step: fn(task, scope, search, message: task_component.StepMessage) {
      use dispatch <- effect.from
      use <- return(nil)
      use <- process.spawn_unlinked

      let #(task, scope) =
        task.commands
        |> evaluate.Context(scope:, search:, handlers:, task_commands: _)
        |> reader.run(context: _, reader: task.step(task))

      dispatch(message(task, scope))
    },
  )
}
