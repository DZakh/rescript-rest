type return<'data> = {
  data: option<'data>,
  error: option<exn>,
  isLoading: bool,
  isValidating: bool,
  mutate: unknown,
}

let use: (Rest.route<'input, 'response>, ~input: 'input=?, ~baseUrl: string=?) => return<'response>
