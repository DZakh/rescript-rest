open RescriptSchema

module Promise = {
  type t<+'a> = promise<'a>

  @send
  external thenResolve: (t<'a>, 'a => 'b) => t<'b> = "then"
}

type t

type abortSignal

type listenOptions = {
  /**
   * Default to `0` (picks the first available open port).
   */
  port?: int,
  /**
   * Default to `localhost`.
   */
  host?: string,
  /**
   * Will be ignored if `port` is specified.
   * @see [Identifying paths for IPC connections](https://nodejs.org/api/net.html#identifying-paths-for-ipc-connections).
   */
  path?: string,
  /**
   * Specify the maximum length of the queue of pending connections.
   * The actual length will be determined by the OS through sysctl settings such as `tcp_max_syn_backlog` and `somaxconn` on Linux.
   * Default to `511`.
   */
  backlog?: int,
  /**
   * Default to `false`.
   */
  exclusive?: bool,
  /**
   * For IPC servers makes the pipe readable for all users.
   * Default to `false`.
   */
  readableAll?: bool,
  /**
   * For IPC servers makes the pipe writable for all users.
   * Default to `false`.
   */
  writableAll?: bool,
  /**
   * For TCP servers, setting `ipv6Only` to `true` will disable dual-stack support, i.e., binding to host `::` won't make `0.0.0.0` be bound.
   * Default to `false`.
   */
  ipv6Only?: bool,
  /**
   * An AbortSignal that may be used to close a listening server.
   * @since This option is available only in Node.js v15.6.0 and greater
   */
  signal?: abortSignal,
  /**
   * Function that resolves text to log after server has been successfully started
   * @param address
   */
  listenTextResolver?: (~address: string) => string,
}

type injectOptionsSimulate = {
  end: bool,
  split: bool,
  error: bool,
  close: bool,
}

type injectOptions = {
  url?: string,
  path?: string,
  headers?: unknown,
  query?: string,
  simulate?: injectOptionsSimulate,
  authority?: string,
  remoteAddress?: string,
  method?: string,
  validate?: bool,
  payload?: unknown,
  body?: unknown,
  server?: unknown,
  autoStart?: bool,
  cookies?: dict<string>,
  signal?: unknown,
  @as("Request")
  request?: unknown,
}

type injectResponse = {
  raw: unknown,
  rawPayload: unknown,
  headers: unknown,
  statusCode: int,
  statusMessage: string,
  trailers: dict<string>,
  payload: string,
  body: string,
  json: unit => Js.Json.t,
  stream: unit => unknown,
  cookies: array<unknown>,
}

/**
 * FastifyRequest is an instance of the standard http or http2 request objects.
 * It defaults to http.IncomingMessage, and it also extends the relative request object.
 */
type request = {
  id: string,
  params: unknown,
  raw: unknown,
  query: unknown,
  headers: unknown,
  body: unknown,
}

type reply = {
  send: 'a. 'a => unit,
  headers: 'a. 'a => unit,
  status: int => unit,
}

@module("fastify")
external make: unit => t = "default"

@send
external inject: (t, injectOptions) => promise<injectResponse> = "inject"

@send
external listen: (t, listenOptions) => promise<string> = "listen"

@send
external listenFirstAvailableLocalPort: t => promise<string> = "listen"

@send
external register: (t, (t, unknown, unit => unit) => unit) => unit = "register"

type addContentTypeParserOptions = {
  bodyLimit?: int,
  parseAs?: [#buffer | #string],
}
@send
external addContentTypeParser: (
  t,
  string,
  addContentTypeParserOptions,
  (request, unknown, (unknown, unknown) => unit) => unit,
) => unit = "addContentTypeParser"

@send external close: t => promise<unit> = "close"

type routeOptions = {
  method: string,
  url: string,
  handler: (request, reply) => unit,
}
@send
external route: (t, routeOptions) => unit = "route"

let route = (app: t, restRoute: Rest.route<'request, 'response>, handler) => {
  let {definition, variablesSchema, responses, pathItems, isRawBody} = restRoute->Rest.params
  let responseParams = switch responses->Js.Dict.values {
  | [response] => response
  | _ =>
    Js.Exn.raiseError("[rescript-rest] Rest route currently supports only one response definition")
  }
  let status = switch responseParams.statuses {
  | [] => 200
  | _ =>
    switch responseParams.statuses->Js.Array2.unsafe_get(0) {
    | #"1XX" => 100
    | #"2XX" => 200
    | #"3XX" => 300
    | #"4XX" => 400
    | #"5XX" => 500
    | #...Rest.Response.numiricStatus as numiricStatus =>
      (numiricStatus: Rest.Response.numiricStatus :> int)
    }
  }

  let url = ref("")
  for idx in 0 to pathItems->Js.Array2.length - 1 {
    let pathItem = pathItems->Js.Array2.unsafe_get(idx)
    switch pathItem {
    | Static(static) => url := url.contents ++ static // FIXME: Escape : with ::
    | Param({name}) => url := url.contents ++ ":" ++ name
    }
  }

  let routeOptions = {
    method: (definition.method :> string),
    url: url.contents,
    handler: (request, reply) => {
      let variables = request->S.parseAnyOrRaiseWith(variablesSchema)
      let _ = handler(variables)->Promise.thenResolve(handlerReturn => {
        let response: {..} = Obj.magic(
          (handlerReturn->S.serializeToUnknownOrRaiseWith(responseParams.schema): unknown),
        )
        let headers = response["headers"]
        if headers->Obj.magic {
          reply.headers(headers)
        }
        reply.status(status)
        reply.send(response["data"])
      })
    },
  }

  if isRawBody {
    app->register((app, _, done) => {
      app->addContentTypeParser(
        "application/json",
        {
          parseAs: #string,
        },
        (_req, data, done) => {
          done(%raw(`null`), data)
        },
      )
      app->route(routeOptions)
      done()
    })
  } else {
    app->route(routeOptions)
  }
}
