open RescriptSchema

module Promise = {
  type t<+'a> = promise<'a>

  @send
  external thenResolve: (t<'a>, 'a => 'b) => t<'b> = "then"
}

let main = async () => {
  let userSchema = S.object(s =>
    {
      "userName": s.field("user_name", S.string),
    }
  )

  let createGame = Rest.route(() => {
    path: "/game",
    method: Post,
    input: s => s.body(userSchema),
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

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

  app->Fastify.route(createGame, async _input => {
    true
  })

  app->Fastify.register(Fastify.Scalar.plugin, {routePrefix: "/reference"})

  let _ = await app->Fastify.listen({port: 3000})

  Js.log("OpenAPI reference: http://localhost:3000/reference")

  // let client = Rest.client(~baseUrl=address)
  // let _ = client.call(createGame, %raw(`{"userName": 123}`))->Promise.thenResolve(response => {
  //   Js.log(response)
  // })
}

let _ = main()
