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
        headers: Some(Js.Dict.fromArray([("X-Version", 1->Obj.magic)])),
        method: "POST",
      },
    )
    {body: JsonString("true"), status: 200}
  })

  let createGame = Rest.route(() => {
    path: "/game",
    method: "POST",
    variables: s =>
      {
        "userName": s.field("user_name", S.string),
        "version": s.header("X-Version", S.int),
      },
  })

  t->Assert.deepEqual(
    await client.call(createGame, ~variables={"userName": "Dmitry", "version": 1}),
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
        headers: None,
        method: "GET",
      },
    )
    {body: JsonString("true"), status: 200}
  })

  let getHeight = Rest.route(() => {
    path: "/height",
    method: "GET",
    variables: _ => (),
  })

  t->Assert.deepEqual(
    await client.call(getHeight, ~variables=()),
    {body: JsonString("true"), status: 200},
  )

  t->ExecutionContext.plan(2)
})
