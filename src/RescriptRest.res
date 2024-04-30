type r = {}
type routeDefinition = {
  method: string,
  path: string,
}

type route = r => routeDefinition
external route: (r => routeDefinition) => route = "%identity"
