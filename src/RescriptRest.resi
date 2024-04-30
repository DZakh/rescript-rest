type r = {}
type routeDefinition = {
  method: string,
  path: string,
}

type route
external route: (r => routeDefinition) => route = "%identity"
