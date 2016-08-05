chai = require "chai"
should = chai.should()
samjs = require "samjs"
samjsClient = require "samjs-client"
samjsFiles = require "../src/main"
samjsFilesClient = require "samjs-files-client"
fs = samjs.Promise.promisifyAll(require("fs"))
path = require "path"
port = 3060
url = "http://localhost:"+port+"/"
testConfigFile = "test/testConfig.json"

Models = [{
  name: "testFile"
  db: "files"
  files: testConfigFile
  write: true
  read: true
  },{
  name: "testFileObj"
  db: "files"
  files:
    path: testConfigFile
    write: true
    read: true
  },{
  name: "testFileMultiple"
  db: "files"
  files: [testConfigFile,testConfigFile+"2"]
  write: true
  read: true
  },{
  name: "testFileMultipleObj"
  db: "files"
  files: [{
    path:testConfigFile
    write: true
    read: true
    },testConfigFile+"3"
  ]
  },{
  name: "testCWD"
  db: "files"
  options: cwd: "test"
  files: testConfigFile
  write: true
  read: true
  },{
  name: "testFolder"
  db: "files"
  folders: "test"
  write: true
  read: true
}]
unlink = (file) ->
  fs.unlinkAsync file
  .catch -> return true
reset = (done) ->
  samjs.reset()
  unlink testConfigFile
  .finally ->
    done()
shutdown = (done) ->
  promises = [unlink(testConfigFile),unlink(testConfigFile+"2"),unlink(testConfigFile+"3")]
  promises.push samjs.shutdown() if samjs.shutdown?
  samjs.Promise.all promises
  .then -> done()

describe "samjs", ->
  client = null
  clientTest = null
  model = null
  describe "files", ->
    before reset
    after shutdown
    it "should be accessible", ->
      samjs.plugins(samjsFiles)
      should.exist samjs.files
    it "should startup", (done) ->
      samjs.options({config:testConfigFile})
      .configs()
      .models(Models)
      .startup().io.listen(port)
      client = samjsClient({
        url: url
        ioOpts:
          reconnection: false
          autoConnect: false
        })()
      client.plugins(samjsFilesClient)
      samjs.state.onceStarted.then -> done()
      .catch done
    describe "model", ->
      it "should exist", ->
        model = samjs.models["testFile"]
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
        it "should set", (done) ->
          clientTest = new client.Files("testFile")
          clientTest.set "{test2:test}"
          .then -> done()
          .catch done
        it "should get", (done) ->
          clientTest.get()
          .then (response) ->
            response.should.equal "{test2:test}"
            done()
          .catch done

    describe "model with file object", ->
      it "should exist", ->
        model = samjs.models["testFileObj"]
        should.exist model
      it "should be able to _set and _get", (done) ->
        model._set testConfigFile,"{test:test2}"
        .then (file) ->
          stats = fs.statSync file.fullpath
          stats.isFile().should.be.true
          model._get(testConfigFile)
        .then (result) ->
          result.should.equal "{test:test2}"
          done()
        .catch done
      describe "client", ->
        clientTest = null
        it "should set", (done) ->
          clientTest = new client.Files("testFileObj")
          clientTest.set path:testConfigFile,data:"{test2:test}"
          .then -> done()
          .catch done
        it "should get", (done) ->
          clientTest.get(testConfigFile)
          .then (response) ->
            response.should.equal "{test2:test}"
            done()
          .catch done
    describe "model with multiple files", ->
      it "should exist", ->
        model = samjs.models["testFileMultiple"]
        should.exist model
      it "should be able to _set and _get", (done) ->
        model._set testConfigFile+"2","{test:test}"
        .then (file) ->
          stats = fs.statSync file.fullpath
          stats.isFile().should.be.true
          model._get(testConfigFile+"2")
        .then (result) ->
          result.should.equal "{test:test}"
          done()
        .catch done
      describe "client", ->
        clientTest = null
        it "should set", (done) ->
          clientTest = new client.Files("testFileMultiple")
          clientTest.set path:testConfigFile+"2",data:"{test2:test}"
          .then -> done()
          .catch done
        it "should get", (done) ->
          clientTest.get(testConfigFile+"2")
          .then (response) ->
            response.should.equal "{test2:test}"
            done()
          .catch done
    describe "model with multiple file objects", ->
      it "should exist", ->
        model = samjs.models["testFileMultipleObj"]
        should.exist model
      it "should be able to _set and _get", (done) ->
        model._set testConfigFile,"{test:test4864}"
        .then (file) ->
          stats = fs.statSync file.fullpath
          stats.isFile().should.be.true
          model._get(testConfigFile)
        .then (result) ->
          result.should.equal "{test:test4864}"
          model._set(testConfigFile+"3","{test:test4864}")
        .then (file) ->
          stats = fs.statSync file.fullpath
          stats.isFile().should.be.true
          model._get(testConfigFile+"3")
        .then (result) ->
          result.should.equal "{test:test4864}"
          done()
        .catch done
      describe "client", ->
        clientTest = null
        it "should set", (done) ->
          clientTest = new client.Files("testFileMultiple")
          clientTest.set path:testConfigFile,data:"{test4864:test}"
          .then -> done()
          .catch done
        it "should get", (done) ->
          clientTest.get(testConfigFile)
          .then (response) ->
            response.should.equal "{test4864:test}"
            done()
          .catch done
        it "should refuse to set when not permitted", (done) ->
          clientTest.set path:testConfigFile+"3",data:"{test4864:test}"
          .catch (e) ->
            done()
        it "should refuse to get when not permitted", (done) ->
          clientTest.get path:testConfigFile+"3"
          .catch (e) ->
            done()

    describe "model with cwd", ->
      model = null
      it "should exist", ->
        model = samjs.models["testCWD"]
        should.exist model
      it "should be able to _set and _get", (done) ->
        model._set "{test4:test}"
        .then (file) ->
          stats = fs.statSync path.resolve(testConfigFile)
          stats.isFile().should.be.true
          model._get()
        .then (result) ->
          result.should.equal "{test4:test}"
          done()
        .catch done
    describe "model with folder", ->
      model = null
      it "should exist", ->
        model = samjs.models["testFolder"]
        should.exist model
      it "should be able to _set and _get", (done) ->
        model._set testConfigFile,"{test45:test}"
        .then (file) ->
          stats = fs.statSync path.resolve(testConfigFile)
          stats.isFile().should.be.true
          model._get(testConfigFile)
        .then (result) ->
          result.should.equal "{test45:test}"
          done()
        .catch done
