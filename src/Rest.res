@@uncurried

open RescriptSchema

module Exn = {
  type error

  @new
  external makeError: string => error = "Error"

  let raiseAny = (any: 'any): 'a => any->Obj.magic->raise

  let raiseError: error => 'a = raiseAny
}

module Obj = {
  external magic: 'a => 'b = "%identity"
}

module Promise = {
  type t<+'a> = promise<'a>

  @send
  external thenResolve: (t<'a>, 'a => 'b) => t<'b> = "then"
}

module Option = {
  let unsafeSome: 'a => option<'a> = Obj.magic
}

module Dict = {
  @inline
  let has = (dict, key) => {
    dict->Js.Dict.unsafeGet(key)->(Obj.magic: 'a => bool)
  }
}

module Object = {
  @val
  external mixin: ({..} as 'a, {..}) => 'a = "Object.assign"
}

module WeakMap = {
  type t<'k, 'v> = Js.WeakMap.t<'k, 'v>

  @new external make: unit => t<'k, 'v> = "WeakMap"

  @send external get: (t<'k, 'v>, 'k) => option<'v> = "get"
  @send external set: (t<'k, 'v>, 'k, 'v) => t<'k, 'v> = "set"
}

@inline
let panic = message => Exn.raiseError(Exn.makeError(`[rescript-rest] ${message}`))

@val
external encodeURIComponent: string => string = "encodeURIComponent"

module ApiFetcher = {
  type args = {body: option<unknown>, headers: option<dict<unknown>>, method: string, path: string}
  type response = {data: unknown, status: int, headers: dict<unknown>}
  type t = args => promise<response>

  %%private(
    external fetch: (
      string,
      {"method": string, "body": option<unknown>, "headers": option<dict<unknown>>},
    ) => promise<{..}> = "fetch"
  )

  // Inspired by https://github.com/ts-rest/ts-rest/blob/7792ef7bdc352e84a4f5766c53f984a9d630c60e/libs/ts-rest/core/src/lib/client.ts#L102
  /**
  * Default fetch api implementation:
  *
  * Can be used as a reference for implementing your own fetcher,
  * or used in the "api" field of ClientArgs to allow you to hook
  * into the request to run custom logic
  */
  let default: t = async (args): response => {
    let body = switch args.body {
    | None => None
    | Some(_) =>
      args.body
      ->(Obj.magic: option<unknown> => Js.Json.t)
      ->Js.Json.stringify
      ->(Obj.magic: string => option<unknown>)
    }
    let headers = switch args.body {
    | None => args.headers
    | Some(_) => {
        let contentHeaders = {
          "content-type": "application/json",
        }

        (
          args.headers === None
            ? contentHeaders
            : Object.mixin(contentHeaders, args.headers->(Obj.magic: option<dict<unknown>> => {..}))
        )->(Obj.magic: {..} => option<dict<unknown>>)
      }
    }
    let result = await fetch(
      args.path,
      {
        "method": args.method,
        "body": body,
        "headers": headers,
      },
    )
    let contentType = result["headers"]["get"]("content-type")

    // Note: contentType might be null
    if (
      contentType->Obj.magic &&
      contentType->Js.String2.includes("application/") &&
      contentType->Js.String2.includes("json")
    ) {
      {
        status: result["status"],
        data: await result["json"](),
        headers: result["headers"],
      }
    } else if contentType->Obj.magic && contentType->Js.String2.includes("text/") {
      {
        status: result["status"],
        data: await result["text"](),
        headers: result["headers"],
      }
    } else {
      {
        status: result["status"],
        data: await result["blob"](),
        headers: result["headers"],
      }
    }
  }
}

module Response = {
  type status = [
    | #"1XX"
    | #"2XX"
    | #"3XX"
    | #"4XX"
    | #"5XX"
    | #100
    | #101
    | #102
    | #200
    | #201
    | #202
    | #203
    | #204
    | #205
    | #206
    | #207
    | #300
    | #301
    | #302
    | #303
    | #304
    | #305
    | #307
    | #308
    | #400
    | #401
    | #402
    | #403
    | #404
    | #405
    | #406
    | #407
    | #408
    | #409
    | #410
    | #411
    | #412
    | #413
    | #414
    | #415
    | #416
    | #417
    | #418
    | #419
    | #420
    | #421
    | #422
    | #423
    | #424
    | #428
    | #429
    | #431
    | #451
    | #500
    | #501
    | #502
    | #503
    | #504
    | #505
    | #507
    | #511
  ]

  type s = {
    status: status => unit,
    description: string => unit,
    data: 'value. S.t<'value> => 'value,
    field: 'value. (string, S.t<'value>) => 'value,
    header: 'value. (string, S.t<'value>) => 'value,
  }

  type t<'response> = {
    // When it's empty, treat response as a default
    statuses: array<status>,
    description: option<string>,
    schema: S.t<'response>,
  }

  type builder<'response> = {
    // When it's empty, treat response as a default
    statuses: array<status>,
    mutable description?: string,
    mutable schema?: S.t<'response>,
  }

  let register = (
    map: dict<t<'response>>,
    status: [< status | #default],
    builder: builder<'response>,
  ) => {
    let key = status->(Obj.magic: [< status | #default] => string)
    if map->Dict.has(key) {
      panic(`Response for the "${key}" status registered multiple times`)
    } else {
      map->Js.Dict.set(key, builder->(Obj.magic: builder<'response> => t<'response>))
    }
  }

  @inline
  let find = (map: dict<t<'response>>, responseStatus: int): option<t<'response>> => {
    (map
    ->Js.Dict.unsafeGet(responseStatus->(Obj.magic: int => string))
    ->(Obj.magic: t<'response> => bool) ||
    map
    ->Js.Dict.unsafeGet((responseStatus / 100)->(Obj.magic: int => string) ++ "XX")
    ->(Obj.magic: t<'response> => bool) ||
    map->Js.Dict.unsafeGet("default")->(Obj.magic: t<'response> => bool))
      ->(Obj.magic: bool => option<t<'response>>)
  }
}

type s = {
  field: 'value. (string, S.t<'value>) => 'value,
  body: 'value. S.t<'value> => 'value,
  header: 'value. (string, S.t<'value>) => 'value,
  query: 'value. (string, S.t<'value>) => 'value,
  param: 'value. (string, S.t<'value>) => 'value,
}
type routeDefinition<'variables, 'response> = {
  method: string,
  path: string,
  variables: s => 'variables,
  responses: array<Response.s => 'response>,
  summary?: string,
  description?: string,
  deprecated?: bool,
}
type routeParams<'variables, 'response> = {
  definition: routeDefinition<'variables, 'response>,
  variablesSchema: S.t<'variables>,
  responses: dict<Response.t<'response>>,
}

type route<'variables, 'response> = unit => routeDefinition<'variables, 'response>
external route: (unit => routeDefinition<'variables, 'response>) => route<'variables, 'response> =
  "%identity"

type client = {
  call: 'variables 'response. (route<'variables, 'response>, 'variables) => promise<'response>,
  baseUrl: string,
  fetcher: ApiFetcher.t,
  // By default, all query parameters are encoded as strings, however, you can use the jsonQuery option to encode query parameters as typed JSON values.
  jsonQuery: bool,
}

/**
 * A recursive function to convert an object/string/number/whatever into an array of key=value pairs
 *
 * This should be fully compatible with the "qs" library, but more optimised and without the need to add a dependency
 */
let rec tokeniseValue = (key, value, ~append) => {
  if Js.Array2.isArray(value) {
    value
    ->(Obj.magic: unknown => array<unknown>)
    ->Js.Array2.forEachi((v, idx) => {
      tokeniseValue(`${key}[${idx->Js.Int.toString}]`, v, ~append)
    })
  } else if value === %raw(`null`) {
    append(key, "")
  } else if value === %raw(`void 0`) {
    ()
  } else if Js.typeof(value) === "object" {
    let dict = value->(Obj.magic: unknown => dict<unknown>)
    dict
    ->Js.Dict.keys
    ->Js.Array2.forEach(k => {
      tokeniseValue(`${key}[${encodeURIComponent(k)}]`, dict->Js.Dict.unsafeGet(k), ~append)
    })
  } else {
    append(key, value->(Obj.magic: unknown => string))
  }
}

// FIXME: Validate that all defined paths are registered
// FIXME: Prevent `/` in the path param
/**
 * @param path - The URL e.g. /posts/:id
 * @param maybeParams - The params e.g. `{ id: string }`
 * @returns - The URL with the params e.g. /posts/123
 */
let insertParamsIntoPath = (~path, ~maybeParams) => {
  path
  ->Js.String2.unsafeReplaceBy1(%re("/:([^/]+)/g"), (_, p, _, _) => {
    switch maybeParams {
    | Some(params) =>
      switch params->Js.Dict.unsafeGet(p)->(Obj.magic: unknown => option<string>) {
      | Some(s) => s
      | None => ""
      }
    | None => ""
    }
  })
  ->Js.String2.replaceByRe(%re("/\/\//g"), "/")
}

// Inspired by https://github.com/ts-rest/ts-rest/blob/7792ef7bdc352e84a4f5766c53f984a9d630c60e/libs/ts-rest/core/src/lib/client.ts#L347
let getCompletePath = (~baseUrl, ~routePath, ~maybeQuery, ~maybeParams, ~jsonQuery) => {
  let path = ref(baseUrl ++ insertParamsIntoPath(~path=routePath, ~maybeParams))

  switch maybeQuery {
  | None => ()
  | Some(query) => {
      let queryItems = []

      let append = (key, value) => {
        let _ = queryItems->Js.Array2.push(key ++ "=" ++ encodeURIComponent(value))
      }

      let queryNames = query->Js.Dict.keys
      for idx in 0 to queryNames->Js.Array2.length - 1 {
        let queryName = queryNames->Js.Array2.unsafe_get(idx)
        let value = query->Js.Dict.unsafeGet(queryName)
        let key = encodeURIComponent(queryName)
        if value !== %raw(`void 0`) {
          switch jsonQuery {
          // if value is a string and is not a reserved JSON value or a number, pass it without encoding
          // this makes strings look nicer in the URL (e.g. ?name=John instead of ?name=%22John%22)
          // this is also how OpenAPI will pass strings even if they are marked as application/json types
          | true =>
            append(
              key,
              if (
                Js.typeof(value) === "string" && {
                    let value = value->(Obj.magic: unknown => string)
                    value !== "true" &&
                    value !== "false" &&
                    value !== "null" &&
                    Js.Float.isNaN(Js.Float.fromString(value))
                  }
              ) {
                value->(Obj.magic: unknown => string)
              } else {
                value->(Obj.magic: unknown => Js.Json.t)->Js.Json.stringify
              },
            )
          | false => tokeniseValue(key, value, ~append)
          }
        }
      }

      if queryItems->Js.Array2.length > 0 {
        path := path.contents ++ "?" ++ queryItems->Js.Array2.joinWith("&")
      }
    }
  }

  path.contents
}

let client = (~baseUrl, ~fetcher=ApiFetcher.default, ~jsonQuery=false) => {
  let initializedRoutes = WeakMap.make()

  let getRouteParams = route => {
    switch initializedRoutes->WeakMap.get(route) {
    | Some(r) => r
    | None => {
        let routeDefinition = route()

        let variablesSchema = S.object(s => {
          routeDefinition.variables({
            field: (fieldName, schema) => {
              s.nestedField("body", fieldName, schema)
            },
            body: schema => {
              s.field("body", schema)
            },
            header: (fieldName, schema) => {
              s.nestedField("headers", fieldName, schema)
            },
            query: (fieldName, schema) => {
              s.nestedField("query", fieldName, schema)
            },
            param: (fieldName, schema) => {
              s.nestedField("params", fieldName, schema)
            },
          })
        })

        let responses = Js.Dict.empty()
        routeDefinition.responses->Js.Array2.forEach(r => {
          let builder: Response.builder<unknown> = {
            statuses: [],
          }
          let schema = S.object(s => {
            r({
              status: status => {
                responses->Response.register(status, builder)
                let _ = builder.statuses->Js.Array2.push(status)
              },
              description: d => builder.description = Some(d),
              field: (fieldName, schema) => {
                s.nestedField("data", fieldName, schema)
              },
              data: schema => {
                s.field("data", schema)
              },
              header: (fieldName, schema) => {
                s.nestedField("headers", fieldName, schema)
              },
            })
          })
          if builder.statuses->Js.Array2.length === 0 {
            responses->Response.register(#default, builder)
          }
          builder.schema = Option.unsafeSome(schema)
        })

        let params = {
          definition: routeDefinition,
          variablesSchema,
          responses,
        }

        let _ = initializedRoutes->WeakMap.set(route, params)
        params
      }
    }
  }

  let call:
    type variables response. (route<variables, response>, variables) => promise<response> =
    (route, variables) => {
      let route = route->(Obj.magic: route<variables, response> => route<unknown, unknown>)
      let variables = variables->(Obj.magic: variables => unknown)

      let {definition, variablesSchema, responses} = getRouteParams(route)

      let data = variables->S.serializeToUnknownOrRaiseWith(variablesSchema)->Obj.magic

      fetcher({
        body: data["body"],
        headers: data["headers"],
        path: getCompletePath(
          ~baseUrl,
          ~routePath=definition.path,
          ~maybeQuery=data["query"],
          ~maybeParams=data["params"],
          ~jsonQuery,
        ),
        method: definition.method,
      })->Promise.thenResolve(fetcherResponse => {
        switch responses->Response.find(fetcherResponse.status) {
        | None =>
          panic(
            `No registered responses for the status "${fetcherResponse.status->Js.Int.toString}"`,
          )
        | Some(response) =>
          fetcherResponse
          ->S.parseAnyOrRaiseWith(response.schema)
          ->(Obj.magic: unknown => response)
        }
      })
    }
  {
    baseUrl,
    fetcher,
    call,
    jsonQuery,
  }
}
