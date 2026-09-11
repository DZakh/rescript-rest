const packageJson = require("./package.json");

module.exports = () => ({
  files: ["src/**/*.res.mjs"],
  tests: packageJson.ava.files,
  env: {
    type: "node",
  },
  debug: false,
  testFramework: "ava",
});
