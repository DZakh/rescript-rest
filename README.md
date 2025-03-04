[![CI](https://github.com/DZakh/rescript-rest/actions/workflows/ci.yml/badge.svg)](https://github.com/DZakh/rescript-rest/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/DZakh/rescript-rest/branch/main/graph/badge.svg?token=40G6YKKD6J)](https://codecov.io/gh/DZakh/rescript-rest)
[![npm](https://img.shields.io/npm/dm/rescript-rest)](https://www.npmjs.com/package/rescript-rest)

# ReScript Rest 😴

- **RPC-like client with no codegen**  
  Fully typed RPC-like client, with no need for code generation!

- **API design agnostic**  
  REST? HTTP-RPC? Your own custom hybrid? rescript-rest doesn't care!

- **First class DX**  
  Use your application data structures and types without worrying about how they're transformed and transferred.

- **Small package size and tree-shakable routes**  
  Routes comple to simple functions which allows tree-shaking only possible with ReScript.

> ⚠️ **rescript-rest** relies on **rescript-schema** which uses `eval` for parsing. It's usually fine but might not work in some environments like Cloudflare Workers or third-party scripts used on pages with the [script-src](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/script-src) header.

## Super Simple Example

Define your API contract somewhere shared, for example, `Contract.res`:

```rescript
let getPosts = Rest.route(() => {
  path: "/posts",
  method: Get,
  input: s => {
    "skip": s.query("skip", S.int),
    "take": s.query("take", S.int),
    "page": s.header("x-pagination-page", S.option(S.int)),
  },
  responses: [
    s => {
      s.status(200)
      s.field("posts", S.array(postSchema))
    },
  ],
})
```

In the same file set an endpoint your fetch calls should use:

```rescript
// Contract.res
Rest.setGlobalClient("http://localhost:3000")
```

Consume the API on the client with a RPC-like interface:

```rescript
let result = await Contract.getPosts->Rest.fetch(
  {"skip": 0, "take": 10, "page": Some(1)}
  // ^-- Fully typed!
) // ℹ️ It'll do a GET request to http://localhost:3000/posts?skip=0&take=10 with the `{"x-pagination-page": "1"}` headers
```

Or use the [SWR](https://swr.vercel.app/) client-side integration and consume your data in React components:

```rescript
@react.component
let make = () => {
  let posts = Contract.getPosts->Swr.use(~input={"skip": 0, "take": 10, "page": Some(1)})
  switch posts {
  | {error: Some(_)} => "Something went wrong!"->React.string
  | {data: None} => "Loading..."->React.string
  | {data: Some(posts)} => <Posts posts />
  }
}
```

Fulfil the contract on your sever, with a type-safe Fastify or Next.js integrations:

```rescript
let app = Fastify.make()

app->Fastify.route(Contract.getPosts, ({input}) => {
  queryPosts(~skip=input["skip"], ~take=input["take"], ~page=input["page"])
})
// ^-- Both input and return value are fully typed!

let _ = app->Fastify.listen({port: 3000})
```

**Examples from public repositories:**

- [Cli App Rock-Paper-Scissors](https://github.com/Nicolas1st/net-cli-rock-paper-scissors/blob/main/apps/client/src/Api.res)

## Tutorials

- Building and consuming REST API in ReScript with rescript-rest and Fastify ([YouTube](https://youtu.be/37FY6a-zY20?si=72zT8Gecs5vmDPlD))
- Learn more about ReScript Schema ([Dev.to](https://dev.to/dzakh/javascript-schema-library-from-the-future-5420))

## Table of Contents

- [Super Simple Example](#super-simple-example)
- [Tutorials](#tutorials)
- [Table of Contents](#table-of-contents)
- [Install](#install)
- [Route Definition](#route-definition)
  - [RPC-like abstraction](#rpc-like-abstraction)
  - [Path Parameters](#path-parameters)
  - [Query Parameters](#query-parameters)
  - [Request Headers](#request-headers)
    - [Authentication Header](#authentication-header)
  - [Raw Body](#raw-body)
  - [Responses](#responses)
  - [Response Headers](#response-headers)
  - [Temporary Redirect](#temporary-redirect)
- [Fetch & Client](#fetch--client)
  - [API Fetcher](#api-fetcher)
- [Client-side Integrations](#client-side-integrations)
  - [SWR](#swr)
    - [Polling](#polling)
- [Server-side Integrations](#server-side-integrations)
  - [Next.js](#nextjs)
    - [Raw Body for Webhooks](#raw-body-for-webhooks)
  - [Fastify](#fastify)
  - [OpenAPI Documentation with Fastify & Scalar](#openapi-documentation-with-fastify--scalar)
- [Useful Utils](#useful-utils)
  - [`Rest.url`](#resturl)

## Install

Install peer dependencies `rescript` ([instruction](https://rescript-lang.org/docs/manual/latest/installation)) with `rescript-schema` ([instruction](https://github.com/DZakh/rescript-schema/blob/main/docs/rescript-usage.md#install)).

And ReScript Rest itself:

```sh
npm install rescript-rest
```

Add `rescript-rest` to `bs-dependencies` in your `rescript.json`:

```diff
{
  ...
+ "bs-dependencies": ["rescript-rest"],
}
```

## Route Definition

Routes are the main building block of the library and a perfect way to describe a contract between your client and server.

For every route you can describe how the HTTP transport will look like, the `'input` and `'output` types, as well as add additional metadata to use for OpenAPI.

### RPC-like abstraction

Alternatively if you use ReScript Rest both on client and server and you don't care about how the data is transfered, there's a helper built on top of `Rest.route`. Just define input and output schemas and done:

```rescript
let getPosts = Rest.rpc(() => {
  input: S.schema(s => {
    "skip": s.matches(S.int),
    "take": s.matches(S.int),
    "page": s.matches(S.option(S.int)),
  }),
  output: S.array(postSchema),
})

let result = await Contract.getPosts->Rest.fetch(
  {"skip": 0, "take": 10, "page": Some(1)}
)
// ℹ️ It'll do a POST request to http://localhost:3000/getPosts with the `{"skip": 0, "take": 10, "page": 1}` body and application/json Content Type
```

This is a code snipped from the super simple example above. Note how I only changed the route definition, but the fetching call stayed untouched. The same goes for the server implementation - if the input and output types of the route don't change there's no need to rewrite any logic.

> 🧠 The path for the route is either taken from `operationId` or the name of the route variable.

### Path Parameters

You can define path parameters by adding them to the `path` strin with a curly brace `{}` including the parameter name. Then each parameter must be defined in `input` with the `s.param` method.

```rescript
let getPost = Rest.route(() => {
  path: "/api/author/{authorId}/posts/{id}",
  method: Get,
  input: s => {
    "authorId": s.param("authorId", S.string->S.uuid),
    "id": s.param("id", S.int),
  },
  responses: [
    s => s.data(postSchema),
  ],
})

let result = await getPost->Rest.fetch(
  {
    "authorId": "d7fa3ac6-5bfa-4322-bb2b-317ca629f61c",
    "id": 1
  }
) // ℹ️ It'll do a GET request to http://localhost:3000/api/author/d7fa3ac6-5bfa-4322-bb2b-317ca629f61c/posts/1
```

If you would like to run validations or transformations on the path parameters, you can use [`rescript-schema`](https://github.com/DZakh/rescript-schema) features for this. Note that the parameter names in the `s.param` **must** match the parameter names in the `path` string.

### Query Parameters

You can add query parameters to the request by using the `s.query` method in the `input` definition.

```rescript
let getPosts = Rest.route(() => {
  path: "/posts",
  method: Get,
  input: s => {
    "skip": s.query("skip", S.int),
    "take": s.query("take", S.int),
  },
  responses: [
    s => s.data(S.array(postSchema)),
  ],
})

let result = await getPosts->Rest.fetch(
  {
    "skip": 0,
    "take": 10,
  }
) // ℹ️ It'll do a GET request to http://localhost:3000/posts?skip=0&take=10
```

You can also configure rescript-rest to encode/decode query parameters as JSON by using the `jsonQuery` option. This allows you to skip having to do type coercions, and allow you to use complex and typed JSON objects.

### Request Headers

You can add headers to the request by using the `s.header` method in the `input` definition.

#### Authentication Header

For the Authentication header there's an additional helper `s.auth` which supports `Bearer` and `Basic` authentication schemes.

```rescript
let getPosts = Rest.route(() => {
  path: "/posts",
  method: Get,
  input: s => {
    "token": s.auth(Bearer),
    "pagination": s.header("x-pagination", S.option(S.int)),
  },
  responses: [
    s => s.data(S.array(postSchema)),
  ],
})

let result = await getPosts->Rest.fetch(
  {
    "token": "abc",
    "pagination": 10,
  }
) // ℹ️ It'll do a GET request to http://localhost:3000/posts with the `{"authorization": "Bearer abc", "x-pagination": "10"}` headers
```

### Raw Body

For some low-level APIs, you may need to send raw body without any additional processing. You can use `s.rawBody` method to define a raw body schema. The schema should be string-based, but you can apply transformations to it using `s.variant` or `s.transform` methods.

```rescript
let getLogs = Rest.route(() => {
  path: "/logs",
  method: POST,
  input: s => s.rawBody(S.string->S.transform(s => {
    // If you use the route on server side, you should also provide the parse function here,
    // But for client side, you can omit it
    serialize: logLevel => {
      `{
        "size": 20,
        "query": {
          "bool": {
            "must": [{"terms": {"log.level": ${logLevels}}}]
          }
        }
      }`
    }
  })),
  responses: [
    s => s.data(S.array(S.string)),
  ],
})

let result = await getLogs->Rest.fetch("debug")
// ℹ️ It'll do a POST request to http://localhost:3000/logs with the body `{"size": 20, "query": {"bool": {"must": [{"terms": {"log.level": ["debug"]}}]}}}` and the headers `{"content-type": "application/json"}`
```

You can also use routes with `rawBody` on the server side with Fastify as any other route:

```rescript
app->Fastify.route(getLogs, async input => {
  // Do something with input and return response
})
```

> 🧠 Currently Raw Body is sent with the application/json Content Type. If you need support for other Content Types, please open an issue or PR.

### Responses

Responses are described as an array of response definitions. It's possible to assign the definition to a specific status using `s.status` method.

If `s.status` is not used in a response definition, it'll be treated as a `default` case, accepting a response with any status code. And for the server-side code, it'll send a response with the status code `200`.

```rescript
let createPost = Rest.route(() => {
  path: "/posts",
  method: Post,
  input: _ => (),
  responses: [
    s => {
      s.status(201)
      Ok(s.data(postSchema))
    },
    s => {
      s.status(404)
      Error(s.field("message", S.string))
    },
  ],
})
```

<!-- You can use `s.status` multiple times. To define a range of response statuses, you may use `1XX`, `2XX`, `3XX`, `4XX` and `5XX`.

```rescript
let createPost = Rest.route(() => {
  path: "/posts",
  method: Post,
  input: _ => (),
  responses: [
    s => {
      s.status(201)
      Ok(s.data(postSchema))
    },
    s => {
      s.status(404)
      Error(s.field("message", S.string))
    },
    s => {
      s.status("5XX")
      Error("Server Error")
    },
    s => Error("Unexpected Error"),
  ],
})
```
-->

### Response Headers

Responses from an API can include custom headers to provide additional information on the result of an API call. For example, a rate-limited API may provide the rate limit status via response headers as follows:

```
HTTP 1/1 200 OK
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 99
X-RateLimit-Reset: 2016-10-12T11:00:00Z
{ ... }
```

You can define custom headers in a response as follows:

```rescript
let ping = Rest.route(() => {
  path: "/ping",
  method: Get,
  summary: "Checks if the server is alive",
  input: _ => (),
  responses: [
    s => {
      s.status(200)
      s.description("OK")
      {
        "limit": s.header("X-RateLimit-Limit", S.int->S.description("Request limit per hour.")),
        "remaining": s.header("X-RateLimit-Remaining", S.int->S.description("The number of requests left for the time window.")),
        "reset": s.header("X-RateLimit-Reset", S.string->S.datetime->S.description("The UTC date/time at which the current rate limit window resets.")),
      }
    }
  ],
})
```

### Temporary Redirect

You can define a redirect using Route response definition:

```rescript
let route = Rest.route(() => {
  path: "/redirect",
  method: Get,
  summary: "Redirect to another URL",
  description: `This endpoint redirects the client to "/new-destination" using an HTTP "307 Temporary Redirect".
                The request method (e.g., "GET", "POST") is preserved.`,
  input: _ => (),
  responses: [
    s => {
      s.description("Temporary redirect to another URL.")
      // Use literal to hardcode the value
      let _ = s.redirect(S.literal("/new-destination"))
      // Or string schema to dynamically set it
      s.redirect(S.string)
    }
    s => {
      s.description("Bad request.")
      s.status(400)
    }
  ],
})
```

In a nutshell, the `redirect` function is a wrapper around `s.status(307)` and `s.header("location", schema)`.

## Fetch & Client

To call `Rest.fetch` you either need to explicitely pass a `client` as an argument or have it globally set.

I recommend to set a global client in the contract file:

```rescript
// Contract.res
Rest.setGlobalClient("http://localhost:3000")
```

If you pass the endpoint via environment variables, I recommend using my another library [rescript-envsafe](https://github.com/DZakh/rescript-envsafe):

```rescript
// PublicEnv.res
%%private(let envSafe = EnvSafe.make())

let apiEndpoint = envSafe->EnvSafe.get(
  "NEXT_PUBLIC_API_ENDPOINT",
  ~input=%raw(`process.env.NEXT_PUBLIC_API_ENDPOINT`),
  S.url(S.string),
)

envSafe->EnvSafe.close
```

```rescript
// Contract.res
Rest.setGlobalClient(PublicEnv.apiEndpoint)
```

If you can't or don't want to use a global client, you can manually pass it to the `Rest.fetch`:

```rescript
let client = Rest.client(PublicEnv.apiEndpoint)

await route->Rest.fetch(input, ~client)
```

This might be useful when you interact with multiple backends in a single application. For this case I recommend to have a separate contract file for every backend and include wrappers for fetch with already configured client:

```rescript
let client = Rest.client(PublicEnv.apiEndpoint)

let fetch = Rest.fetch(~client, ...)
```

### API Fetcher

You can override the client fetching logic by passing the `~fetcher` param.

## Client-side Integrations

### [SWR](https://swr.vercel.app/)

React Hooks for Data Fetching - With SWR, components will get a stream of data updates constantly and automatically.
And the UI will be always fast and reactive.

```sh
npm install rescript-rest swr
```

```rescript
@react.component
let make = () => {
  let posts = Contract.getPosts->Swr.use(~input={"skip": 0, "take": 10, "page": Some(1)})
  switch posts {
  | {error: Some(_)} => "Something went wrong!"->React.string
  | {data: None} => "Loading..."->React.string
  | {data: Some(posts)} => <Posts posts />
  }
}
```

It'll automatically refetch the data when the input parameters change. (⚠️ Currently supported only for `query` and `path` fields)

#### Polling

```rescript
Contract.getTodos->Swr.use(~input=(), ~options={ refreshInterval: 1000 })
```

#### Current Limitations

- Supports only `useSwr` hook with GET method routes
- Header field updates don't trigger refetching
- Please create a PR to extend available bindings

## Server-side Integrations

### [Next.js](https://nextjs.org/)

Next.js is a React framework for server-side rendering and static site generation.

Currently `rescript-rest` supports only page API handlers.

Start with defining your API contract:

```rescript
let getPosts = Rest.route(() => {
  path: "/getPosts",
  method: Get,
  input: _ => (),
  responses: [
    s => {
      s.status(200)
      s.data(S.array(postSchema))
    }
  ]
})
```

Create a `pages/api` directory and add a file `getPosts.res` with the following content:

```rescript
let default = Contract.getPosts->RestNextJs.handler(async ({input, req, res}) => {
  // Here's your logic
  []
})
```

Then you can call your API handler from the client:

```rescript
let posts = await Contract.getPosts->Rest.fetch()
```

#### Raw Body for Webhooks

To make Raw Body work with Next.js handler, you need to disable the automatic body parsing. One use case for this is to allow you to verify the raw body of a **webhook** request, for example [from Stripe](https://docs.stripe.com/webhooks).

> 🧠 This example uses another great library [ReScript Stripe](https://github.com/enviodev/rescript-stripe)

```rescript
let stripe = Stripe.make("sk_test_...")

let route = Rest.route(() => {
  path: "/api/stripe/webhook",
  method: Post,
  input: s => {
    "body": s.rawBody(S.string),
    "sig": s.header("stripe-signature", S.string),
  },
  responses: [
    s => {
      s.status(200)
      let _ = s.data(S.literal({"received": true}))
      Ok()
    },
    s => {
      s.status(400)
      Error(s.data(S.string))
    },
  ],
})

// Disable bodyParsing to make Raw Body work
let config: RestNextJs.config = {api: {bodyParser: false}}

let default = RestNextJs.handler(route, async ({input}) => {
  stripe
  ->Stripe.Webhook.constructEvent(
    ~body=input["body"],
    ~sig=input["sig"],
    // You can find your endpoint's secret in your webhook settings
    ~secret="whsec_...",
  )
  ->Result.map(event => {
    switch event {
    | CustomerSubscriptionCreated({data: {object: subscription}}) =>
      await processSubscription(subscription)
    | _ => ()
    }
  })
})
```

#### Current Limitations

- Doesn't support path parameters

### [Fastify](https://fastify.dev/)

Fastify is a fast and low overhead web framework, for Node.js. You can use it to implement your API server with `rescript-rest`.

To start, install `rescript-rest` and `fastify`:

```sh
npm install rescript-rest fastify
```

Then define your API contract:

```rescript
let getPosts = Rest.route(() => {...})
```

And implement it on the server side:

```rescript
let app = Fastify.make()

app->Fastify.route(Contract.getPosts, async ({input}) => {
  // Implementation where return type is promise<'response>
})

let _ = app->Fastify.listen({port: 3000})
```

> 🧠 `rescript-rest` ships with minimal bindings for Fastify to improve the integration experience. If you need more advanced configuration, please open an issue or PR.

#### Current Limitations

- Doesn't support array/object-like query params
- Has issues with paths with `:`

### OpenAPI Documentation with Fastify & Scalar

ReScript Rest ships with a plugin for [Fastify](https://github.com/fastify/fastify-swagger) to generate OpenAPI documentation for your API. Additionally, it also supports [Scalar](https://github.com/scalar/scalar/blob/main/packages/fastify-api-reference/README.md) which is a free, open-source, self-hosted API documentation tool.

To start, you need to additionally install `@fastify/swagger` which is used for OpenAPI generation. And if you want to host your documentation on a server, install `@scalar/fastify-api-reference` which is a nice and free OpenAPI UI:

```sh
npm install @fastify/swagger @scalar/fastify-api-reference
```

Then let's connect the plugins to our Fastify app:

```rescript
let app = Fastify.make()

// Set up @fastify/swagger
app->Fastify.register(
  Fastify.Swagger.plugin,
  {
    openapi: {
      openapi: "3.1.0",
      info: {
        title: "Test API",
        version: "1.0.0",
      },
    },
  },
)

app->Fastify.route(Contract.getPosts, async ({input}) => {
  // Implementation where return type is promise<'response>
})

// Render your OpenAPI reference with Scalar
app->Fastify.register(Fastify.Scalar.plugin, {routePrefix: "/reference"})

let _ = await app->Fastify.listen({port: 3000})

Console.log("OpenAPI reference: http://localhost:3000/reference")
```

Also, you can use the `Fastify.Swagger.generate` function to get the OpenAPI JSON.

## Useful Utils

### `Rest.url`

`Rest.url` is a helper function which builds a complete URL for a given route and input.

```rescript
let getPosts = Rest.route(() => {
  path: "/posts",
  method: Get,
  input: s => {
    "skip": s.query("skip", S.int),
    "take": s.query("take", S.int),
  },
  responses: [
    s => s.data(S.array(postSchema)),
  ],
})

let url = Rest.url(
  getPosts,
  {
    "skip": 0,
    "take": 10,
  }
) //? /posts?skip=0&take=10
```
