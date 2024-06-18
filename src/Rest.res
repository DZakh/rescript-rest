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
  path: string,
}

type route<'variables> = unit => routeDefinition<'variables>
external route: (unit => routeDefinition<'variables>) => route<'variables> = "%identity"

type client = {
  call: 'variables. (route<'variables>, ~variables: 'variables) => promise<ApiFetcher.return>,
  baseUrl: string,
  api: ApiFetcher.t,
}

let client = (~baseUrl, ~api=ApiFetcher.default) => {
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
          })
        })

        let params = {
          definition: routeDefinition,
          variablesSchema,
          path: baseUrl ++ routeDefinition.path,
        }

        let _ = initializedRoutes->WeakMap.set(route, params)
        params
      }
    }
  }

  let call:
    type variables. (route<variables>, ~variables: variables) => promise<ApiFetcher.return> =
    (route, ~variables) => {
      let route = route->(Obj.magic: route<variables> => route<unknown>)
      let variables = variables->(Obj.magic: variables => unknown)

      let {definition, path, variablesSchema} = getRouteParams(route)

      let data = variables->S.serializeToUnknownOrRaiseWith(variablesSchema)->Obj.magic

      let body = switch data["body"] {
      | None => None
      | Some(body) => Some(ApiFetcher.JsonString(body->Js.Json.stringify))
      }

      api({
        body,
        headers: data["headers"],
        path,
        method: definition.method,
      })
    }
  {
    baseUrl,
    api,
    call,
  }
}
