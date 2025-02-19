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

## Tutorials

- Building and consuming REST API in ReScript with rescript-rest and Fastify ([YouTube](https://youtu.be/37FY6a-zY20?si=72zT8Gecs5vmDPlD))

## Super Simple Example

Easily define your API contract somewhere shared, for example, `Contract.res`:

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

Consume the API on the client with a RPC-like interface:

```rescript
let result = await Contract.getPosts->Rest.fetch(
  "http://localhost:3000",
  {
    "skip": 0,
    "take": 10,
    "page": Some(1),
  }
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

## Install

Install peer dependencies `rescript` ([instruction](https://rescript-lang.org/docs/manual/latest/installation)) and `rescript-schema` ([instruction](https://github.com/DZakh/rescript-schema/blob/main/docs/rescript-usage.md#install)).

Then run:

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

## Path Parameters

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

let result = await client.call(
  getPost,
  {
    "authorId": "d7fa3ac6-5bfa-4322-bb2b-317ca629f61c",
    "id": 1
  }
) // ℹ️ It'll do a GET request to http://localhost:3000/api/author/d7fa3ac6-5bfa-4322-bb2b-317ca629f61c/posts/1
```

If you would like to run validations or transformations on the path parameters, you can use [`rescript-schema`](https://github.com/DZakh/rescript-schema) features for this. Note that the parameter names in the `s.param` **must** match the parameter names in the `path` string.

## Query Parameters

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

let result = await client.call(
  getPosts,
  {
    "skip": 0,
    "take": 10,
  }
) // ℹ️ It'll do a GET request to http://localhost:3000/posts?skip=0&take=10
```

You can also configure rescript-rest to encode/decode query parameters as JSON by using the `jsonQuery` option. This allows you to skip having to do type coercions, and allow you to use complex and typed JSON objects.

## Request Headers

You can add headers to the request by using the `s.header` method in the `input` definition.

### Authentication header

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

let result = await client.call(
  getPosts,
  {
    "token": "abc",
    "pagination": 10,
  }
) // ℹ️ It'll do a GET request to http://localhost:3000/posts with the `{"authorization": "Bearer abc", "x-pagination": "10"}` headers
```

## Raw Body

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

let result = await client.call(
  getLogs,
  "debug"
) // ℹ️ It'll do a POST request to http://localhost:3000/logs with the body `{"size": 20, "query": {"bool": {"must": [{"terms": {"log.level": ["debug"]}}]}}}` and the headers `{"content-type": "application/json"}`
```

You can also use routes with `rawBody` on the server side with Fastify as any other route:

```rescript
app->Fastify.route(getLogs, async input => {
  // Do something with input and return response
})
```

> 🧠 Currently Raw Body is sent with the application/json Content Type. If you need support for other Content Types, please open an issue or PR.

## Responses

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

## Response Headers

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
let posts = await Contract.getPosts->Rest.fetch(
  "/api",
  ()
)
```

#### Current Limitations

- Doesn't support path parameters
- Doesn't support raw body

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

## Planned Features

- [x] Support query params
- [x] Support headers
- [x] Support path params
- [x] Implement type-safe response
- [ ] Support custom fetch options
- [ ] Support non-json body
- [x] Generate OpenAPI from Contract
- [ ] Generate Contract from OpenAPI
- [x] Server implementation with Fastify
- [ ] NextJs integration
- [ ] Add TS/JS support
