open Ava
open RescriptSchema

asyncTest("Test simple POST request", async t => {
  let client = Rest.client(~baseUrl="http://localhost:3000", ~api=async (
    args
  ): Rest.ApiFetcher.return => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/game",
        body: Some(JsonString(`{"user_name":"Dmitry"}`)),
        method: "POST",
      },
    )
    {body: JsonString("true"), status: 200}
  })

  let createGame = Rest.route(() => {
    path: "/game",
    method: "POST",
    schema: s =>
      {
        "userName": s.field("user_name", S.string),
      },
  })

  t->Assert.deepEqual(
    await client.call(createGame, ~variables={"userName": "Dmitry"}),
    {body: JsonString("true"), status: 200},
  )

  t->ExecutionContext.plan(2)
})

asyncTest("Test simple GET request", async t => {
  let client = Rest.client(~baseUrl="http://localhost:3000", ~api=async (
    args
  ): Rest.ApiFetcher.return => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/height",
        body: None,
        method: "GET",
      },
    )
    {body: JsonString("true"), status: 200}
  })

  let getHeight = Rest.route(() => {
    path: "/height",
    method: "GET",
    schema: _ => (),
  })

  t->Assert.deepEqual(
    await client.call(getHeight, ~variables=()),
    {body: JsonString("true"), status: 200},
  )

  t->ExecutionContext.plan(2)
})
