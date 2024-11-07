open Ava
open RescriptSchema

asyncTest("OpenAPI with a simple get request using rawBody", async t => {
  let app = Fastify.make()
  app->Fastify.register(Fastify.Swagger.plugin, {openapi: {}})
  app->Fastify.route(
    Rest.route(
      () => {
        path: "/",
        method: Post,
        variables: s => s.rawBody(S.string),
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

  await app->Fastify.ready

  t->Assert.deepEqual(
    app->Fastify.Swagger.generate,
    %raw(`{
      "components": { "schemas": {} },
      "openapi": "3.0.3",
      "info": {
        "title": "@fastify/swagger",
        "version": "9.2.0"
      },
      "paths": {
        "/": {
          "post": {
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
  app->Fastify.register(Fastify.Swagger.plugin, {openapi: {}})
  app->Fastify.route(
    Rest.route(
      () => {
        path: "/",
        method: Post,
        variables: s => s.body(S.string),
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

  await app->Fastify.ready

  t->Assert.deepEqual(
    app->Fastify.Swagger.generate,
    %raw(`{
      "components": { "schemas": {} },
      "openapi": "3.0.3",
      "info": {
        "title": "@fastify/swagger",
        "version": "9.2.0"
      },
      "paths": {
        "/": {
          "post": {
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
  app->Fastify.register(Fastify.Swagger.plugin, {openapi: {}})
  app->Fastify.route(
    Rest.route(
      () => {
        path: "/",
        method: Post,
        variables: s => s.body(S.string),
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

  await app->Fastify.ready

  t->Assert.deepEqual(
    app->Fastify.Swagger.generate,
    %raw(`{
      "components": { "schemas": {} },
      "openapi": "3.0.3",
      "info": {
        "title": "@fastify/swagger",
        "version": "9.2.0"
      },
      "paths": {
        "/": {
          "post": {
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
  app->Fastify.register(Fastify.Swagger.plugin, {openapi: {}})
  app->Fastify.route(
    Rest.route(
      () => {
        path: "/",
        method: Post,
        variables: s => s.body(S.string),
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

  await app->Fastify.ready

  t->Assert.deepEqual(
    app->Fastify.Swagger.generate,
    %raw(`{
      "components": { "schemas": {} },
      "openapi": "3.0.3",
      "info": {
        "title": "@fastify/swagger",
        "version": "9.2.0"
      },
      "paths": {
        "/": {
          "post": {
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
