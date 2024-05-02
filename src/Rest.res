@@uncurried

open RescriptSchema

module Obj = {
  external magic: 'a => 'b = "%identity"
}

module WeakMap = {
  type t<'k, 'v> = Js.WeakMap.t<'k, 'v>

  @new external make: unit => t<'k, 'v> = "WeakMap"

  @send external get: (t<'k, 'v>, 'k) => option<'v> = "get"
  @send external set: (t<'k, 'v>, 'k, 'v) => t<'k, 'v> = "set"
}

module ApiFetcher = {
  type body = JsonString(string) | Text(string) | Blob(unknown)
  type args = {body: option<body>, method: string, path: string}
  type return = {body: body, status: int}
  type t = args => promise<return>

  %%private(
    external fetch: (
      string,
      {"body": unknown, "method": string, "headers": {..}},
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
        "headers": switch args.body {
        | Some(JsonString(_)) => {"content-type": "application/json"}
        | _ => ()->Obj.magic
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
  fieldOr: 'value. (string, S.t<'value>, 'value) => 'value,
  tag: 'value. (string, 'value) => unit,
}
type routeDefinition<'variables> = {
  method: string,
  path: string,
  schema: s => 'variables,
}
type routeParams<'variables> = {
  definition: routeDefinition<'variables>,
  isBodyUsed: bool,
  bodySchema: S.t<'variables>,
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
        let definition = route()
        let isBodyUsed = ref(false)
        let bodySchema = S.object(s => {
          let field = (fieldName, schema) => {
            isBodyUsed.contents = true
            s.field(fieldName, schema)
          }

          let tag = (tag, asValue) => {
            isBodyUsed.contents = true
            s.tag(tag, asValue)
          }

          let fieldOr = (fieldName, schema, or) => {
            isBodyUsed.contents = true
            s.fieldOr(fieldName, schema, or)
          }

          definition.schema({
            field,
            fieldOr,
            tag,
          })
        })

        let params = {
          definition,
          bodySchema,
          isBodyUsed: isBodyUsed.contents,
          path: baseUrl ++ definition.path,
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

      let {definition, path, bodySchema, isBodyUsed} = getRouteParams(route)

      let bodyJsonString = switch variables->S.serializeToJsonStringWith(bodySchema) {
      | Ok(j) => j
      | Error(e) => e->S.Error.raise // TODO: Stop throwing
      }
      api({
        body: isBodyUsed ? Some(JsonString(bodyJsonString)) : None,
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
