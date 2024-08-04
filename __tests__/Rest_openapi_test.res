open Ava
open RescriptSchema

let postSchema = S.object(s =>
  {
    "title": s.field("title", S.string),
    "published": s.field("published", S.bool),
  }
)

test("findPosts route to OpenAPI", t => {
  let findPosts = Rest.route(() => {
    path: "/posts",
    method: "GET",
    variables: s =>
      {
        "search": s.query("search", S.option(S.string)),
        "sortBy": s.query(
          "sortBy",
          S.option(S.union([S.literal(#title), S.literal(#date)]))->S.Option.getOr(#date),
        ),
        "sort": s.query(
          "sort",
          S.option(S.union([S.literal(#asc), S.literal(#desc)]))->S.Option.getOr(#desc),
        ),
        "obj": s.query("obj", S.object(s => s.field("a", S.string))),
      },
    responses: [
      s => {
        s.status(#200)
        s.data(S.array(postSchema))
      },
    ],
  })

  t->Assert.deepEqual(
    Rest.routeToOpenAPI(findPosts),
    %raw(`{
      operationId: 'findPosts',
      parameters: [
        {
          schema: {
            type: 'string',
            '$schema': 'http://json-schema.org/draft-07/schema#'
          },
          name: 'search',
          in: 'query'
        },
        {
          schema: {
            anyOf: [
              { type: 'string', const: 'title' },
              { type: 'string', const: 'date' }
            ],
            '$schema': 'http://json-schema.org/draft-07/schema#'
          },
          name: 'sortBy',
          in: 'query'
        },
        {
          schema: {
            anyOf: [
              { type: 'string', const: 'asc' },
              { type: 'string', const: 'desc' }
            ],
            '$schema': 'http://json-schema.org/draft-07/schema#'
          },
          name: 'sort',
          in: 'query'
        },
        {
          required: true,
          style: 'deepObject',
          schema: {
            type: 'object',
            properties: { a: { type: 'string' } },
            additionalProperties: true,
            required: [ 'a' ],
            '$schema': 'http://json-schema.org/draft-07/schema#'
          },
          name: 'obj',
          in: 'query'
        }
      ],
    }`),
  )
})

test("createPost route to OpenAPI", t => {
  let createPost = Rest.route(() => {
    path: "/posts",
    method: "POST",
    deprecated: true,
    variables: s =>
      {
        "title": s.field("title", S.string),
        "published": s.field("published", S.option(S.bool)),
      },
    responses: [
      s => {
        s.status(#200)
        s.data(postSchema)
      },
    ],
  })

  t->Assert.deepEqual(
    Rest.routeToOpenAPI(createPost),
    %raw(`{
      operationId: "createPost",
      deprecated: true,
      parameters: [],
    }`),
  )
})

test("auth route to OpenAPI", t => {
  let auth = Rest.route(() => {
    path: "/auth",
    method: "POST",
    variables: s =>
      {
        "clientId": s.header("x-client-id", S.string),
        "apiKey": s.header("x-api-key", S.string),
        "tenantId": s.header("x-tenant-id", S.option(S.string)),
      },
    responses: [
      s => {
        s.status(#200)
        s.data(S.string)
      },
    ],
  })

  t->Assert.deepEqual(
    Rest.routeToOpenAPI(auth),
    %raw(`{
      operationId: "auth",
      parameters: [],
    }`),
  )
})
