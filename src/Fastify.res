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

type reply = {send: 'a. 'a => unit}

type routeOptions = {
  method: string,
  url: string,
  handler: (request, reply) => unit,
}

@module("fastify")
external make: unit => t = "default"

@send
external inject: (t, injectOptions) => promise<injectResponse> = "inject"

@send
external listen: (
  t,
  listenOptions,
  ~callback: (~err: unknown, ~address: string) => unit=?,
) => unit = "listen"

@send
external route: (t, routeOptions) => unit = "route"

let route = (app: t, restRoute: Rest.route<'request, 'response>, handler) => {
  let params = restRoute->Rest.params
  app->route({
    method: (params.definition.method :> string),
    url: params.definition.path,
    handler: (request, reply) => {
      let variables = request->S.parseAnyOrRaiseWith(params.variablesSchema)
      let _ = handler(variables)->Promise.thenResolve(response => {
        reply.send(response)
      })
    },
  })
}
