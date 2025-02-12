open Ava
open RescriptSchema

module Reply = {
  type t

  @send external status: (t, int) => t = "status"
  @send external send: (t, {..}) => t = "send"
}

let delay = milliseconds =>
  Js.Promise2.make((~resolve, ~reject as _) => {
    let _interval = Js.Global.setTimeout(_ => {
      resolve()
    }, milliseconds)
  })

@new external makeError: string => exn = "Error"

@send
external setErrorHandler: (
  Fastify.t,
  (~error: 'error, ~request: unknown, ~reply: Reply.t) => promise<unit>,
) => unit = "setErrorHandler"

asyncTest("Global errors are propagated properly", async t => {
  let failingRoute = Rest.route(() => {
    path: "/test",
    method: Get,
    input: _s => (),
    responses: [
      s => {
        s.status(200)
        s.data(S.bool)
      },
    ],
  })

  let app = Fastify.make()

  let callCount = ref(-1)

  app->Fastify.route(failingRoute, _input => {
    callCount := callCount.contents + 1
    switch callCount.contents {
    | 0 => Js.Exn.raiseError("Sync error")
    | 1 => delay(0)->Js.Promise2.then(_ => Js.Exn.raiseError("Async error"))
    | _ => {
        t->Assert.pass(~message="Should be called")
        raise(Not_found)
      } // Sync ReScript exception
    }
  })

  app->setErrorHandler(async (~error, ~request as _, ~reply) => {
    switch callCount.contents {
    | 0 => t->Assert.deepEqual(error, makeError("Sync error"))
    | 1 => t->Assert.deepEqual(error, makeError("Async error"))
    | _ =>
      t->Assert.deepEqual(
        error,
        {
          "RE_EXN_ID": "Not_found",
          "Error": makeError(""),
        }->Obj.magic,
        ~message="Fastify will add an Error field without a message with stacktrace.",
      )
    }
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

  t->ExecutionContext.plan(10)
})
