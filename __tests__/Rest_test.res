open Ava
open RescriptSchema

asyncTest("Test simple POST request", async t => {
  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=async (
    args
  ): Rest.ApiFetcher.response => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/game",
        body: %raw(`{"user_name":"Dmitry"}`),
        headers: None,
        method: "POST",
      },
    )
    {data: true->Obj.magic, status: 200, headers: Js.Dict.empty()}
  })

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
        s.status(#200)
        s.data(S.bool)
      },
    ],
  })

  t->Assert.deepEqual(await client.call(createGame, {"userName": "Dmitry"}), true)

  t->ExecutionContext.plan(2)
})

asyncTest("Test request with mixed body and header data", async t => {
  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=async (
    args
  ): Rest.ApiFetcher.response => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/game",
        body: %raw(`{"user_name":"Dmitry"}`),
        headers: Some(Js.Dict.fromArray([("X-Version", 1->Obj.magic)])),
        method: "POST",
      },
    )
    {
      data: args.body->Obj.magic,
      status: 200,
      headers: args.headers->Belt.Option.getWithDefault(Js.Dict.empty()),
    }
  })

  let createGame = Rest.route(() => {
    path: "/game",
    method: Post,
    variables: s =>
      {
        "userName": s.field("user_name", S.string),
        "version": s.header("X-Version", S.int),
      },
    responses: [
      s => {
        s.status(#200)
        {
          "userName": s.field("user_name", S.string),
          "version": s.header("X-Version", S.int),
        }
      },
    ],
  })

  t->Assert.deepEqual(
    await client.call(createGame, {"userName": "Dmitry", "version": 1}),
    {"userName": "Dmitry", "version": 1},
  )

  t->ExecutionContext.plan(2)
})

asyncTest("Test simple GET request", async t => {
  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=async (
    args
  ): Rest.ApiFetcher.response => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/height",
        body: None,
        headers: None,
        method: "GET",
      },
    )
    {data: true->Obj.magic, status: 200, headers: Js.Dict.empty()}
  })

  let getHeight = Rest.route(() => {
    path: "/height",
    method: Get,
    variables: _ => (),
    responses: [
      s => {
        s.status(#200)
        s.data(S.bool)
      },
    ],
  })

  t->Assert.deepEqual(await client.call(getHeight, ()), true)

  t->ExecutionContext.plan(2)
})

asyncTest("Test query params encoding to path", async t => {
  let getHeight = Rest.route(() => {
    path: "/height",
    method: Get,
    variables: s =>
      {
        "string": s.query("string", S.string),
        "unit": s.query("unit", S.unit),
        "null": s.query("null", S.null(S.string)),
        "bool": s.query("bool", S.bool),
        "int": s.query("int", S.int),
        "array": s.query("array", S.array(S.string)),
        "nan": s.query("nan", S.literal(%raw(`NaN`))),
        "float": s.query("float", S.float),
        "matrix": s.query("matrix", S.array(S.array(S.string))),
        "arrayOfObjects": s.query(
          "arrayOfObjects",
          S.array(S.object(s => s.field("field", S.string))),
        ),
        "encoded": s.query("===", S.string),
        "trueString": s.query("trueString", S.literal("true")),
        "nested": s.query(
          "nested",
          S.object(
            s =>
              {
                "unit": s.field("unit", S.unit),
                "nestedNested": s.nestedField("nestedNested", "field", S.string),
              },
          ),
        ),
      },
    responses: [
      s => {
        s.status(#200)
        s.data(S.bool)
      },
    ],
  })

  let variables = {
    "string": "abc",
    "unit": (),
    "null": None,
    "bool": true,
    "int": 123,
    "array": ["a", "b", "c"],
    "nan": %raw(`NaN`),
    "float": 1.2,
    "matrix": [["a0", "a1"], ["b0"]],
    "arrayOfObjects": ["v0", "v1"],
    "encoded": "===",
    "trueString": "true",
    "nested": {
      "unit": (),
      "nestedNested": "nv",
    },
  }

  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=async (
    args
  ): Rest.ApiFetcher.response => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/height?string=abc&null=&bool=true&int=123&array[0]=a&array[1]=b&array[2]=c&nan=NaN&float=1.2&matrix[0][0]=a0&matrix[0][1]=a1&matrix[1][0]=b0&arrayOfObjects[0][field]=v0&arrayOfObjects[1][field]=v1&%3D%3D%3D=%3D%3D%3D&trueString=true&nested[nestedNested][field]=nv",
        body: None,
        headers: None,
        method: "GET",
      },
    )
    {data: true->Obj.magic, status: 200, headers: Js.Dict.empty()}
  })

  t->Assert.deepEqual(await client.call(getHeight, variables), true)

  let jsonQueryClient = Rest.client(
    ~baseUrl="http://localhost:3000",
    ~fetcher=async (args): Rest.ApiFetcher.response => {
      t->Assert.deepEqual(
        args,
        {
          path: "http://localhost:3000/height?string=abc&null=null&bool=true&int=123&array=%5B%22a%22%2C%22b%22%2C%22c%22%5D&nan=null&float=1.2&matrix=%5B%5B%22a0%22%2C%22a1%22%5D%2C%5B%22b0%22%5D%5D&arrayOfObjects=%5B%7B%22field%22%3A%22v0%22%7D%2C%7B%22field%22%3A%22v1%22%7D%5D&%3D%3D%3D=%3D%3D%3D&trueString=%22true%22&nested=%7B%22nestedNested%22%3A%7B%22field%22%3A%22nv%22%7D%7D",
          body: None,
          headers: None,
          method: "GET",
        },
      )
      {data: true->Obj.magic, status: 200, headers: Js.Dict.empty()}
    },
    ~jsonQuery=true,
  )

  t->Assert.deepEqual(await jsonQueryClient.call(getHeight, variables), true)

  t->ExecutionContext.plan(4)
})

asyncTest("Example test", async t => {
  let posts = []
  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=async (
    args
  ): Rest.ApiFetcher.response => {
    if args.method === "POST" {
      t->Assert.deepEqual(
        args,
        {
          path: "http://localhost:3000/posts",
          body: %raw(`{"title":"How to use ReScript Rest?","body":"Read the documentation on GitHub"}`),
          headers: None,
          method: "POST",
        },
      )
      let post = args.body->Obj.magic
      let _ = posts->Js.Array2.push(post)
      {data: post->Obj.magic, status: 201, headers: Js.Dict.empty()}
    } else {
      t->Assert.deepEqual(
        args,
        {
          path: "http://localhost:3000/posts?skip=0&take=10",
          body: None,
          headers: %raw(`{"x-pagination-page": 1}`),
          method: "GET",
        },
      )
      {
        data: {"posts": posts, "total": posts->Js.Array2.length}->Obj.magic,
        status: 200,
        headers: Js.Dict.empty(),
      }
    }
  })

  let postSchema = S.object(s =>
    {
      "title": s.field("title", S.string),
      "body": s.field("body", S.string),
    }
  )

  let createPost = Rest.route(() => {
    path: "/posts",
    method: Post,
    variables: s =>
      {
        "title": s.field("title", S.string),
        "body": s.field("body", S.string),
      },
    responses: [
      s => {
        s.status(#201)
        s.data(postSchema)
      },
    ],
  })

  let getPosts = Rest.route(() => {
    path: "/posts",
    method: Get,
    variables: s =>
      {
        "skip": s.query("skip", S.int),
        "take": s.query("take", S.int),
        "page": s.header("x-pagination-page", S.option(S.int)),
      },
    responses: [
      s => {
        s.status(#200)
        {
          "posts": s.field("posts", S.array(postSchema)),
          "total": s.field("total", S.int),
        }
      },
    ],
  })

  t->Assert.deepEqual(
    await client.call(
      createPost,
      {
        "title": "How to use ReScript Rest?",
        "body": "Read the documentation on GitHub",
      },
    ),
    {
      "title": "How to use ReScript Rest?",
      "body": "Read the documentation on GitHub",
    },
  )

  t->Assert.deepEqual(
    await client.call(
      getPosts,
      {
        "skip": 0,
        "take": 10,
        "page": Some(1),
      },
    ),
    {
      "posts": [
        {
          "title": "How to use ReScript Rest?",
          "body": "Read the documentation on GitHub",
        },
      ],
      "total": 1,
    },
  )

  t->ExecutionContext.plan(4)
})

asyncTest("Multiple path params", async t => {
  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=async (
    args
  ): Rest.ApiFetcher.response => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/post/abc/comments/1/123",
        body: None,
        headers: None,
        method: "GET",
      },
    )
    {data: true->Obj.magic, status: 200, headers: Js.Dict.empty()}
  })

  let getSubComment = Rest.route(() => {
    path: "/post/{id}/comments/{commentId}/{commentId2}",
    method: Get,
    variables: s =>
      {
        "id": s.param("id", S.string),
        "commentId": s.param("commentId", S.int),
        "commentId2": s.param("commentId2", S.int),
      },
    responses: [
      s => {
        s.status(#200)
        s.data(S.bool)
      },
    ],
  })

  t->Assert.deepEqual(
    await client.call(
      getSubComment,
      {
        "id": "abc",
        "commentId": 1,
        "commentId2": 123,
      },
    ),
    true,
  )

  t->ExecutionContext.plan(2)
})

asyncTest("Fails to register two default responses", async t => {
  let client = Rest.client(
    ~baseUrl="http://localhost:3000",
    ~fetcher=async (_): Rest.ApiFetcher.response => {
      t->Assert.fail("Shouldn't be called")
    },
  )

  let getHeight = Rest.route(() => {
    path: "/height",
    method: Get,
    variables: _ => (),
    responses: [
      s => {
        s.data(S.bool)
      },
      s => {
        s.data(S.bool)
      },
    ],
  })

  t->Assert.throws(
    () => {
      client.call(getHeight, ())
    },
    ~expectations={
      message: "[rescript-rest] Response for the \"default\" status registered multiple times",
    },
  )
})

asyncTest("Fails when response is not registered", async t => {
  let client = Rest.client(
    ~baseUrl="http://localhost:3000",
    ~fetcher=async (_): Rest.ApiFetcher.response => {
      {data: true->Obj.magic, status: 200, headers: Js.Dict.empty()}
    },
  )

  let getHeight = Rest.route(() => {
    path: "/height",
    method: Get,
    variables: _ => (),
    responses: [],
  })

  await t->Assert.throwsAsync(
    client.call(getHeight, ()),
    ~expectations={
      message: "[rescript-rest] No registered responses for the status \"200\"",
    },
  )
})

asyncTest("Uses default response when explicit status is not defined", async t => {
  let client = Rest.client(
    ~baseUrl="http://localhost:3000",
    ~fetcher=async (_): Rest.ApiFetcher.response => {
      {data: true->Obj.magic, status: 200, headers: Js.Dict.empty()}
    },
  )

  let getHeight = Rest.route(() => {
    path: "/height",
    method: Get,
    variables: _ => (),
    responses: [
      s => {
        s.status(#400)
        s.data(S.literal(false))
      },
      s => {
        s.data(S.literal(true))
      },
    ],
  })

  t->Assert.deepEqual(await client.call(getHeight, ()), true)
})

asyncTest("Uses 2XX response when explicit status is not defined", async t => {
  let client = Rest.client(
    ~baseUrl="http://localhost:3000",
    ~fetcher=async (_): Rest.ApiFetcher.response => {
      {data: true->Obj.magic, status: 200, headers: Js.Dict.empty()}
    },
  )

  let getHeight = Rest.route(() => {
    path: "/height",
    method: Get,
    variables: _ => (),
    responses: [
      s => {
        s.status(#400)
        s.data(S.literal(false))
      },
      s => {
        s.status(#"2XX")
        s.data(S.literal(true))
      },
    ],
  })

  t->Assert.deepEqual(await client.call(getHeight, ()), true)
})

asyncTest("Fails with an invalid response data", async t => {
  let client = Rest.client(
    ~baseUrl="http://localhost:3000",
    ~fetcher=async (_): Rest.ApiFetcher.response => {
      {data: false->Obj.magic, status: 200, headers: Js.Dict.empty()}
    },
  )

  let getHeight = Rest.route(() => {
    path: "/height",
    method: Get,
    variables: _ => (),
    responses: [
      s => {
        s.status(#400)
        s.data(S.literal(false))
      },
      s => {
        s.data(S.literal(true))
      },
    ],
  })

  await t->Assert.throwsAsync(
    client.call(getHeight, ()),
    ~expectations={message: `Failed parsing at ["data"]. Reason: Expected true, received false`},
  )
})
