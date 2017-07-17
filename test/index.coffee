chai = require "chai"
chaiAsPromised = require "chai-as-promised"
chai.use chaiAsPromised
should = chai.should()
requireAny = require "try-require-multiple"
Samjs = requireAny "samjs/src", "samjs"
SamjsClient = requireAny "samjs/client-src", "samjs/client"
samjsFiles = require "../src"
samjsFilesClient = require "../client-src"

path = require "path"
port = 3060
url = "http://localhost:"+port+"/"
testConfigFile = "test/testConfig.json"



Models = [{
  name: "testFile"
  db: "files"
  files: testConfigFile
  options: 'utf8'
  },{
  name: "testFileObj"
  db: "files"
  options: 'utf8'
  files:
    path: testConfigFile
  },{
  name: "testFileMultiple"
  db: "files"
  options: 'utf8'
  files: [testConfigFile,testConfigFile+"2"]
  },{
  name: "testFileMultipleObj"
  options: 'utf8'
  db: "files"
  files: [{
    path:testConfigFile
    },testConfigFile+"3"
  ]
  },{
  name: "testCWD"
  options: 'utf8'
  db: "files"
  cwd: "./"
  files: testConfigFile
  },{
  name: "testFolder"
  options: 'utf8'
  db: "files"
  folders: "test"
}]
describe "samjs", =>
  describe "files", =>
    samjs = samjsClient = model = null
    isFile = (path) =>
      stats = await samjs.fs.stat path
      stats.isFile().should.be.true
    after =>
      await samjs.fs.remove testConfigFile
      await samjs.fs.remove testConfigFile+"2"
      await samjs.fs.remove testConfigFile+"3"
      samjs?.shutdown()
      samjsClient?.close()

    it "should startup", =>
      samjs = new Samjs
        plugins: samjsFiles
        options: {config:testConfigFile}
        models: Models
      await samjs.finished.then (io) => io.listen(port)
      samjsClient = new SamjsClient
        plugins: samjsFilesClient
        url: url
        io: reconnection:false
      await samjsClient.finished

    describe "model", =>
      it "should exist", =>
        model = samjs.models.testFile
        should.exist model
      it "should be able to write and read",=>
        {file} = await model.write(data: "{test:test}")
        isFile(file.fullpath)
        {data} = await model.read()
        data.should.equal "{test:test}"

      describe "client", =>
        testFile = null
        it "should write",  => 
          testFile = await samjsClient.model("testFile").ready
          testFile.write data: "{test2:test}"
        it "should read", =>
          testFile.read().should.eventually.equal "{test2:test}"

    describe "model with file object", =>
      it "should exist", =>
        model = samjs.models["testFileObj"]
        should.exist model
      it "should be able to write and read", =>
        {file} = await model.write path: testConfigFile, data: "{test:test2}"
        isFile(file.fullpath)
        {data} = await model.read(path: testConfigFile)
        data.should.equal "{test:test2}"

      describe "client", =>
        it "should write",  =>
          model = await samjsClient.model("testFileObj").ready
          model.write path:testConfigFile, data:"{test2:test}"

        it "should read",  =>
          model.read(testConfigFile).should.eventually.equal "{test2:test}"

    describe "model with multiple files", =>
      it "should exist", =>
        model = samjs.models["testFileMultiple"]
        should.exist model
      it "should be able to write and read", =>
        {file} = await model.write path: testConfigFile+"2", data: "{test:test}"
        isFile(file.fullpath)
        {data} = await model.read path: testConfigFile+"2"
        data.should.equal "{test:test}"

      describe "client", =>
        it "should write", =>
          model = await samjsClient.model("testFileMultiple").ready
          model.write path:testConfigFile+"2",data:"{test2:test}"

        it "should read", =>
          model.read(testConfigFile+"2").should.eventually.equal "{test2:test}"

    describe "model with multiple file objects", =>
      it "should exist", =>
        model = samjs.models["testFileMultipleObj"]
        should.exist model
      it "should be able to write and read", =>
        {file} = await model.write path: testConfigFile, data: "{test:test4864}"
        isFile(file.fullpath)
        {data} = await model.read path: testConfigFile
        data.should.equal "{test:test4864}"
        {file} = await model.write path: testConfigFile+"3",data: "{test:test4864}"
        isFile(file.fullpath)
        {data} = await model.read path: testConfigFile+"3"
        data.should.equal "{test:test4864}"

      describe "client", =>
        it "should write", =>
          model = await samjsClient.model("testFileMultipleObj").ready
          model.write path:testConfigFile, data:"{test4864:test}"

        it "should read",  =>
          model.read(testConfigFile).should.eventually.equal "{test4864:test}"

    describe "model with cwd", =>
      model = null
      it "should exist", =>
        model = samjs.models["testCWD"]
        should.exist model
      it "should be able to write and read", =>
        {file} = await model.write data: "{test4:test}"
        isFile(path.resolve(testConfigFile))
        {data} = await model.read()
        data.should.equal "{test4:test}"
    describe "model with folder", =>
      model = null
      it "should exist", =>
        model = samjs.models["testFolder"]
        should.exist model
      it "should be able to write and read", =>
        {file} = await model.write path: testConfigFile, data: "{test45:test}"
        isFile(path.resolve(testConfigFile))
        {data} = await model.read path: testConfigFile
        data.should.equal "{test45:test}"