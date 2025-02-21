type return<'data> = {
  data: option<'data>,
  error: option<exn>,
  isLoading: bool,
  isValidating: bool,
  mutate: unknown,
}

type options = {
  /**
   *  error retry interval in milliseconds
    *  @defaultValue 5000
    */
  errorRetryInterval?: int,
  /** max error retry count */
  errorRetryCount?: int,
  /**
   * timeout to trigger the onLoadingSlow event in milliseconds
    * @defaultValue 3000
    */
  loadingTimeout?: int,
  /**
   * only revalidate once during a time span in milliseconds
    * @defaultValue 5000
    */
  focusThrottleInterval?: int,
  /**
   * dedupe requests with the same key in this time span in milliseconds
    * @defaultValue 2000
    */
  dedupingInterval?: int,
  /**
   *  @link https://swr.vercel.app/docs/revalidation
   *  * Disabled by default: `refreshInterval = 0`
   *  * If set to a number, polling interval in milliseconds
   *  * If set to a function, the function will receive the latest data and should return the interval in milliseconds
   */
  refreshInterval?: int, // number | ((latestData: Data | undefined) => number);
  /**
   * polling when the window is invisible (if `refreshInterval` is enabled)
    * @defaultValue false
    *
    */
  refreshWhenHidden?: bool,
  /**
   * polling when the browser is offline (determined by `navigator.onLine`)
    */
  refreshWhenOffline?: bool,
  /**
   * automatically revalidate when window gets focused
    * @defaultValue true
    * @link https://swr.vercel.app/docs/revalidation
    */
  revalidateOnFocus?: bool,
  /**
   * automatically revalidate when the browser regains a network connection (via `navigator.onLine`)
    * @defaultValue true
    * @link https://swr.vercel.app/docs/revalidation
    */
  revalidateOnReconnect?: bool,
  /**
   * enable or disable automatic revalidation when component is mounted
    */
  revalidateOnMount?: bool,
  /**
   * automatically revalidate even if there is stale data
    * @defaultValue true
    * @link https://swr.vercel.app/docs/revalidation#disable-automatic-revalidations
    */
  revalidateIfStale?: bool,
  // /**
  //  * retry when fetcher has an error
  //  * @defaultValue true
  //  */
  // shouldRetryOnError?: unknown, // boolean | ((err: Error) => boolean);
  /**
   * keep the previous result when key is changed but data is not ready
    * @defaultValue false
    */
  keepPreviousData?: bool,
  // /**
  //  * @experimental  enable React Suspense mode
  //  * @defaultValue false
  //  * @link https://swr.vercel.app/docs/suspense
  //  */
  // suspense?: bool,
  // /**
  //  * initial data to be returned (note: ***This is per-hook***)
  //  * @link https://swr.vercel.app/docs/with-nextjs
  //  */
  // fallbackData?: Data | Promise<Data>;
  // /**
  //  * the fetcher function
  //  */
  // fetcher?: Fn;
  // /**
  //  * array of middleware functions
  //  * @link https://swr.vercel.app/docs/middleware
  //  */
  // use?: Middleware[];
  // /**
  //  * a key-value object of multiple fallback data
  //  * @link https://swr.vercel.app/docs/with-nextjs#pre-rendering-with-default-data
  //  */
  // fallback: {
  //     [key: string]: any;
  // };
  /**
   * function to detect whether pause revalidations, will ignore fetched data and errors when it returns true. Returns false by default.
    */
  isPaused?: unit => bool,
  // /**
  //  * callback function when a request takes too long to load (see `loadingTimeout`)
  //  */
  // onLoadingSlow: (key: string, config: Readonly<PublicConfiguration<Data, Error, Fn>>) => void;
  // /**
  //  * callback function when a request finishes successfully
  //  */
  // onSuccess: (data: Data, key: string, config: Readonly<PublicConfiguration<Data, Error, Fn>>) => void;
  // /**
  //  * callback function when a request returns an error
  //  */
  // onError: (err: Error, key: string, config: Readonly<PublicConfiguration<Data, Error, Fn>>) => void;
  // /**
  //  * handler for error retry
  //  */
  // onErrorRetry: (err: Error, key: string, config: Readonly<PublicConfiguration<Data, Error, Fn>>, revalidate: Revalidator, revalidateOpts: Required<RevalidatorOptions>) => void;
  // /**
  //  * callback function when a request is ignored
  //  */
  // onDiscarded: (key: string) => void;
  // /**
  //  * comparison function used to detect when returned data has changed, to avoid spurious rerenders. By default, [stable-hash](https://github.com/shuding/stable-hash) is used.
  //  */
  // compare: (a: Data | undefined, b: Data | undefined) => boolean;
  /**
   * isOnline and isVisible are functions that return a boolean, to determine if the application is "active". By default, SWR will bail out a revalidation if these conditions are not met.
    * @link https://swr.vercel.app/docs/advanced/react-native#customize-focus-and-reconnect-events
    */
  isOnline?: unit => bool,
  /**
   * isOnline and isVisible are functions that return a boolean, to determine if the application is "active". By default, SWR will bail out a revalidation if these conditions are not met.
    * @link https://swr.vercel.app/docs/advanced/react-native#customize-focus-and-reconnect-events
    */
  isVisible?: unit => bool,
}

let use: (
  Rest.route<'input, 'response>,
  ~baseUrl: string=?,
  ~input: 'input=?,
  ~options: options=?,
) => return<'response>
