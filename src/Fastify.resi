type t
type plugin<'a>

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
external register: (t, plugin<'a>, 'a) => unit = "register"

@send
external ready: t => promise<unit> = "ready"

@send
external listen: (t, listenOptions) => promise<string> = "listen"
@send
external listenFirstAvailableLocalPort: t => promise<string> = "listen"

@send external close: t => promise<unit> = "close"

type options<'input> = {input: 'input}

let route: (t, Rest.route<'request, 'response>, options<'request> => promise<'response>) => unit

module Swagger: {
  type options = {openapi?: OpenAPI.t}

  @module("@fastify/swagger")
  external plugin: plugin<options> = "default"

  @send
  external generate: t => Js.Json.t = "swagger"
}

module Scalar: {
  type options = {routePrefix: string}

  @module("@scalar/fastify-api-reference")
  external plugin: plugin<options> = "default"
}
