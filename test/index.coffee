chai = require "chai"
should = chai.should()
samjs = require "samjs"
samjsClient = require "samjs-client"
samjsFiles = require "../src/main"
samjsFilesClient = require "samjs-files-client"
samjsAuth = require "samjs-auth"
samjsAuthClient = require "samjs-auth-client"
fs = samjs.Promise.promisifyAll(require("fs"))
path = require "path"
port = 3060
url = "http://localhost:"+port+"/"
testConfigFile = "test/testConfig.json"

testModel =
  name: "test"
  db: "files"
  files: testConfigFile
testModel2 =
  name: "test2"
  db: "files"
  files: testConfigFile+"2"
  write: "root"
  read: "root"
testModel3 =
  name: "test3"
  db: "files"
  files:
    path: testConfigFile+"3"
    write: "root"
    read: "root"
testModel4 =
  name: "testMultipleFiles"
  db: "files"
  files: [testConfigFile,testConfigFile+"2"]
testModel5 =
  name: "testCWD"
  db: "files"
  options: cwd: "test"
  files: "testConfig.json4"
unlink = (file) ->
  fs.unlinkAsync file
  .catch -> return true
reset = (done) ->
  samjs.reset()
  unlink testConfigFile
  .finally ->
    done()
shutdown = (done) ->

  promises = [unlink(testConfigFile),unlink(testConfigFile+"2"),unlink(testConfigFile+"3"),unlink(testConfigFile+"4")]
  promises.push samjs.shutdown() if samjs.shutdown?
  samjs.Promise.all promises
  .then -> done()

describe "samjs", ->
  client = null
  clientTest = null
  describe "files", ->
    before reset
    after shutdown
    it "should be accessible", ->
      samjs.plugins(samjsFiles)
      should.exist samjs.files
    it "should startup", (done) ->
      samjs.options({config:testConfigFile})
      .configs()
      .models(testModel,testModel4,testModel5)
      .startup().io.listen(port)
      client = samjsClient({
        url: url
        ioOpts:
          reconnection: false
          autoConnect: false
        })()
      samjs.state.onceStarted.then -> done()
      .catch done
    describe "model", ->
      model = null
      it "should exist", ->
        model = samjs.models[testModel.name]
        should.exist model
      it "should be able to _set and _get", (done) ->
        model._set "{test:test}"
        .then (file) ->
          stats = fs.statSync file.fullpath
          stats.isFile().should.be.true
          model._get()
        .then (result) ->
          result.should.equal "{test:test}"
          done()
        .catch done
      it "should be able to hook up", (done) ->
        finished = ->
          remover()
          done()
        remover = model.addHook "after_Set", (file) ->
          file.path.should.equal testConfigFile

          finished()
          return file
        model._set "{test:test}"
        .catch done
      describe "client", ->
        clientTest = null
        it "should plugin", ->
          client.plugins(samjsFilesClient)
          should.exist client.Files
        it "should set", (done) ->
          clientTest = new client.Files("test")
          clientTest.set "{test2:test}"
          .then -> done()
          .catch done
        it "should get", (done) ->
          clientTest.get()
          .then (response) ->
            response.should.equal "{test2:test}"
            done()
          .catch done
    describe "model with multiple files", ->
      model4 = null
      it "should exist", ->
        model4 = samjs.models[testModel4.name]
        should.exist model4
      it "should be able to _set and _get", (done) ->
        model4._set testConfigFile+"2","{test:test}"
        .then (file) ->
          stats = fs.statSync file.fullpath
          stats.isFile().should.be.true
          model4._get(testConfigFile+"2")
        .then (result) ->
          result.should.equal "{test:test}"
          done()
        .catch done
      describe "client", ->
        clientTest = null
        it "should plugin", ->
          client.plugins(samjsFilesClient)
          should.exist client.Files
        it "should set", (done) ->
          clientTest = new client.Files("testMultipleFiles")
          clientTest.set path:testConfigFile+"2",data:"{test2:test}"
          .then -> done()
          .catch done
        it "should get", (done) ->
          clientTest.get(testConfigFile+"2")
          .then (response) ->
            response.should.equal "{test2:test}"
            done()
          .catch done
    describe "model with cwd", ->
      model5 = null
      it "should exist", ->
        model5 = samjs.models[testModel5.name]
        should.exist model5
      it "should be able to _set and _get", (done) ->
        model5._set "{test:test}"
        .then (file) ->
          stats = fs.statSync path.resolve(testConfigFile+"4")
          stats.isFile().should.be.true
          model5._get()
        .then (result) ->
          result.should.equal "{test:test}"
          done()
        .catch done
  describe "files+auth", ->
    before reset
    after shutdown
    it "should be accessible", ->
      samjs.plugins(samjsAuth,samjsFiles)
      should.exist samjs.files
      should.exist samjs.auth
    it "should install", (done) ->
      samjs.options({config:testConfigFile})
      .configs()
      .models(testModel,testModel2,testModel3)
      .startup().io.listen(port)
      client = samjsClient({
        url: url
        ioOpts:
          reconnection: false
          autoConnect: false
        })()
      client.plugins(samjsAuthClient,samjsFilesClient)
      client.auth.createRoot name:"root",pwd:"rootroot"
      .then -> done()
      .catch done
    it "should startup", (done) ->
      samjs.state.onceStarted.then -> done()
      .catch done
    describe "client", ->
      clientTest = null
      clientTest2 = null
      clientTest3 = null
      it "should be unaccessible", (done) ->
        clientTest = new client.Files("test")
        clientTest2 = new client.Files("test2")
        clientTest3 = new client.Files("test3")
        samjs.Promise.any [clientTest.get(),clientTest2.get(),clientTest3.get(),clientTest.set("something"),clientTest2.set("something"),clientTest3.set("something")]
        .catch (result) ->
          result.should.be.an.instanceOf Error
          done()
      it "should auth", (done) ->
        client.auth.login {name:"root",pwd:"rootroot"}
        .then (result) ->
          result.name.should.equal "root"
          done()
        .catch done
      it "should be still unable to access test", (done) ->
        samjs.Promise.any [clientTest.get(),clientTest.set("something")]
        .catch (result) ->
          result.should.be.an.instanceOf Error
          done()
      it "should be able to set and get test2 and test3", (done) ->
        samjs.Promise.all [clientTest2.set("something2"),clientTest3.set("something3")]
        .then ->
          samjs.Promise.all [clientTest2.get(),clientTest3.get()]
        .then (result) ->
          result[0].should.equal "something2"
          result[1].should.equal "something3"
          done()
        .catch done
