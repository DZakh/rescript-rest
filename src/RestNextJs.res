@@uncurried

open RescriptSchema

module Exn = {
  type error

  @new
  external makeError: string => error = "Error"

  let raiseAny = (any: 'any): 'a => any->Obj.magic->raise

  let raiseError: error => 'a = raiseAny
}

@inline
let panic = message => Exn.raiseError(Exn.makeError(`[rescript-rest] ${message}`))

type req = private {
  cookies: Js.Dict.t<string>,
  method: Rest.method,
  url: string,
  port: int,
  body: Js.Json.t,
  query: Js.Json.t,
  headers: Js.Dict.t<string>,
  rawHeaders: array<string>,
  rawTrailers: array<string>,
  aborted: bool,
  complete: bool,
  statusCode: Rest.Response.numiricStatus,
  statusMessage: string,
  trailers: Js.Dict.t<string>,
}
// @send
// external destroy: (req, ~error: option<Js.Exn.t>=?) => bool = "destroy"

type reply
type rec res = private {
  statusCode: Rest.Response.numiricStatus,
  statusMessage: string,
  getHeader: string => option<string>,
  setHeader: (string, string) => unit,
  status: int => res,
  end: unit => reply,
  json: Js.Json.t => reply,
  // The type is not 100% correct.
  // It asccepts a string, object or a Buffer
  send: Js.Json.t => reply,
}

type options<'input> = {
  input: 'input,
  req: req,
  res: res,
}

let handler = (route, implementation) => {
  let {pathItems, definition, isRawBody, responseSchema, inputSchema} = route->Rest.params

  // TOD: Validate that we match the req path
  pathItems->Js.Array2.forEach(pathItem => {
    switch pathItem {
    | Param(param) =>
      panic(
        `Route ${definition.path} contains a path param ${param.name} which is not supported by Next.js handler yet`,
      )
    | Static(_) => ()
    }
  })
  if isRawBody {
    panic(
      `Route ${definition.path} contains a raw body which is not supported by Next.js handler yet`,
    )
  }

  async (req, res) => {
    if req.method !== definition.method {
      res.status(404).end()
    } else {
      switch req->S.parseOrThrow(inputSchema) {
      | input =>
        try {
          let implementationResult = await implementation({
            req,
            res,
            input,
          })
          let data: {..} = implementationResult->S.reverseConvertOrThrow(responseSchema)->Obj.magic
          let headers: option<dict<string>> = data["headers"]
          switch headers {
          | Some(headers) =>
            headers
            ->Js.Dict.keys
            ->Js.Array2.forEach(key => {
              res.setHeader(key, headers->Js.Dict.unsafeGet(key))
            })
          | None => ()
          }
          res.status(%raw(`data.status || 200`)).json(data["data"])
        } catch {
        | S.Raised(error) =>
          Js.Exn.raiseError(
            `Unexpected error in the ${definition.path} route: ${error->S.Error.message}`,
          )
        }
      | exception S.Raised(error) => res.status(400).send(error->S.Error.message->Js.Json.string)
      }
    }
  }
}
