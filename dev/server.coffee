samjs = require "samjs"
path = require "path"
server = require "vue-dev-server"
fs = samjs.Promise.promisifyAll(require("fs"))
testConfigFile = "test/testConfig.json"
koa = server(koa:true)
koa.middleware.unshift(require("../src/koa-middleware.coffee")(samjs))

server = require("http").createServer(koa.callback())
fs.unlinkAsync testConfigFile
.catch -> return true
.finally ->
  samjs
  .plugins([
    require("../src/main.coffee")
    ])
  .options({config:testConfigFile})
  .configs()
  .models({
    name: "test"
    db: "files"
    cwd: "test"
    folders: "./"
    write: true
    read: true
  })
  .startup(server)
  samjs.state.onceStarted
  .then ->
    server.listen 8080
