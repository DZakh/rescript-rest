open Ava
open RescriptSchema

S.setGlobalConfig({
  defaultUnknownKeys: Strict,
})

let assertSchemaCode = (t, ~schema, code) => {
  t->Assert.is(
    (
      if schema->S.isAsync {
        let fn = schema->S.compile(~input=Any, ~output=Value, ~mode=Async, ~typeValidation=true)
        fn->Obj.magic
      } else {
        let fn = schema->S.compile(~input=Any, ~output=Value, ~mode=Sync, ~typeValidation=true)
        fn->Obj.magic
      }
    )["toString"](),
    code,
  )
}

let inject = async (app: Fastify.t, args: Rest.ApiFetcher.args): Rest.ApiFetcher.response => {
  let response = await app->Fastify.inject({
    url: args.path,
    method: args.method,
    body: args.body->Obj.magic,
    headers: args.headers->Obj.magic,
  })
  {
    data: response.json()->Obj.magic,
    status: response.statusCode,
    headers: response.headers->Obj.magic,
  }
}

asyncTest("Empty app", async t => {
  let app = Fastify.make()

  let response = await app->Fastify.inject({
    url: "/",
    method: "GET",
  })

  t->Assert.deepEqual(
    response.json(),
    %raw(`{
      "error": "Not Found",
      "message": "Route GET:/ not found",
      "statusCode": 404
    }`),
  )
})

asyncTest("Validation error on not providing body", async t => {
  let route = Rest.route(() => {
    path: "/",
    method: Post,
    input: s =>
      {
        "a": s.field("a", S.string),
      },
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  let app = Fastify.make()
  app->Fastify.route(route, async _input => true)

  let response = await app->Fastify.inject({
    url: "/",
    method: "POST",
  })

  t->Assert.deepEqual(
    response.json(),
    %raw(`{
      "error": "Bad Request",
      "message": "Failed parsing at [\"body\"]. Reason: Expected { a: string; }, received undefined",
      "statusCode": 400
    }`),
  )

  t->assertSchemaCode(
    ~schema=(route->Rest.params).inputSchema,
    `i=>{let v0=i["body"];if(!v0||v0.constructor!==Object){e[0](v0)}let v1=v0["a"],v2;if(typeof v1!=="string"){e[1](v1)}for(v2 in v0){if(v2!=="a"){e[2](v2)}}return {"a":v0["a"],}}`,
  )
  t->assertSchemaCode(
    ~schema=((route->Rest.params).responses->Js.Array2.unsafe_get(0)).schema,
    `i=>{let v0=i["data"];if(typeof v0!=="boolean"){e[0](v0)}return v0}`,
  )
})

asyncTest("Test simple POST request", async t => {
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
  app->Fastify.route(createGame, async ({input}) => {
    t->Assert.deepEqual(
      input,
      {
        "userName": "Dmitry",
      },
    )
    true
  })

  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/game",
        body: `{"user_name":"Dmitry"}`->Obj.magic,
        headers: %raw(`{"content-type": "application/json"}`),
        method: "POST",
      },
    )

    app->inject(args)
  })

  t->Assert.deepEqual(await client.call(createGame, {"userName": "Dmitry"}), true)

  // Returns validation error
  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => {
    app->inject(args)
  })
  await t->Assert.throwsAsync(
    client.call(createGame, %raw(`{"userName": 123}`)),
    ~expectations={
      message: `[rescript-rest] Unexpected response status "400". Message: Failed parsing at ["body"]["user_name"]. Reason: Expected string, received 123`,
    },
  )

  t->assertSchemaCode(
    ~schema=(createGame->Rest.params).inputSchema,
    `i=>{let v0=i["body"];if(!v0||v0.constructor!==Object){e[0](v0)}let v1=v0["user_name"],v2;if(typeof v1!=="string"){e[1](v1)}for(v2 in v0){if(v2!=="user_name"){e[2](v2)}}return {"userName":v1,}}`,
  )

  t->ExecutionContext.plan(5)
})

asyncTest("Test mixing s.body/s.data and s.field", async t => {
  t->ExecutionContext.plan(10)

  let data = {
    "id": 1,
    "user": {
      "userName": "Dmitry",
    },
    "after": "abc",
  }

  let userSchema = S.schema(s =>
    {
      "userName": s.matches(S.string),
    }
  )

  let createGame = Rest.route(() => {
    path: "/game",
    method: Post,
    input: s =>
      {
        "id": s.field("id", S.int),
        "user": s.body(userSchema),
        "after": s.field("after", S.string),
      },
    responses: [
      s => {
        s.status(200)
        {
          "id": s.field("id", S.int),
          "user": s.data(userSchema),
          "after": s.field("after", S.string),
        }
      },
    ],
  })

  let app = Fastify.make()
  app->Fastify.route(createGame, async ({input}) => {
    t->Assert.deepEqual(input, data)
    input
  })

  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/game",
        body: `{"id":1,"userName":"Dmitry","after":"abc"}`->Obj.magic,
        headers: %raw(`{"content-type": "application/json"}`),
        method: "POST",
      },
    )

    app->inject(args)
  })

  t->Assert.deepEqual(await client.call(createGame, data), data)

  t->assertSchemaCode(
    ~schema=(createGame->Rest.params).inputSchema,
    `i=>{let v0=i["body"];if(!v0||v0.constructor!==Object){e[0](v0)}let v1=v0["id"],v2=v0["userName"],v3=v0["after"],v4;if(typeof v1!=="number"||v1>2147483647||v1<-2147483648||v1%1!==0){e[1](v1)}if(typeof v2!=="string"){e[2](v2)}if(typeof v3!=="string"){e[3](v3)}for(v4 in v0){if(v4!=="id"&&v4!=="userName"&&v4!=="after"){e[4](v4)}}return {"id":v0["id"],"user":{"userName":v0["userName"],},"after":v0["after"],}}`,
  )
  t->assertSchemaCode(
    ~schema=((createGame->Rest.params).responses->Js.Array2.unsafe_get(0)).schema,
    `i=>{let v0=i["data"];if(!v0||v0.constructor!==Object){e[0](v0)}let v1=v0["id"],v2=v0["userName"],v3=v0["after"],v4;if(typeof v1!=="number"||v1>2147483647||v1<-2147483648||v1%1!==0){e[1](v1)}if(typeof v2!=="string"){e[2](v2)}if(typeof v3!=="string"){e[3](v3)}for(v4 in v0){if(v4!=="id"&&v4!=="userName"&&v4!=="after"){e[4](v4)}}return {"id":v0["id"],"user":{"userName":v0["userName"],},"after":v0["after"],}}`,
  )

  let failingCreateGame = Rest.route(() => {
    path: "/game",
    method: Post,
    input: s =>
      {
        "id": s.field("id", S.int),
        "user": s.body(S.object(s => {"userName": s.field("userName", S.string)})),
        "after": s.field("after", S.string),
      },
    responses: [s => s.status(200)],
  })
  t->Assert.throws(
    () => client.call(failingCreateGame, data),
    ~expectations={
      message: `[rescript-schema] The field "body" defined twice with incompatible schemas`,
    },
    ~message="Can't use s.field and s.body together with S.object schema",
  )

  let failingCreateGame = Rest.route(() => {
    path: "/game",
    method: Post,
    input: s =>
      {
        "id": s.field("id", S.int),
        "user": s.body(
          S.schema(s => {"userName": s.matches(S.string)})->S.transform(_ => {parser: v => v}),
        ),
        "after": s.field("after", S.string),
      },
    responses: [s => s.status(200)],
  })
  t->Assert.throws(
    () => client.call(failingCreateGame, data),
    ~expectations={
      message: `[rescript-schema] The field "body" defined twice with incompatible schemas`,
    },
    ~message="Can't use s.field and s.body together with S.schema->S.transform schema",
  )

  let failingCreateGame = Rest.route(() => {
    path: "/game",
    method: Post,
    input: s =>
      {
        "id": s.field("id", S.int),
        "user": {"userName": s.body(S.string)},
        "after": s.field("after", S.string),
      },
    responses: [s => s.status(200)],
  })
  t->Assert.throws(
    () => client.call(failingCreateGame, data),
    ~expectations={
      message: `[rescript-schema] The field "body" defined twice with incompatible schemas`,
    },
    ~message="Can't use s.field and s.body together with S.string schema",
  )

  let failingCreateGame = Rest.route(() => {
    path: "/game",
    method: Post,
    input: s =>
      {
        "id": s.field("id", S.int),
        "user": s.body(userSchema),
        "after": s.field("after", S.string),
      },
    responses: [
      s => {
        s.status(200)
        {
          "id": s.field("id", S.int),
          "user": s.data(S.object(s => {"userName": s.field("userName", S.string)})),
          "after": s.field("after", S.string),
        }
      },
    ],
  })
  t->Assert.throws(
    () => client.call(failingCreateGame, data),
    ~expectations={
      message: `[rescript-schema] The field "data" defined twice with incompatible schemas`,
    },
    ~message="Can't use s.field and s.data together with S.object schema",
  )

  let failingCreateGame = Rest.route(() => {
    path: "/game",
    method: Post,
    input: s =>
      {
        "id": s.field("id", S.int),
        "user": s.body(userSchema),
        "after": s.field("after", S.string),
      },
    responses: [
      s => {
        s.status(200)
        {
          "id": s.field("id", S.int),
          "user": {"userName": s.data(S.string)},
          "after": s.field("after", S.string),
        }
      },
    ],
  })
  t->Assert.throws(
    () => client.call(failingCreateGame, data),
    ~expectations={
      message: `[rescript-schema] The field "data" defined twice with incompatible schemas`,
    },
    ~message="Can't use s.field and s.data together with S.string schema",
  )
})

asyncTest("Integration test of simple POST request", async t => {
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
  app->Fastify.route(createGame, async ({input}) => {
    t->Assert.deepEqual(
      input,
      {
        "userName": "Dmitry",
      },
    )
    true
  })

  let address = await app->Fastify.listenFirstAvailableLocalPort
  t->ExecutionContext.teardown(() => app->Fastify.close)

  let client = Rest.client(~baseUrl=address)

  t->Assert.deepEqual(await client.call(createGame, {"userName": "Dmitry"}), true)

  t->ExecutionContext.plan(2)
})

asyncTest("Test request with mixed body and header data", async t => {
  let createGame = Rest.route(() => {
    path: "/game",
    method: Post,
    input: s =>
      {
        "userName": s.field("user_name", S.string),
        "version": s.header("X-Version", S.int),
      },
    responses: [
      s => {
        s.status(200)
        {
          "userName": s.field("user_name", S.string),
          "version": s.header("X-Version", S.int),
        }
      },
    ],
  })

  let app = Fastify.make()
  app->Fastify.route(createGame, async ({input}) => {
    t->Assert.deepEqual(
      input,
      {
        "userName": "Dmitry",
        "version": 1,
      },
    )
    input
  })

  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/game",
        body: `{"user_name":"Dmitry"}`->Obj.magic,
        headers: %raw(`{
          "content-type": "application/json",
          "x-version": 1
        }`),
        method: "POST",
      },
    )
    app->inject(args)
  })

  t->Assert.deepEqual(
    await client.call(createGame, {"userName": "Dmitry", "version": 1}),
    {"userName": "Dmitry", "version": 1},
  )

  t->ExecutionContext.plan(5)

  t->assertSchemaCode(
    ~schema=(createGame->Rest.params).inputSchema,
    `i=>{let v0=i["body"],v3=i["headers"];if(!v0||v0.constructor!==Object){e[0](v0)}let v1=v0["user_name"],v2;if(typeof v1!=="string"){e[1](v1)}for(v2 in v0){if(v2!=="user_name"){e[2](v2)}}let v4=e[3](v3["x-version"]);if(typeof v4!=="number"||v4>2147483647||v4<-2147483648||v4%1!==0){e[4](v4)}return {"userName":v0["user_name"],"version":v4,}}`,
  )
  t->assertSchemaCode(
    ~schema=((createGame->Rest.params).responses->Js.Array2.unsafe_get(0)).schema,
    `i=>{let v0=i["data"],v3=i["headers"];if(!v0||v0.constructor!==Object){e[0](v0)}let v1=v0["user_name"],v2;if(typeof v1!=="string"){e[1](v1)}for(v2 in v0){if(v2!=="user_name"){e[2](v2)}}let v4=e[3](v3["x-version"]);if(typeof v4!=="number"||v4>2147483647||v4<-2147483648||v4%1!==0){e[4](v4)}return {"userName":v0["user_name"],"version":v4,}}`,
  )
})

asyncTest("Test request with Bearer auth", async t => {
  let createGame = Rest.route(() => {
    path: "/game",
    method: Post,
    input: s =>
      {
        "userName": s.field("user_name", S.string),
        "bearer": s.auth(Bearer),
      },
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  let app = Fastify.make()
  app->Fastify.route(createGame, async ({input}) => {
    t->Assert.deepEqual(
      input,
      {
        "userName": "Dmitry",
        "bearer": "abc",
      },
    )
    true
  })

  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/game",
        body: `{"user_name":"Dmitry"}`->Obj.magic,
        headers: %raw(`{
          "content-type": "application/json",
          "authorization": "Bearer abc"
        }`),
        method: "POST",
      },
    )
    app->inject(args)
  })

  t->Assert.deepEqual(await client.call(createGame, {"userName": "Dmitry", "bearer": "abc"}), true)

  t->ExecutionContext.plan(3)
})

asyncTest("Test request with Basic auth", async t => {
  let createGame = Rest.route(() => {
    path: "/game",
    method: Post,
    input: s =>
      {
        "userName": s.field("user_name", S.string),
        "token": s.auth(Basic),
      },
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  let app = Fastify.make()
  app->Fastify.route(createGame, async ({input}) => {
    t->Assert.deepEqual(
      input,
      {
        "userName": "Dmitry",
        "token": "abc",
      },
    )
    true
  })

  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/game",
        body: `{"user_name":"Dmitry"}`->Obj.magic,
        headers: %raw(`{
          "content-type": "application/json",
          "authorization": "Basic abc"
        }`),
        method: "POST",
      },
    )
    app->inject(args)
  })

  t->Assert.deepEqual(await client.call(createGame, {"userName": "Dmitry", "token": "abc"}), true)

  t->ExecutionContext.plan(3)
})

asyncTest("Test simple GET request", async t => {
  let getHeight = Rest.route(() => {
    path: "/height",
    method: Get,
    input: _ => (),
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  let app = Fastify.make()
  app->Fastify.route(getHeight, async ({input}) => {
    t->Assert.deepEqual(input, ())
    true
  })

  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/height",
        body: None,
        headers: None,
        method: "GET",
      },
    )
    app->inject(args)
  })

  t->Assert.deepEqual(await client.call(getHeight, ()), true)

  t->ExecutionContext.plan(3)
})

let bigint: S.t<bigint> = S.custom("BigInt", s => {
  {
    parser: unknown => {
      if Js.typeof(unknown) !== "bigint" {
        s.fail("Expected bigint")
      } else {
        unknown->Obj.magic
      }
    },
    serializer: unknown => unknown,
  }
})

asyncTest("Test query params encoding to path", async t => {
  let getHeight = Rest.route(() => {
    path: "/height",
    method: Get,
    input: s =>
      {
        "string": s.query("string", S.string),
        "unit": s.query("unit", S.unit),
        "null": s.query("null", S.null(S.string)),
        "bool": s.query("bool", S.bool),
        "int": s.query("int", S.int),
        "bigint": s.query("bigint", bigint),
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
                "nestedNested": s.nested("nestedNested").field("field", S.string),
              },
          ),
        ),
      },
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  let input = {
    "string": "abc",
    "unit": (),
    "null": None,
    "bool": true,
    "int": 123,
    "bigint": 111n,
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
        path: "http://localhost:3000/height?string=abc&null=&bool=true&int=123&bigint=111&array[0]=a&array[1]=b&array[2]=c&nan=NaN&float=1.2&matrix[0][0]=a0&matrix[0][1]=a1&matrix[1][0]=b0&arrayOfObjects[0][field]=v0&arrayOfObjects[1][field]=v1&%3D%3D%3D=%3D%3D%3D&trueString=true&nested[nestedNested][field]=nv",
        body: None,
        headers: None,
        method: "GET",
      },
    )
    {data: true->Obj.magic, status: 200, headers: Js.Dict.empty()}
  })

  t->Assert.deepEqual(await client.call(getHeight, input), true)

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

  // BigInt is not supported by jsonQuery mode
  let _ = %raw(`delete input.bigint`)
  t->Assert.deepEqual(await jsonQueryClient.call(getHeight, input), true)

  t->ExecutionContext.plan(4)
})

asyncTest("Test query params support by Fastify", async t => {
  let getHeight = Rest.route(() => {
    path: "/height",
    method: Get,
    input: s =>
      {
        "string": s.query("string", S.string),
        "unit": s.query("unit", S.unit),
        // "null": s.query("null", S.null(S.string)),
        "bool": s.query("bool", S.bool),
        "int": s.query("int", S.int),
        // "array": s.query("array", S.array(S.string)),
        // "nan": s.query("nan", S.literal(%raw(`NaN`))),
        "float": s.query("float", S.float),
        // "matrix": s.query("matrix", S.array(S.array(S.string))),
        // "arrayOfObjects": s.query(
        //   "arrayOfObjects",
        //   S.array(S.object(s => s.field("field", S.string))),
        // ),
        "encoded": s.query("===", S.string),
        "trueString": s.query("trueString", S.literal("true")),
        // "nested": s.query(
        //   "nested",
        //   S.object(
        //     s =>
        //       {
        //         "unit": s.field("unit", S.unit),
        //         "nestedNested": s.nestedField("nestedNested", "field", S.string),
        //       },
        //   ),
        // ),
      },
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  let input = {
    "string": "abc",
    "unit": (),
    // "null": None,
    "bool": true,
    "int": 123,
    // "array": ["a", "b", "c"],
    // "nan": %raw(`NaN`),
    "float": 1.2,
    // "matrix": [["a0", "a1"], ["b0"]],
    // "arrayOfObjects": ["v0", "v1"],
    "encoded": "===",
    "trueString": "true",
    // "nested": {
    //   "unit": (),
    //   "nestedNested": "nv",
    // },
  }

  let app = Fastify.make()
  app->Fastify.route(getHeight, async ({input: resVariables}) => {
    t->Assert.deepEqual(resVariables, input)
    true
  })

  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/height?string=abc&bool=true&int=123&float=1.2&%3D%3D%3D=%3D%3D%3D&trueString=true",
        body: None,
        headers: None,
        method: "GET",
      },
    )
    app->inject(args)
  })

  t->Assert.deepEqual(await client.call(getHeight, input), true)

  let jsonQueryClient = Rest.client(
    ~baseUrl="http://localhost:3000",
    ~fetcher=async (args): Rest.ApiFetcher.response => {
      t->Assert.deepEqual(
        args,
        {
          path: "http://localhost:3000/height?string=abc&bool=true&int=123&float=1.2&%3D%3D%3D=%3D%3D%3D&trueString=%22true%22",
          body: None,
          headers: None,
          method: "GET",
        },
      )
      {data: true->Obj.magic, status: 200, headers: Js.Dict.empty()}
    },
    ~jsonQuery=true,
  )

  t->Assert.deepEqual(await jsonQueryClient.call(getHeight, input), true)

  t->ExecutionContext.plan(5)
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
          body: `{"title":"How to use ReScript Rest?","body":"Read the documentation on GitHub"}`->Obj.magic,
          headers: %raw(`{"content-type": "application/json"}`),
          method: "POST",
        },
      )
      let post = args.body->Obj.magic->Js.Json.parseExn->Obj.magic
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
    input: s =>
      {
        "title": s.field("title", S.string),
        "body": s.field("body", S.string),
      },
    responses: [
      s => {
        s.status(201)
        s.data(postSchema)
      },
    ],
  })

  let getPosts = Rest.route(() => {
    path: "/posts",
    method: Get,
    input: s =>
      {
        "skip": s.query("skip", S.int),
        "take": s.query("take", S.int),
        "page": s.header("x-pagination-page", S.option(S.int)),
      },
    responses: [
      s => {
        s.status(200)
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
  let getSubComment = Rest.route(() => {
    path: "/post/{id}/comments/{commentId}/{commentId2}",
    method: Get,
    input: s =>
      {
        "id": s.param("id", S.string),
        "commentId": s.param("commentId", S.int),
        "commentId2": s.param("commentId2", S.int),
      },
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  let app = Fastify.make()
  app->Fastify.route(getSubComment, async ({input}) => {
    t->Assert.deepEqual(
      input,
      {
        "id": "abc",
        "commentId": 1,
        "commentId2": 123,
      },
    )
    true
  })

  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/post/abc/comments/1/123",
        body: None,
        headers: None,
        method: "GET",
      },
    )
    app->inject(args)
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

  t->ExecutionContext.plan(3)
})

asyncTest("Fastify server works with path containing columns", async t => {
  let getSubComment = Rest.route(() => {
    path: "/post:2/{id:1}",
    method: Get,
    input: s =>
      {
        "id": s.param("id:1", S.string),
      },
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  let getSubComment2 = Rest.route(() => {
    path: "/postb/{id:1}",
    method: Get,
    input: s =>
      {
        "id": s.param("id:1", S.string),
      },
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  let app = Fastify.make()
  app->Fastify.route(getSubComment, async ({input}) => {
    t->Assert.deepEqual(
      input,
      {
        "id": "abc",
      },
    )
    true
  })

  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => {
    app->inject(args)
  })

  S.setGlobalConfig({
    defaultUnknownKeys: Strip,
  })
  // Otherwise it will fail in the CI because of concurrency
  let p = client.call(
    getSubComment,
    {
      "id": "abc",
    },
  )
  S.setGlobalConfig({
    defaultUnknownKeys: Strict,
  })

  t->Assert.deepEqual(await p, true)

  // FIXME: Should return 404
  t->Assert.deepEqual(
    await client.call(
      getSubComment2,
      {
        "id": "abc",
      },
    ),
    true,
  )

  t->ExecutionContext.plan(4)
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
    input: _ => (),
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
    input: _ => (),
    responses: [],
  })

  t->Assert.throws(
    () => client.call(getHeight, ()),
    ~expectations={
      message: `[rescript-rest] At least single response should be registered`,
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
    input: _ => (),
    responses: [
      s => {
        s.status(400)
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
    input: _ => (),
    responses: [
      s => {
        s.status(200)
        s.data(S.literal(true))
      },
      s => {
        s.status(400)
        s.data(S.literal(false))
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
    input: _ => (),
    responses: [
      s => {
        s.status(400)
        s.data(S.literal(false))
      },
      s => {
        s.data(S.literal(true))
      },
    ],
  })

  await t->Assert.throwsAsync(
    client.call(getHeight, ()),
    ~expectations={
      message: `[rescript-rest] Failed parsing response data. Reason: Expected true, received false`,
    },
  )
})

asyncTest("Test POST request with rawBody", async t => {
  let createGame = Rest.route(() => {
    path: "/game",
    method: Post,
    input: s => s.rawBody(S.string->S.to(s => Ok(s))),
    responses: [
      s => {
        s.data(S.bool)
      },
    ],
  })

  let app = Fastify.make()
  app->Fastify.route(createGame, async ({input}) => {
    t->Assert.deepEqual(input, Ok("[12, 123]"))
    true
  })

  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/game",
        body: `[12, 123]`->Obj.magic,
        headers: %raw(`{"content-type": "application/json"}`),
        method: "POST",
      },
    )

    app->inject(args)
  })

  t->Assert.deepEqual(await client.call(createGame, Ok("[12, 123]")), true)

  t->ExecutionContext.plan(3)
})

asyncTest("Test POST request with literal rawBody", async t => {
  let createGame = Rest.route(() => {
    path: "/game",
    method: Post,
    input: s => {
      let _ = s.rawBody(S.literal(`{"version": 1}`))
    },
    responses: [
      s => {
        s.data(S.bool)
      },
    ],
  })

  let app = Fastify.make()
  app->Fastify.route(createGame, async ({input}) => {
    t->Assert.deepEqual(input, ())
    true
  })

  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => {
    t->Assert.deepEqual(
      args,
      {
        path: "http://localhost:3000/game",
        body: `{"version": 1}`->Obj.magic,
        headers: %raw(`{"content-type": "application/json"}`),
        method: "POST",
      },
    )

    app->inject(args)
  })

  t->Assert.deepEqual(await client.call(createGame, ()), true)

  t->ExecutionContext.plan(3)
})

asyncTest("Fails when rawBody is not a string-based schema", async t => {
  let client = Rest.client(
    ~baseUrl="http://localhost:3000",
    ~fetcher=async (_): Rest.ApiFetcher.response => {
      {data: true->Obj.magic, status: 200, headers: Js.Dict.empty()}
    },
  )

  let getHeight = Rest.route(() => {
    path: "/height",
    method: Get,
    input: s => {
      s.rawBody(S.int)
    },
    responses: [],
  })

  t->Assert.throws(
    () => client.call(getHeight, 12),
    ~expectations={
      message: `[rescript-rest] Only string-based schemas are allowed in rawBody`,
    },
  )
})

asyncTest("Fastify works with routes having multiple responses", async t => {
  let getHeight = Rest.route(() => {
    path: "/height",
    method: Get,
    input: _ => (),
    responses: [
      s => {
        s.status(400)
        s.data(S.literal(false))
      },
      s => {
        s.data(S.literal(true))
      },
    ],
  })

  let app = Fastify.make()
  app->Fastify.route(getHeight, async ({input: ()}) => {
    true
  })
  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => app->inject(args))
  t->Assert.deepEqual(await client.call(getHeight, ()), true)
})

asyncTest("Sends response without a data", async t => {
  let getHeight = Rest.route(() => {
    path: "/height",
    method: Get,
    input: _ => (),
    responses: [_ => ()],
  })

  let app = Fastify.make()
  app->Fastify.route(getHeight, async _ => ())
  let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => app->inject(args))
  t->Assert.deepEqual(await client.call(getHeight, ()), ())
})

asyncTest("Graphql example https://x.com/ChShersh/status/1880968521200603364", async t => {
  let _issuesQuery = Rest.route(() => {
    path: "",
    method: Post,
    input: s => {
      let _ = s.header("Authorization", S.literal(`bearer ${%raw(`process.env.GITHUB_TOKEN`)}`))
      let _ = s.header("User-Agent", S.literal("chshersh/github-tui"))
      s.field(
        "query",
        S.string->S.transform(
          _ => {
            serializer: data =>
              `query {
                repository(owner: "${data["owner"]}", name: "${data["repo"]}") {
                  issues(first: 2, states: [OPEN], orderBy: {field: CREATED_AT, direction: DESC}) {
                    nodes {
                      number
                      title
                      author {
                        login
                      }
                    }
                  }
                }
              }`,
          },
        ),
      )
    },
    responses: [
      s =>
        s.data(
          S.object(
            s =>
              s.nested("data").nested("repository").nested("issues").fieldOr(
                "nodes",
                S.array(
                  S.object(
                    s =>
                      {
                        "number": s.field("number", S.int),
                        "title": s.field("title", S.string),
                        "author": s.nested("author").field("login", S.string),
                      },
                  ),
                ),
                [],
              ),
          ),
        ),
    ],
  })
  // let _issues = await Rest.fetch(
  //   _issuesQuery,
  //   "https://api.github.com/graphql",
  //   {
  //     "owner": "ChShersh",
  //     "repo": "status",
  //   },
  // )

  t->Assert.pass

  // let app = Fastify.make()
  // app->Fastify.route(getHeight, async () => ())
  // let client = Rest.client(~baseUrl="http://localhost:3000", ~fetcher=args => app->inject(args))
  // t->Assert.deepEqual(await client.call(getHeight, ()), ())
})
