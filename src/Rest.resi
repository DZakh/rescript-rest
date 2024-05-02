@@uncurried

open RescriptSchema

module ApiFetcher: {
  type body = JsonString(string) | Text(string) | Blob(unknown)
  type args = {body: option<body>, method: string, path: string}
  type return = {body: body, status: int}
  type t = args => promise<return>

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

type route<'variables>
external route: (unit => routeDefinition<'variables>) => route<'variables> = "%identity"

type client = {
  call: 'variables. (route<'variables>, ~variables: 'variables) => promise<ApiFetcher.return>,
  baseUrl: string,
  api: ApiFetcher.t,
}

let client: (~baseUrl: string, ~api: ApiFetcher.t=?) => client
