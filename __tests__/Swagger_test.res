open Ava
open RescriptSchema

let getCleanedSwagger = async app => {
  await app->Fastify.ready
  let stripSymbols = %raw(`structuredClone`)
  stripSymbols(app->Fastify.Swagger.generate)
}

asyncTest("OpenAPI with a simple get request using rawBody", async t => {
  let app = Fastify.make()
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
  app->Fastify.route(
    Rest.route(
      () => {
        path: "/",
        method: Post,
        input: s => s.rawBody(S.string),
        responses: [
          s => {
            s.status(200)
            s.data(S.bool)
          },
        ],
      },
    ),
    async _ => true,
  )

  t->Assert.deepEqual(
    await app->getCleanedSwagger,
    %raw(`{
      "components": { "schemas": {} },
      "openapi": "3.1.0",
      "info": {
        "title": "Test API",
        "version": "1.0.0"
      },
      "paths": {
        "/": {
          "post": {
            "requestBody": { "content": { "application/json": { "schema": { "type": "string" } } } },
            "responses": {
              "200": {
                "description": "Default Response",
                "content": { "application/json": { "schema": { "type": "boolean" } } }
              }
            }
          }
        }
      }
    }`),
  )
})

asyncTest("OpenAPI with a simple post request using body", async t => {
  let app = Fastify.make()
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
  app->Fastify.route(
    Rest.route(
      () => {
        path: "/",
        method: Post,
        input: s => s.body(S.string),
        responses: [
          s => {
            s.status(200)
            s.data(S.bool)
          },
        ],
      },
    ),
    async _ => true,
  )

  t->Assert.deepEqual(
    await app->getCleanedSwagger,
    %raw(`{
      "components": { "schemas": {} },
      "openapi": "3.1.0",
      "info": {
        "title": "Test API",
        "version": "1.0.0"
      },
      "paths": {
        "/": {
          "post": {
            "requestBody": { "content": { "application/json": { "schema": { "type": "string" } } } },
            "responses": {
              "200": {
                "description": "Default Response",
                "content": { "application/json": { "schema": { "type": "boolean" } } }
              }
            }
          }
        }
      }
    }`),
  )
})

asyncTest("OpenAPI with a mulitiple reponses having description", async t => {
  let app = Fastify.make()
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
  app->Fastify.route(
    Rest.route(
      () => {
        path: "/",
        method: Post,
        input: s => s.body(S.string),
        responses: [
          s => {
            s.status(200)
            s.description("OK")
            s.data(S.bool)
          },
          s => {
            s.status(400)
            s.description("Not Ok")
            s.data(S.bool)
          },
          s => {
            s.status(404)
            s.data(S.literal(false))
          },
          s => {
            s.data(S.literal(true))
          },
        ],
      },
    ),
    async _ => true,
  )

  t->Assert.deepEqual(
    await app->getCleanedSwagger,
    %raw(`{
      "components": { "schemas": {} },
      "openapi": "3.1.0",
      "info": {
        "title": "Test API",
        "version": "1.0.0"
      },
      "paths": {
        "/": {
          "post": {
            "requestBody": { "content": { "application/json": { "schema": { "type": "string" } } } },
            "responses": {
              "200": {
                "description": "OK",
                "content": { "application/json": { "schema": { "type": "boolean" } } }
              },
              "400": {
                "description": "Not Ok",
                "content": { "application/json": { "schema": { "type": "boolean" } } }
              },
              "404": {
                "description": "Default Response",
                "content": { "application/json": { "schema": { "type": "boolean", "enum": [false] } } }
              },
              "default": {
                "description": "Default Response", // FIXME: Default Response looks wrong
                "content": { "application/json": { "schema": { "type": "boolean", "enum": [true] } } }
              }
            }
          }
        }
      }
    }`),
  )
})

asyncTest("OpenAPI with response not returning any data", async t => {
  let app = Fastify.make()
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
  app->Fastify.route(
    Rest.route(
      () => {
        path: "/",
        method: Post,
        input: s => s.body(S.string),
        responses: [
          s => {
            s.status(200)
            ()
          },
        ],
      },
    ),
    async _ => (),
  )

  t->Assert.deepEqual(
    await app->getCleanedSwagger,
    %raw(`{
      "components": { "schemas": {} },
      "openapi": "3.1.0",
      "info": {
        "title": "Test API",
        "version": "1.0.0"
      },
      "paths": {
        "/": {
          "post": {
            "requestBody": { "content": { "application/json": { "schema": { "type": "string" } } } },
            "responses": {
              "200": {
                "description": "Default Response",
                "content": { "application/json": { "schema": { "type": "null" } } }
              }
            }
          }
        }
      }
    }`),
  )
})

asyncTest("Route with all meta info and deprecated", async t => {
  let app = Fastify.make()
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
  app->Fastify.route(
    Rest.route(
      () => {
        description: "This is a description",
        summary: "This is a summary",
        deprecated: true,
        tags: ["Foo", "Bar"],
        externalDocs: {
          description: "External docs",
          url: "https://example.com",
        },
        operationId: "getNoop",
        path: "/",
        method: Post,
        input: _ => (),
        responses: [_ => ()],
      },
    ),
    async _ => (),
  )

  t->Assert.deepEqual(
    await app->getCleanedSwagger,
    %raw(`{
      "components": { "schemas": {} },
      "openapi": "3.1.0",
      "info": {
        "title": "Test API",
        "version": "1.0.0"
      },
      "paths": {
        "/": {
          "post": {
            "deprecated": true,
            "summary": "This is a summary",
            "description": "This is a description",
            "tags": ["Foo", "Bar"],
            "externalDocs": {
              "description": "External docs",
              "url": "https://example.com",
            },
            "operationId": "getNoop",
            "responses": {
              "default": {
                "description": "Default Response",
                "content": { "application/json": { "schema": { "type": "null" } } }
              }
            }
          }
        }
      }
    }`),
  )
})

asyncTest("OpenAPI with a complex request having different types", async t => {
  let app = Fastify.make()
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
  app->Fastify.route(
    Rest.route(
      () => {
        path: "/post/{id}",
        method: Post,
        input: s => {
          let _ = s.header("x-header", S.literal("foo"))
          let _ = s.param("id", S.literal(123))
          let _ = s.query("name", S.literal(true))
          s.body(S.string)
        },
        responses: [
          s => {
            s.status(200)
            s.data(S.bool)
          },
        ],
      },
    ),
    async _ => true,
  )

  t->Assert.deepEqual(
    await app->getCleanedSwagger,
    %raw(`{
      "components": { "schemas": {} },
      "openapi": "3.1.0",
      "info": {
        "title": "Test API",
        "version": "1.0.0"
      },
      "paths": {
        "/post/{id}": {
          "post": {
            "parameters": [
              { "in": 'query',
                "name": 'name',
                "required": true,
                "schema": { "enum": [ true ], "type": 'boolean' } },
              { "in": 'path',
                "name": 'id',
                "required": true,
                "schema": { "enum": [ 123 ], "type": 'integer' } }, // TODO: Verify whether integer is valid in OpenAPI
              { "in": 'header',
                "name": 'x-header',
                "required": true,
                "schema": { "enum": [ 'foo' ], "type": 'string' } },
            ],
            "requestBody": { "content": { "application/json": { "schema": { "type": "string" } } } },
            "responses": {
              "200": {
                "description": "Default Response",
                "content": { "application/json": { "schema": { "type": "boolean" } } }
              }
            }
          }
        }
      }
    }`),
  )
})
