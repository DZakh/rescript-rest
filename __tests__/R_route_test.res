open Ava

test("foo", t => {
  let route = RescriptRest.route(_ => {
    path: "/height",
    method: "GET",
  })
  t->Assert.deepEqual(route, route)
})
