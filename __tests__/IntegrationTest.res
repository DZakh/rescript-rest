open RescriptSchema

module Promise = {
  type t<+'a> = promise<'a>

  @send
  external thenResolve: (t<'a>, 'a => 'b) => t<'b> = "then"
}

let userSchema = S.object(s =>
  {
    "userName": s.field("user_name", S.string),
  }
)

let createGame = Rest.route(() => {
  path: "/game",
  method: Post,
  variables: s => s.body(userSchema),
  responses: [
    s => {
      s.status(200)
      s.data(S.bool)
    },
  ],
})

let app = Fastify.make()
app->Fastify.route(createGame, async _variables => {
  true
})

let _ =
  app
  ->Fastify.listen({port: 3000})
  ->Promise.thenResolve(address => {
    let client = Rest.client(~baseUrl=address)

    let _ = client.call(createGame, %raw(`{"userName": 123}`))->Promise.thenResolve(response => {
      Js.log(response)
    })
  })
