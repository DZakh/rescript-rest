@@uncurried

type options<'input, 'req, 'res> = {
  input: 'input,
  req: 'req,
  res: 'res,
}

let handler: (
  Rest.route<'input, 'response>,
  options<'input, 'req, 'res> => promise<'response>,
) => ('req, 'res) => promise<'reply>
