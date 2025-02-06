open RescriptSchema

module Obj = {
  external magic: 'a => 'b = "%identity"
}

module Promise = {
  type t<+'a> = promise<'a>

  @send
  external thenResolve: (t<'a>, 'a => 'b) => t<'b> = "then"
}

type t
type plugin<'a>

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
external register: (t, plugin<'a>, 'a) => unit = "register"

@send
external ready: t => promise<unit> = "ready"

@send
external listen: (t, listenOptions) => promise<string> = "listen"

@send
external listenFirstAvailableLocalPort: t => promise<string> = "listen"

@send
external internalRegister: (t, (t, unknown, unit => unit) => unit) => unit = "register"

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

@send
external setValidatorCompiler: (t, unknown => unknown => bool) => unit = "setValidatorCompiler"

@send external close: t => promise<unit> = "close"

type routeResponseContent = {schema?: JSONSchema.t}
type routeResponse = {
  description?: string,
  content: dict<routeResponseContent>,
}
type routeSchema = {
  description?: string,
  summary?: string,
  deprecated?: bool,
  response?: dict<routeResponse>,
  operationId?: string,
  tags?: array<string>,
  externalDocs?: OpenAPI.externalDocumentation,
}

type routeOptions = {
  method: string,
  url: string,
  handler: 'response. (request, reply) => promise<'response>,
  schema?: routeSchema,
}
@send
external route: (t, routeOptions) => unit = "route"

let route = (app: t, restRoute: Rest.route<'request, 'response>, fn) => {
  // Wrap it with register for:
  // 1. To be able to configure ContentTypeParser specifically for the route
  // 2. To get access to app with registered plugins eg Swagger
  app->internalRegister((app, _, done) => {
    let {definition, variablesSchema, responses, pathItems, isRawBody} = restRoute->Rest.params

    let url = ref("")
    for idx in 0 to pathItems->Js.Array2.length - 1 {
      let pathItem = pathItems->Js.Array2.unsafe_get(idx)
      switch pathItem {
      | Static(static) => url := url.contents ++ static // FIXME: Escape : with ::
      | Param({name}) => url := url.contents ++ ":" ++ name
      }
    }

    let responseSchemas = []
    let routeSchemaResponses: dict<routeResponse> = Js.Dict.empty()
    responses->Js.Array2.forEach(r => {
      responseSchemas->Js.Array2.push(r.schema)->ignore
      let status = switch r.status {
      | Some(status) => status->(Obj.magic: int => string)
      | None => "default"
      }
      let content = Js.Dict.empty()
      content->Js.Dict.set(
        "application/json",
        {
          schema: switch r.dataSchema->JSONSchema.make {
          | Ok(jsonSchema) => jsonSchema
          | Error(message) =>
            Js.Exn.raiseError(
              `Failed to create JSON-Schema for response with status ${status}. Error: ${message}`,
            )
          },
        },
      )
      routeSchemaResponses->Js.Dict.set(
        status,
        {
          description: ?r.description,
          content,
        },
      )
    })

    let responseSchema = S.union(responseSchemas)

    let routeSchema = {
      description: ?definition.description,
      summary: ?definition.summary,
      deprecated: ?definition.deprecated,
      tags: ?definition.tags,
      operationId: ?definition.operationId,
      externalDocs: ?definition.externalDocs,
      response: routeSchemaResponses,
    }
    let routeOptions = {
      method: (definition.method :> string),
      url: url.contents,
      handler: (request, reply) => {
        let variables = try request->S.parseOrThrow(variablesSchema) catch {
        | S.Raised(error) => {
            reply.status(400)
            reply.send({
              "statusCode": 400,
              "error": "Bad Request",
              "message": error->S.Error.message,
            })
            raise(%raw(`0`))
          }
        }
        fn(variables)->Promise.thenResolve(handlerReturn => {
          let data: {..} = handlerReturn->S.reverseConvertOrThrow(responseSchema)->Obj.magic
          let headers = data["headers"]
          if headers->Obj.magic {
            reply.headers(headers)
          }
          reply.status(%raw(`data.status || 200`))
          data["data"]
        })
      },
      schema: routeSchema,
    }

    // Add request schemas only when swagger plugin enabled
    if (app->Obj.magic)["swagger"] {
      let addSchemaFor = location =>
        switch (variablesSchema->S.classify->Obj.magic)["fields"]->Js.Dict.unsafeGet(location) {
        | Some(item: S.item) =>
          switch item.schema->JSONSchema.make {
          | Ok(jsonSchema) =>
            routeSchema
            ->(Obj.magic: routeSchema => dict<JSONSchema.t>)
            ->Js.Dict.set(location, jsonSchema)
          | Error(message) =>
            Js.Exn.raiseError(
              `Failed to create JSON-Schema for ${location} of ${(definition.method :> string)} ${definition.path} route. Error: ${message}`,
            )
          }
        | None => ()
        }
      addSchemaFor("body")
      addSchemaFor("headers")
      addSchemaFor("params")
      addSchemaFor("query")
    }

    // Reset built-in response validator
    app->setValidatorCompiler(_ => _ => true)

    if isRawBody {
      app->addContentTypeParser(
        "application/json",
        {
          parseAs: #string,
        },
        (_req, data, done) => {
          done(%raw(`null`), data)
        },
      )
    }
    app->route(routeOptions)
    done()
  })
}

module Swagger = {
  type options = {openapi?: OpenAPI.t}

  @module("@fastify/swagger")
  external plugin: plugin<options> = "default"

  @send
  external generate: t => Js.Json.t = "swagger"
}

module Scalar = {
  type options = {routePrefix: string}

  @module("@scalar/fastify-api-reference")
  external plugin: plugin<options> = "default"
}
