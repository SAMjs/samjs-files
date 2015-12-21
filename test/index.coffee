chai = require "chai"
should = chai.should()
samjs = require "samjs"
samjsClient = require "samjs-client"
samjsMongoClient = require "samjs-mongo-client"
samjsMongo = require("../src/main")
mongoose = require "mongoose"
fs = samjs.Promise.promisifyAll(require("fs"))
port = 3050
url = "http://localhost:"+port+"/"
testConfigFile = "test/testConfig.json"
mongodb = "mongodb://localhost/test"

testModel =
  name: "test"
  db: "mongo"
  schema:
    testProp: String
    testProp2: Boolean
  plugins:
    testPlugin: null

describe "mongoose", ->
  it "should work", (done) ->
    samjs.Promise.resolve(mongoose.createConnection(mongodb))
    .then (conn) ->
      return new samjs.Promise (resolve) ->
        conn.on "open", ->
          resolve(conn)
    .call "close"
    .then -> done()
    .catch done

describe "samjs", ->
  client = null
  clientTest = null
  before (done) ->
    samjs.reset().plugins(samjsMongo)
    fs.unlinkAsync testConfigFile
    .catch -> return true
    .finally ->
      done()

  describe "mongo", ->
    it "should be accessible", ->
      should.exist samjs.mongo
    it "should have default option mongoURI", ->
      samjs.options({config:testConfigFile})
      samjs.options["mongoURI"].should.equal "mongoURI"
    it "should have default config mongoURI", ->
      samjs.configs()
      should.exist samjs.configs["mongoURI"]
    it "should take model plugins", ->
      samjs.mongo.plugins testPlugin: ->
        @someProp = true
        return @
      samjs.models(testModel)
      samjs.models.test.someProp.should.be.true
    it "should configure", (done) ->
      samjs.startup().io.listen(port)
      client = samjsClient({
        url: url
        ioOpts:
          reconnection: false
          autoConnect: false
        })()
      client.install.onceInConfigMode
      .return client.install.set "mongoURI", mongodb
      .then -> done()
      .catch done
    it "should be configured", (done) ->
      samjs.state.ifConfigured()
      .then -> done()
      .catch done
    it "should be installed", (done) ->
      samjs.state.ifInstalled()
      .then -> done()
      .catch done
    it "should startup", (done) ->
      samjs.started.then -> done()
      .catch (e) -> console.log e
    describe "client", ->
      it "should plugin", ->
        client.plugins(samjsMongoClient)
        should.exist client.Mongo
      it "should insert data", (done) ->
        clientTest = new client.Mongo("test")
        clientTest.insert testProp:"test",testProp2: false
        .then (response) ->
          should.exist response._id
          done()
        .catch done
      it "should count data", (done) ->
        clientTest.count()
        .then (response) ->
          response.should.equal 1
          done()
        .catch done
      it "should find data", (done) ->
        clientTest.find find: {testProp:"test"}, fields: "testProp2"
        .then (response) ->
          response.length.should.be.above(0)
          for entry in response
            should.not.exist entry.testProp
            entry.testProp2.should.be.false
            should.exist entry._id
          done()
        .catch done
      it "should update data", (done) ->
        clientTest.update cond: {testProp:"test"}, doc: {testProp2:true}
        .then (response) ->
          should.exist response[0]._id
          clientTest.find find: {testProp:"test"}
        .then (response) ->
          response[0].testProp2.should.be.true
          done()
        .catch done
      it "should remove data", (done) ->
        clientTest.remove {testProp:"test"}
        .then (response) ->
          response.length.should.be.above(0)
          done()
        .catch done
  after (done) ->
    if samjs.shutdown?
      samjs.shutdown().then -> done()
    else
      done()
