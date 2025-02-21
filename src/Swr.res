type return<'data> = {
  data: option<'data>,
  error: option<exn>,
  isLoading: bool,
  isValidating: bool,
  mutate: unknown,
}

type options = {
  errorRetryInterval?: int,
  errorRetryCount?: int,
  loadingTimeout?: int,
  focusThrottleInterval?: int,
  dedupingInterval?: int,
  refreshInterval?: int, // number | ((latestData: Data | undefined) => number);
  refreshWhenHidden?: bool,
  refreshWhenOffline?: bool,
  revalidateOnFocus?: bool,
  revalidateOnReconnect?: bool,
  revalidateOnMount?: bool,
  revalidateIfStale?: bool,
  // shouldRetryOnError?: unknown, // boolean | ((err: Error) => boolean);
  keepPreviousData?: bool,
  // suspense?: bool,
  // fallbackData?: Data | Promise<Data>;
  // fetcher?: Fn;
  // use?: Middleware[];
  // fallback: {
  //     [key: string]: any;
  // };
  isPaused?: unit => bool,
  // onLoadingSlow: (key: string, config: Readonly<PublicConfiguration<Data, Error, Fn>>) => void;
  // onSuccess: (data: Data, key: string, config: Readonly<PublicConfiguration<Data, Error, Fn>>) => void;
  // onError: (err: Error, key: string, config: Readonly<PublicConfiguration<Data, Error, Fn>>) => void;
  // onErrorRetry: (err: Error, key: string, config: Readonly<PublicConfiguration<Data, Error, Fn>>, revalidate: Revalidator, revalidateOpts: Required<RevalidatorOptions>) => void;
  // onDiscarded: (key: string) => void;
  // compare: (a: Data | undefined, b: Data | undefined) => boolean;
  isOnline?: unit => bool,
  isVisible?: unit => bool,
}

@module("swr")
external useSwrInternal: (
  Js.Null.t<string>,
  string => promise<'data>,
  ~options: options=?,
) => return<'data> = "default"

let use = (route, ~baseUrl=?, ~input=?, ~options=?) => {
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
    ~options?,
  )
}
