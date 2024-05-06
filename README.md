# ReScript Rest 😴

- **RPC-like client with no codegen**  
  Fully typed RPC-like client, with no need for code generation!

- **API design agnostic**  
  REST? HTTP-RPC? Your own custom hybrid? rescript-rest doesn't care!

- **First class DX**  
  Less unnecessary builds in monorepos, instant compile-time errors, and instantly view endpoint implementations through your IDEs "go to definition"

- **Small package size and tree-shakable routes**  
  Routes comple to simple functions which allows tree-shaking only possible with ReScript.

> ⚠️ **rescript-rest** is currently in Beta and has very limited list of features. Be aware of possible breaking changes ☺️

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

## Basic usage

Create `Contract.res` and define your routes:

```rescript
// Contract.res

let createGame = Rest.route(() => {
  path: "/game",
  method: "POST",
  schema: s => {
    "userName": s.field("user_name", S.string),
  },
})
```

> 🧠 Currently `rescript-rest` supports only `client`, but the idea is to reuse the file both for `client` and `server`.

Now you can use the contract to perform type-safe calls to your server:

```rescript
// Client.res

let client = Rest.client(~baseUrl="http://localhost:3000")

let _ = await client.call(Contract.createGame, ~variables={"userName": "Dmitry"})
```

## Planned features

- [ ] Support path params
- [ ] Implement type-safe response
- [ ] Support passing headers and fetch options
- [ ] Generate OpenAPI from Contract
- [ ] Generate Contract from OpenAPI
- [ ] Integrate with Fastify on server-side
