// Generated by ReScript, PLEASE EDIT WITH CARE
'use strict';

var Rest = require("./Rest.res.js");
var Js_exn = require("rescript/lib/js/js_exn.js");
var JSONSchema = require("rescript-json-schema/src/JSONSchema.res.js");
var S$RescriptSchema = require("rescript-schema/src/S.res.js");
var Caml_js_exceptions = require("rescript/lib/js/caml_js_exceptions.js");

function route(app, restRoute, fn) {
  app.register(function (app, param, done) {
        var params = Rest.params(restRoute);
        var outputSchema = params.outputSchema;
        var inputSchema = params.inputSchema;
        var pathItems = params.pathItems;
        var url = "";
        for(var idx = 0 ,idx_finish = pathItems.length; idx < idx_finish; ++idx){
          var pathItem = pathItems[idx];
          url = typeof pathItem === "string" ? url + pathItem : url + ":" + pathItem.name;
        }
        var routeSchemaResponses = {};
        params.responses.forEach(function (r) {
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
        var routeSchema_description = params.description;
        var routeSchema_summary = params.summary;
        var routeSchema_deprecated = params.deprecated;
        var routeSchema_response = routeSchemaResponses;
        var routeSchema_operationId = params.operationId;
        var routeSchema_tags = params.tags;
        var routeSchema_externalDocs = params.externalDocs;
        var routeSchema = {
          description: routeSchema_description,
          summary: routeSchema_summary,
          deprecated: routeSchema_deprecated,
          response: routeSchema_response,
          operationId: routeSchema_operationId,
          tags: routeSchema_tags,
          externalDocs: routeSchema_externalDocs
        };
        var routeOptions_method = params.method;
        var routeOptions_handler = function (request, reply) {
          var input;
          try {
            input = S$RescriptSchema.parseOrThrow(request, inputSchema);
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
          return fn({
                        input: input
                      }).then(function (implementationResult) {
                      var data = S$RescriptSchema.reverseConvertOrThrow(implementationResult, outputSchema);
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
            var item = inputSchema.t.fields[$$location];
            if (item === undefined) {
              return ;
            }
            var jsonSchema = JSONSchema.make(item.schema);
            if (jsonSchema.TAG !== "Ok") {
              return Js_exn.raiseError("Failed to create JSON-Schema for " + $$location + " of " + params.method + " " + params.path + " route. Error: " + jsonSchema._0);
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
        if (params.isRawBody) {
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
