// Generated by ReScript, PLEASE EDIT WITH CARE
'use strict';

var Ava = require("ava").default;
var Rest = require("../src/Rest.res.js");
var S$RescriptSchema = require("rescript-schema/src/S.res.js");

Ava("Test simple POST request", (async function (t) {
        var client = Rest.client("http://localhost:3000", (async function (args) {
                t.deepEqual(args, {
                      body: {
                        TAG: "JsonString",
                        _0: "{\"user_name\":\"Dmitry\"}"
                      },
                      method: "POST",
                      path: "http://localhost:3000/game"
                    });
                return {
                        body: {
                          TAG: "JsonString",
                          _0: "true"
                        },
                        status: 200
                      };
              }));
        var createGame = function () {
          return {
                  method: "POST",
                  path: "/game",
                  schema: (function (s) {
                      return {
                              userName: s.field("user_name", S$RescriptSchema.string)
                            };
                    })
                };
        };
        t.deepEqual(await client.call(createGame, {
                  userName: "Dmitry"
                }), {
              body: {
                TAG: "JsonString",
                _0: "true"
              },
              status: 200
            });
        t.plan(2);
      }));

Ava("Test simple GET request", (async function (t) {
        var client = Rest.client("http://localhost:3000", (async function (args) {
                t.deepEqual(args, {
                      body: undefined,
                      method: "GET",
                      path: "http://localhost:3000/height"
                    });
                return {
                        body: {
                          TAG: "JsonString",
                          _0: "true"
                        },
                        status: 200
                      };
              }));
        var getHeight = function () {
          return {
                  method: "GET",
                  path: "/height",
                  schema: (function (param) {
                      
                    })
                };
        };
        t.deepEqual(await client.call(getHeight, undefined), {
              body: {
                TAG: "JsonString",
                _0: "true"
              },
              status: 200
            });
        t.plan(2);
      }));

/*  Not a pure module */
