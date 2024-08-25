[![CI](https://github.com/DZakh/rescript-rest/actions/workflows/ci.yml/badge.svg)](https://github.com/DZakh/rescript-rest/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/DZakh/rescript-rest/branch/main/graph/badge.svg?token=40G6YKKD6J)](https://codecov.io/gh/DZakh/rescript-rest)

<!-- [![npm](https://img.shields.io/npm/dm/rescript-rest)](https://www.npmjs.com/package/rescript-rest) -->

# ReScript Rest 😴

- **RPC-like client with no codegen**  
  Fully typed RPC-like client, with no need for code generation!

- **API design agnostic**  
  REST? HTTP-RPC? Your own custom hybrid? rescript-rest doesn't care!

- **First class DX**  
  Less unnecessary builds in monorepos, instant compile-time errors, and instantly view endpoint implementations through your IDEs "go to definition"

- **Small package size and tree-shakable routes**  
  Routes comple to simple functions which allows tree-shaking only possible with ReScript.

> ⚠️ **rescript-rest** relies on **rescript-schema** which uses `eval` for parsing. It's usually fine but might not work in some environments like Cloudflare Workers or third-party scripts used on pages with the [script-src](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/script-src) header.

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

## Super Simple Example

Easily define your API contract somewhere shared, for example, `Contract.res`:

```rescript
let getPosts = Rest.route(() => {
  path: "/posts",
  method: Get,
  variables: s => {
    "skip": s.query("skip", S.int),
    "take": s.query("take", S.int),
    "page": s.header("x-pagination-page", S.option(S.int)),
  },
  responses: [
    s => {
      s.status(#200)
      s.field("posts", S.array(postSchema))
    },
  ],
})
```

Consume the API on the client with a RPC-like interface:

```rescript
let client = Rest.client(~baseUrl="http://localhost:3000")

let result = await client.call(
  Contract.getPosts,
  {
    "skip": 0,
    "take": 10,
    "page": Some(1),
  }
  // ^-- Fully typed!
) // ℹ️ It'll do a GET request to http://localhost:3000/posts?skip=0&take=10 with the `{"x-pagination-page": "1"}` headers
```

Fulfil the contract on your sever, with a type-safe Fasitfy integration:

```rescript
let app = Fastify.make()

app->Fastify.route(Contract.getPosts, variables => {
  queryPosts(~skip=variables["skip"], ~take=variables["take"], ~page=variables["page"])
})
// ^-- Both variables and return value are fully typed!

let _ = app->Fastify.listen({port: 3000})
```

**Examples from public repositories:**

- [Cli App Rock-Paper-Scissors](https://github.com/Nicolas1st/net-cli-rock-paper-scissors/blob/main/apps/client/src/Api.res)

## Path Parameters

You can define path parameters by adding them to the `path` strin with a curly brace `{}` including the parameter name. Then each parameter must be defined in `variables` with the `s.param` method.

```rescript
let getPost = Rest.route(() => {
  path: "/api/author/{authorId}/posts/{id}",
  method: Get,
  variables: s => {
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

You can add query parameters to the request by using the `s.query` method in the `variables` definition.

```rescript
let getPosts = Rest.route(() => {
  path: "/posts",
  method: Get,
  variables: s => {
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

You can add headers to the request by using the `s.header` method in the `variables` definition.

```rescript
let getPosts = Rest.route(() => {
  path: "/posts",
  method: Get,
  variables: s => {
    "authorization": s.header("authorization", S.string),
    "pagination": s.header("pagination", S.option(S.int)),
  },
  responses: [
    s => s.data(S.array(postSchema)),
  ],
})
```

## Responses

Responses are described as an array of response definitions. It's possible to assign the definition to a specific status using `s.status` method.

```rescript
let createPost = Rest.route(() => {
  path: "/posts",
  method: Post,
  variables: _ => (),
  responses: [
    s => {
      s.status(#201)
      Ok(s.data(postSchema))
    },
    s => {
      s.status(#404)
      Error(s.field("message", S.string))
    },
  ],
})
```

You can use `s.status` multiple times. To define a range of response statuses, you may use `1XX`, `2XX`, `3XX`, `4XX` and `5XX`. If `s.status` is not used in a response definition, it'll be treated as a `default` case, accepting a response with any status code.

```rescript
let createPost = Rest.route(() => {
  path: "/posts",
  method: Post,
  variables: _ => (),
  responses: [
    s => {
      s.status(#201)
      Ok(s.data(postSchema))
    },
    s => {
      s.status(#404)
      Error(s.field("message", S.string))
    },
    s => {
      s.status(#"5XX")
      Error("Server Error")
    },
    s => Error("Unexpected Error"),
  ],
})
```

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
  variables: _ => (),
  responses: [
    s => {
      s.status(#200)
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

## Server Implementation

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

app->Fastify.route(Contract.getPosts, async variables => {
  // Implementation where return type is promise<'response>
})

let _ = app->Fastify.listen({port: 3000})
```

> 🧠 `rescript-rest` ships with minimal bindings for Fastify to improve the integration experience. If you need more advanced configuration, please open an issue or PR.

#### Known Limitations

- Currently supports routes only with a single response definition
- Doesn't support array/object-like query params
- Has issues with paths with `:`

## Planned Features

- [x] Support query params
- [x] Support headers
- [x] Support path params
- [x] Implement type-safe response
- [ ] Support custom fetch options
- [ ] Support non-json body
- [ ] Generate OpenAPI from Contract
- [ ] Generate Contract from OpenAPI
- [x] Server implementation with Fastify
- [ ] NextJs integration
- [ ] Add TS/JS support
