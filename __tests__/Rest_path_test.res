open Ava
open RescriptSchema

let mockClient = () => {
  Rest.client("http://localhost:3000", ~fetcher=async (_): Rest.ApiFetcher.response => {
    Js.Exn.raiseError("Not implemented")
  })
}

asyncTest("Fails with path parameter not defined in input", async t => {
  let client = mockClient()

  let createGame = Rest.route(() => {
    path: "/game/{gameId}",
    method: Post,
    input: _ => (),
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  t->Assert.throws(
    () => {
      createGame->Rest.fetch((), ~client)
    },
    ~expectations={
      message: `[rescript-rest] Path parameter "gameId" is not defined in input`,
    },
  )
})

asyncTest("Fails with path parameter not defined in the path string", async t => {
  let client = mockClient()

  let createGame = Rest.route(() => {
    path: "/game",
    method: Post,
    input: s => s.param("gameId", S.string),
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  t->Assert.throws(
    () => {
      createGame->Rest.fetch("gameId", ~client)
    },
    ~expectations={
      message: `[rescript-rest] Path parameter "gameId" is not defined in the path`,
    },
  )
})

asyncTest("Fails with empty path parameter name", async t => {
  let client = mockClient()

  let createGame = Rest.route(() => {
    path: "/game/{}",
    method: Post,
    input: s => s.param("", S.string),
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  t->Assert.throws(
    () => {
      createGame->Rest.fetch("gameId", ~client)
    },
    ~expectations={
      message: `[rescript-rest] Path parameter name cannot be empty`,
    },
  )
})

asyncTest("Fails with path parameter missing closing curly bracket", async t => {
  let client = mockClient()

  let createGame = Rest.route(() => {
    path: "/game/{gameId",
    method: Post,
    input: s => s.param("", S.string),
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  t->Assert.throws(
    () => {
      createGame->Rest.fetch("gameId", ~client)
    },
    ~expectations={
      message: `[rescript-rest] Path contains an unclosed parameter`,
    },
  )
})

asyncTest("Fails with path parameter missing opening curly bracket", async t => {
  let client = mockClient()

  let createGame = Rest.route(() => {
    path: "/game/gameId}",
    method: Post,
    input: s => s.param("gameId", S.string),
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  t->Assert.throws(
    () => {
      createGame->Rest.fetch("gameId", ~client)
    },
    ~expectations={
      message: `[rescript-rest] Path parameter "gameId" is not defined in the path`,
    },
  )
})

asyncTest("Fails with path parameter switched open and close curly bracket", async t => {
  let client = mockClient()

  let createGame = Rest.route(() => {
    path: "/game/}gameId{",
    method: Post,
    input: s => s.param("gameId", S.string),
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  t->Assert.throws(
    () => {
      createGame->Rest.fetch("gameId", ~client)
    },
    ~expectations={
      message: `[rescript-rest] Path parameter is not enclosed in curly braces`,
    },
  )
})
