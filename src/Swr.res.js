// Generated by ReScript, PLEASE EDIT WITH CARE
'use strict';

var Swr = require("swr").default;
var Rest = require("./Rest.res.js");
var Js_exn = require("rescript/lib/js/js_exn.js");
var Belt_Option = require("rescript/lib/js/belt_Option.js");
var Caml_option = require("rescript/lib/js/caml_option.js");

function use(route, input, options, client) {
  var match = Rest.params(route);
  if (match.method !== "GET") {
    Js_exn.raiseError("[rescript-rest] Only GET requests are supported by Swr");
  }
  return Swr(input !== undefined ? Rest.url(route, Caml_option.valFromOption(input), client !== undefined ? client.baseUrl : undefined) : null, (function (param) {
                return Rest.$$fetch(route, Belt_Option.getExn(input), client);
              }), options !== undefined ? Caml_option.valFromOption(options) : undefined);
}

exports.use = use;
/* swr Not a pure module */
