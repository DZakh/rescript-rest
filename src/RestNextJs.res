@@uncurried

open RescriptSchema

module Promise = {
  type t<+'a> = promise<'a>

  @new
  external make: (('a => unit, Js.Exn.t => unit) => unit) => t<'a> = "Promise"
}

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

type apiConfig = {
  bodyParser?: bool,
  externalResolver?: bool,
  responseLimit?: bool,
}
type config = {maxDuration?: int, api?: apiConfig}

type options<'input> = {
  input: 'input,
  req: req,
  res: res,
}

let handler = (route, implementation) => {
  let {pathItems, path, method, isRawBody, outputSchema, inputSchema} = route->Rest.params

  // TODO: Validate that we match the req path
  pathItems->Js.Array2.forEach(pathItem => {
    switch pathItem {
    | Param(param) =>
      panic(
        `Route ${path} contains a path param ${param.name} which is not supported by Next.js handler yet`,
      )
    | Static(_) => ()
    }
  })

  async (req, res) => {
    if req.method !== method {
      res.status(404).end()
    } else {
      if req.body === %raw(`undefined`) {
        let rawBody = ref("")
        let _ = await Promise.make((resolve, reject) => {
          let _ = (req->Obj.magic)["on"]("data", chunk => {
            rawBody := rawBody.contents ++ chunk
          })
          let _ = (req->Obj.magic)["on"]("end", resolve)
          let _ = (req->Obj.magic)["on"]("error", reject)
        })
        (req->Obj.magic)["body"] = isRawBody
          ? rawBody.contents->Obj.magic
          : Js.Json.parseExn(rawBody.contents)
      } else if isRawBody {
        Js.Exn.raiseError(
          "Routes with Raw Body require to disable body parser for your handler. Add `let config: RestNextJs.config = {api: {bodyParser: false}}` to the file with your handler to make it work.",
        )
      }

      switch req->S.parseOrThrow(inputSchema) {
      | input =>
        try {
          let implementationResult = await implementation({
            req,
            res,
            input,
          })
          let data: {..} = implementationResult->S.reverseConvertOrThrow(outputSchema)->Obj.magic
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
          Js.Exn.raiseError(`Unexpected error in the ${path} route: ${error->S.Error.message}`)
        }
      | exception S.Raised(error) =>
        res.status(400).json({"error": error->S.Error.message->Js.Json.string}->Obj.magic)
      }
    }
  }
}
