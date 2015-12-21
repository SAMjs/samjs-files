# out: ../lib/modelProcessor.js

module.exports = (samjs,mongo) -> return (model) ->
  throw new Error "mongo model needs a schema" unless model.schema?
  model.interfaces ?= {}
  model.interfaceGenerators ?= {}
  model.dbModelGenerators ?= {}
  model.mutators ?= {}
  model.mutators.find ?= []
  model.mutators.update ?= []
  model.mutators.insert ?= []
  model.mutators.remove ?= []
  model.dbModels ?= {}
  if samjs.util.isFunction model.schema
    model.schema = model.schema(@mongoose.Schema)
  unless model.schema instanceof @mongoose.Schema
    model.schema = new @mongoose.Schema model.schema
  model.interfaceGenerators[model.name] ?= []
  model.dbModelGenerators[model.name] = (addName="") ->
    name = if addName then addName+"."+@name else @name
    return samjs.mongo.mongoose.model name,@schema
  model.startup = ->
    @dbModel = @dbModelGenerators[@name].bind(@)()
    mongo.debug "model "+@name+" - loaded"
    for name, interfaceGenerators of @interfaceGenerators
      interfaces = @interfaces[name] ?= []
      for interfaceGenerator in interfaceGenerators
        interfaces.push interfaceGenerator()
    return samjs.Promise.resolve()
  model.processMutators = (query, socket, type) ->
    new Promise (resolve, reject) =>
      return reject() unless query? or socket? or type?
      for mutator in @mutators[type]
        try
          query = mutator.bind(@)(query, socket)
        catch
          return reject()
      return resolve(query)
  model.find = (query, socket, addName) ->
    query = samjs.mongo.cleanQuery(query)
    @processMutators.bind(@)(query, socket, "find")
    .then (query) =>
      new Promise (resolve, reject) =>
        dbModel = if addName then @dbModels[addName+"."+@name] else @dbModel
        dbModel.find query.find, query.fields, query.options, (err, data) ->
          return reject err if err?
          resolve data
  model.interfaceGenerators[model.name].push (addName) -> return (socket) ->
    mongo.debug "listening on "+ @name + ".find"
    socket.on "find", (request) =>
      if request?.token?
        @find request.content, socket, addName
        .then (data) -> success:true , content:data
        .catch (err) ->
          console.log err
          success:false, content:undefined
        .then (response) -> socket.emit "find.#{request.token}", response
  model.count = (query, socket, addName) ->
    query = samjs.mongo.cleanQuery(query)
    @processMutators.bind(@)(query, socket, "find")
    .then (query) =>
      new Promise (resolve, reject) =>
        dbModel = if addName then @dbModels[addName+"."+@name] else @dbModel
        dbModel.find(query.find, null, query.options).count (err, count) ->
          return reject err if err?
          resolve count
  model.interfaceGenerators[model.name].push (addName) -> return (socket) ->
    mongo.debug "listening on "+ @name + ".count"
    socket.on "count", (request) =>
      if request?.token?
        @count request.content, socket, addName
        .then (count) -> success:true , content:count
        .catch (err)  -> success:false, content:undefined
        .then (response) -> socket.emit "count.#{request.token}", response
  model.insert = (query, socket, addName) ->
    @processMutators.bind(@)(query, socket, "insert")
    .then (query) =>
      new Promise (resolve, reject) =>
        dbModel = if addName then @dbModels[addName+"."+@name] else @dbModel
        dbModel.create query, (err, obj) ->
          return reject err if err?
          resolve {_id: obj._id}
  model.interfaceGenerators[model.name].push (addName) -> return (socket) ->
    mongo.debug "listening on "+ @name + ".insert"
    socket.on "insert", (request) =>
      if request?.token?
        @insert request.content, socket, addName
        .then (modelObj) ->
          socket.broadcast.emit "inserted", modelObj._id
          return success: true, content: modelObj
        .catch (err) ->
          success: false, content: undefined
        .then (response) -> socket.emit "insert." + request.token, response
  model.update = (query, socket, addName) ->
    @processMutators.bind(@)(query, socket, "update")
    .then (query) =>
      new Promise (resolve, reject) =>
        return reject() unless query.cond? and query.doc?
        dbModel = if addName then @dbModels[addName+"."+@name] else @dbModel
        dbModel.update query.cond, query.doc, (err) =>
          return reject err if err?
          @find.bind(@) {find: query.cond, fields: "_id"}, socket, addName
          .then resolve
  model.interfaceGenerators[model.name].push (addName) -> return (socket) ->
    mongo.debug "listening on "+ @name + ".update"
    socket.on "update", (request) =>
      if request?.token?
        @update request.content, socket, addName
        .then (modelObj) ->
          socket.broadcast.emit("updated",modelObj._id)
          return success: true, content: modelObj
        .catch (err) -> success: false, content: undefined
        .then (response) -> socket.emit "update." + request.token, response
  model.remove = (query, socket, addName) ->
    @processMutators.bind(@)(query, socket, "remove")
    .then (query) =>
      new Promise (resolve, reject) =>
        dbModel = if addName then @dbModels[addName+"."+@name] else @dbModel
        @find.bind(@) {find: query, fields: "_id"}, socket, addName
        .then (results) ->
          if results.length > 0
            dbModel.remove query, (err) ->
              return reject err if err?
              resolve results
          else
            resolve []
        .catch reject
  model.interfaceGenerators[model.name].push (addName) -> return (socket) ->
    mongo.debug "listening on "+ @name + ".remove"
    socket.on "remove", (request) =>
      if request?.token?
        @remove request.content, socket, addName
        .then (id) ->
          socket.broadcast.emit "removed", id
          success: true, content: id
        .catch -> success: false, content: undefined
        .then (response) -> socket.emit "remove." + request.token, response
  for name, options of model.plugins
    throw new Error "#{name} mongo plugin not found" unless @_plugins[name]?
    model = @_plugins[name].bind(model)(options)
    unless samjs.util.isObject model
      throw new Error "mongo plugins need to return the model"
  return model
