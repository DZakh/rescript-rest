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
              }
            }
          }
        }
      }
    }`),
  )
})
