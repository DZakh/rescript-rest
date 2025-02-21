@@uncurried

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

let handler: (
  Rest.route<'input, 'response>,
  options<'input> => promise<'response>,
) => (req, res) => promise<reply>
