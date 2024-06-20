@@uncurried

open RescriptSchema

module Obj = {
  external magic: 'a => 'b = "%identity"
}

module Dict = {
  @val
  external mixin: (dict<'a>, dict<'a>) => dict<'a> = "Object.assign"
}

module WeakMap = {
  type t<'k, 'v> = Js.WeakMap.t<'k, 'v>

  @new external make: unit => t<'k, 'v> = "WeakMap"

  @send external get: (t<'k, 'v>, 'k) => option<'v> = "get"
  @send external set: (t<'k, 'v>, 'k, 'v) => t<'k, 'v> = "set"
}

@val
external encodeURIComponent: string => string = "encodeURIComponent"

module ApiFetcher = {
  type body = JsonString(string) | Text(string) | Blob(unknown)
  type args = {body: option<body>, headers: option<dict<unknown>>, method: string, path: string}
  type return = {body: body, status: int}
  type t = args => promise<return>

  %%private(
    external fetch: (
      string,
      {"body": unknown, "method": string, "headers": option<dict<unknown>>},
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
  let default: t = async args => {
    let result = await fetch(
      args.path,
      {
        "method": args.method,
        "body": switch args.body {
        | Some(JsonString(string)) => string->Obj.magic
        | Some(Text(string)) => string->Obj.magic
        | Some(Blob(blob)) => blob->Obj.magic
        | None => ()->Obj.magic
        },
        "headers": switch (args.body, args.headers) {
        | (Some(JsonString(_)), None) => Some({"content-type": "application/json"}->Obj.magic)
        | (Some(JsonString(_)), Some(headers)) =>
          Some(Dict.mixin({"content-type": "application/json"}->Obj.magic, headers))
        | (_, Some(_) as h) => h
        | (_, None) => None
        },
      },
    )
    let contentType = result["headers"]["get"]("content-type")
    switch contentType {
    | Some(contentType)
      if contentType->Js.String2.includes("application/") &&
        contentType->Js.String2.includes("json") => {
        status: result["status"],
        body: JsonString(await result["json"]()),
      }
    | Some(contentType) if contentType->Js.String2.includes("text/") => {
        status: result["status"],
        body: Text(await result["text"]()),
      }
    | _ => {
        status: result["status"],
        body: Blob(await result["blob"]()),
      }
    }
  }
}

type s = {
  field: 'value. (string, S.t<'value>) => 'value,
  header: 'value. (string, S.t<'value>) => 'value,
  query: 'value. (string, S.t<'value>) => 'value,
}
type routeDefinition<'variables> = {
  method: string,
  path: string,
  variables: s => 'variables,
  summary?: string,
  description?: string,
  deprecated?: bool,
}
type routeParams<'variables> = {
  definition: routeDefinition<'variables>,
  variablesSchema: S.t<'variables>,
}

type route<'variables> = unit => routeDefinition<'variables>
external route: (unit => routeDefinition<'variables>) => route<'variables> = "%identity"

type client = {
  call: 'variables. (route<'variables>, 'variables) => promise<ApiFetcher.return>,
  baseUrl: string,
  api: ApiFetcher.t,
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

// Inspired by https://github.com/ts-rest/ts-rest/blob/7792ef7bdc352e84a4f5766c53f984a9d630c60e/libs/ts-rest/core/src/lib/client.ts#L347
let getCompletePath = (~baseUrl, ~routePath, ~maybeQuery, ~jsonQuery) => {
  let path = ref(baseUrl ++ routePath)

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

let client = (~baseUrl, ~api=ApiFetcher.default, ~jsonQuery=false) => {
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
            header: (fieldName, schema) => {
              s.nestedField("headers", fieldName, schema)
            },
            query: (fieldName, schema) => {
              s.nestedField("query", fieldName, schema)
            },
          })
        })

        let params = {
          definition: routeDefinition,
          variablesSchema,
        }

        let _ = initializedRoutes->WeakMap.set(route, params)
        params
      }
    }
  }

  let call:
    type variables. (route<variables>, variables) => promise<ApiFetcher.return> =
    (route, variables) => {
      let route = route->(Obj.magic: route<variables> => route<unknown>)
      let variables = variables->(Obj.magic: variables => unknown)

      let {definition, variablesSchema} = getRouteParams(route)

      let data = variables->S.serializeToUnknownOrRaiseWith(variablesSchema)->Obj.magic

      let body = switch data["body"] {
      | None => None
      | Some(body) => Some(ApiFetcher.JsonString(body->Js.Json.stringify))
      }

      api({
        body,
        headers: data["headers"],
        path: getCompletePath(
          ~baseUrl,
          ~routePath=definition.path,
          ~maybeQuery=data["query"],
          ~jsonQuery,
        ),
        method: definition.method,
      })
    }
  {
    baseUrl,
    api,
    call,
    jsonQuery,
  }
}
