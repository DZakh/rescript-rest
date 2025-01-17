open Ava
open RescriptSchema

module Reply = {
  type t

  @send external status: (t, int) => t = "status"
  @send external send: (t, {..}) => t = "send"
}

@send
external setErrorHandler: (
  Fastify.t,
  (~error: Js.Exn.t, ~request: unknown, ~reply: Reply.t) => promise<unit>,
) => unit = "setErrorHandler"

asyncTest("Global errors are propagated properly", async t => {
  let failingRoute = Rest.route(() => {
    path: "/test",
    method: Get,
    variables: _s => (),
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  let app = Fastify.make()

  app->Fastify.route(failingRoute, async _variables => {
    Js.Exn.raiseError("Test error")
  })

  app->setErrorHandler(async (~error as _, ~request as _, ~reply) => {
    let _ = reply->Reply.status(500)->Reply.send({"message": "Internal server error."})
  })

  let res = await app->Fastify.inject({
    url: "/test",
    method: "GET",
  })

  t->Assert.is(res.statusCode, 500)
  t->Assert.deepEqual(
    res.json(),
    %raw(`{
      "message": "Internal server error."
    }`),
  )
})
