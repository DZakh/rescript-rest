type t

type abortSignal

type listenOptions = {
  port?: int,
  host?: string,
  path?: string,
  backlog?: int,
  exclusive?: bool,
  readableAll?: bool,
  writableAll?: bool,
  ipv6Only?: bool,
  signal?: abortSignal,
  listenTextResolver?: (~address: string) => string,
}

type injectOptionsSimulate = {end: bool, split: bool, error: bool, close: bool}
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

@module("fastify")
external make: unit => t = "default"

@send
external inject: (t, injectOptions) => promise<injectResponse> = "inject"

@send
external listen: (t, listenOptions) => promise<string> = "listen"
@send
external listenFirstAvailableLocalPort: t => promise<string> = "listen"

@send external close: t => promise<unit> = "close"

let route: (t, Rest.route<'request, 'response>, 'request => promise<'response>) => unit
