type return<'data> = {
  data: option<'data>,
  error: option<exn>,
  isLoading: bool,
  isValidating: bool,
  mutate: unknown,
}

@module("swr")
external useSwrInternal: (Js.Null.t<string>, string => promise<'data>) => return<'data> = "default"

let use = (route, ~input=?, ~baseUrl=?) => {
  let {definition} = route->Rest.params
  if definition.method !== Get {
    Js.Exn.raiseError(`[rescript-rest] Only GET requests are supported by Swr`)
  }
  useSwrInternal(
    switch input {
    | Some(input) => Value(route->Rest.url(input, ~baseUrl?))
    | None => Null
    },
    _ => {
      route->Rest.fetch(
        switch baseUrl {
        | Some(url) => url
        | None => ""
        },
        input->Belt.Option.getExn,
      )
    },
  )
}
