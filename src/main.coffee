# out: ../lib/main.js
module.exports = (samjs) ->
  files = require("./files")(samjs)
  plugin = {}
  plugin.name = files.name
  plugin.obj = files
  plugin.startup = files.startup
  return plugin
