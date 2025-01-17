// Generated by ReScript, PLEASE EDIT WITH CARE
'use strict';

var Rest = require("./Rest.res.js");
var Js_exn = require("rescript/lib/js/js_exn.js");
var JSONSchema = require("rescript-json-schema/src/JSONSchema.res.js");
var S$RescriptSchema = require("rescript-schema/src/S.res.js");
var Caml_js_exceptions = require("rescript/lib/js/caml_js_exceptions.js");

function route(app, restRoute, fn) {
  app.register(function (app, param, done) {
        var match = Rest.params(restRoute);
        var variablesSchema = match.variablesSchema;
        var pathItems = match.pathItems;
        var definition = match.definition;
        var url = "";
        for(var idx = 0 ,idx_finish = pathItems.length; idx < idx_finish; ++idx){
          var pathItem = pathItems[idx];
          url = typeof pathItem === "string" ? url + pathItem : url + ":" + pathItem.name;
        }
        var responseSchemas = [];
        var routeSchemaResponses = {};
        match.responses.forEach(function (r) {
              responseSchemas.push(r.schema);
              var status = r.status;
              var status$1 = status !== undefined ? status : "default";
              var content = {};
              var jsonSchema = JSONSchema.make(r.dataSchema);
              var tmp;
              tmp = jsonSchema.TAG === "Ok" ? jsonSchema._0 : Js_exn.raiseError("Failed to create JSON-Schema for response with status " + status$1 + ". Error: " + jsonSchema._0);
              content["application/json"] = {
                schema: tmp
              };
              routeSchemaResponses[status$1] = {
                description: r.description,
                content: content
              };
            });
        var responseSchema = S$RescriptSchema.union(responseSchemas);
        var routeSchema_description = definition.description;
        var routeSchema_summary = definition.summary;
        var routeSchema_deprecated = definition.deprecated;
        var routeSchema_response = routeSchemaResponses;
        var routeSchema = {
          description: routeSchema_description,
          summary: routeSchema_summary,
          deprecated: routeSchema_deprecated,
          response: routeSchema_response
        };
        var routeOptions_method = definition.method;
        var routeOptions_handler = function (request, reply) {
          var variables;
          try {
            variables = S$RescriptSchema.parseOrThrow(request, variablesSchema);
          }
          catch (raw_error){
            var error = Caml_js_exceptions.internalToOCamlException(raw_error);
            if (error.RE_EXN_ID === S$RescriptSchema.Raised) {
              reply.status(400);
              reply.send({
                    statusCode: 400,
                    error: "Bad Request",
                    message: S$RescriptSchema.$$Error.message(error._1)
                  });
              throw 0;
            }
            throw error;
          }
          return fn(variables).then(function (handlerReturn) {
                      var data = S$RescriptSchema.reverseConvertOrThrow(handlerReturn, responseSchema);
                      var headers = data.headers;
                      if (headers) {
                        reply.headers(headers);
                      }
                      reply.status((data.status || 200));
                      return data.data;
                    });
        };
        var routeOptions_schema = routeSchema;
        var routeOptions = {
          method: routeOptions_method,
          url: url,
          handler: routeOptions_handler,
          schema: routeOptions_schema
        };
        if (app.swagger) {
          var addSchemaFor = function ($$location) {
            var item = variablesSchema.t.fields[$$location];
            if (item === undefined) {
              return ;
            }
            var jsonSchema = JSONSchema.make(item.schema);
            if (jsonSchema.TAG !== "Ok") {
              return Js_exn.raiseError("Failed to create JSON-Schema for " + $$location + " of " + definition.method + " " + definition.path + " route. Error: " + jsonSchema._0);
            }
            routeSchema[$$location] = jsonSchema._0;
          };
          addSchemaFor("body");
          addSchemaFor("headers");
          addSchemaFor("params");
          addSchemaFor("query");
        }
        app.setValidatorCompiler(function (param) {
              return function (param) {
                return true;
              };
            });
        if (match.isRawBody) {
          app.addContentTypeParser("application/json", {
                parseAs: "string"
              }, (function (_req, data, done) {
                  done(null, data);
                }));
        }
        app.route(routeOptions);
        done();
      });
}

var Swagger = {};

var Scalar = {};

exports.route = route;
exports.Swagger = Swagger;
exports.Scalar = Scalar;
/* Rest Not a pure module */
