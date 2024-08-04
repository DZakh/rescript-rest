@@uncurried

open RescriptSchema

module ApiFetcher: {
  type args = {body: option<unknown>, headers: option<dict<unknown>>, method: string, path: string}
  type response = {data: unknown, status: int, headers: dict<unknown>}
  type t = args => promise<response>

  // Inspired by https://github.com/ts-rest/ts-rest/blob/7792ef7bdc352e84a4f5766c53f984a9d630c60e/libs/ts-rest/core/src/lib/client.ts#L102
  /**
  * Default fetch api implementation:
  *
  * Can be used as a reference for implementing your own fetcher,
  * or used in the "api" field of ClientArgs to allow you to hook
  * into the request to run custom logic
  */
  let default: t
}

module Response: {
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
}

type s = {
  field: 'value. (string, S.t<'value>) => 'value,
  body: 'value. S.t<'value> => 'value,
  header: 'value. (string, S.t<'value>) => 'value,
  query: 'value. (string, S.t<'value>) => 'value,
  param: 'value. (string, S.t<'value>) => 'value,
}

type definition<'variables, 'response> = {
  method: string,
  path: string,
  variables: s => 'variables,
  responses: array<Response.s => 'response>,
  summary?: string,
  description?: string,
  deprecated?: bool,
}

type route<'variables, 'response>

external route: (unit => definition<'variables, 'response>) => route<'variables, 'response> =
  "%identity"

type client = {
  call: 'variables 'response. (route<'variables, 'response>, 'variables) => promise<'response>,
  baseUrl: string,
  fetcher: ApiFetcher.t,
  jsonQuery: bool,
}

let client: (~baseUrl: string, ~fetcher: ApiFetcher.t=?, ~jsonQuery: bool=?) => client

let routeToOpenAPI: (route<'variables, 'response>, ~jsonQuery: bool=?) => OpenAPI.operation
