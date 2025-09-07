import gleam/uri.{type Uri}
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import modem
import sb/frontend/components/header
import sb/frontend/pages

pub opaque type Model {
  Model(uri: Uri, page: pages.Model)
}

pub opaque type Message {
  UriChanged(Uri)
  PageMessage(pages.Message)
}

pub fn new() -> lustre.App(Uri, Model, Message) {
  lustre.application(init, update, view)
}

fn init(uri: Uri) -> #(Model, Effect(Message)) {
  let #(page, page_effect) = {
    let #(model, effect) = pages.init(uri)
    #(model, effect.map(effect, PageMessage))
  }

  let effects = effect.batch([modem.init(UriChanged), page_effect])
  #(Model(uri:, page:), effects)
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    UriChanged(uri) -> {
      case uri.path == model.uri.path {
        True -> #(Model(..model, uri:), effect.none())

        False -> {
          let #(page, page_effect) = {
            let #(model, effect) = pages.init(uri)
            #(model, effect.map(effect, PageMessage))
          }

          #(Model(uri:, page:), page_effect)
        }
      }
    }

    PageMessage(message) -> {
      let #(page, page_effect) = {
        let #(model, effect) = pages.update(model.page, message)
        #(model, effect.map(effect, PageMessage))
      }

      #(Model(..model, page:), page_effect)
    }
  }
}

fn view(model: Model) -> Element(Message) {
  element.fragment([
    header.view(),
    pages.view(model.page, model.uri)
      |> element.map(PageMessage),
  ])
}
