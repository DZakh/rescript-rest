const packageJson = require("./package.json");

module.exports = () => ({
  files: ["src/**/*.res.js"],
  tests: packageJson.ava.files,
  env: {
    type: "node",
  },
  debug: false,
  testFramework: "ava",
});
