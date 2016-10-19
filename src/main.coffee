# out: ../lib/main.js

fs = require "fs"
path = require "path"

module.exports = (samjs) ->
  debug = samjs.debug("files")
  asyncHooks = [
    "afterGet"
    "after_Get"
    "afterSet"
    "after_Set"
    "afterDelete"
    "after_Delete"
    "beforeGet"
    "before_Get"
    "beforeSet"
    "before_Set"
    "beforeDelete"
    "before_Delete"
  ]
  syncHooks = ["afterCreate","beforeCreate"]
  return new class Files
    constructor: ->
      @_plugins = {}
    name: "files"
    plugins: (plugins) ->
      for k,v of plugins
        @_plugins[k] = v
    processModel: (model) ->
      unless model.files? or model.folders?
        throw new Error "files model need files or folders property"
      samjs.helper.initiateHooks model, asyncHooks,syncHooks
      model.options ?= {}
      model.access ?= {}
      hasNoAuth = false
      hasAuth = false
      for name, options of model.plugins
        throw new Error "#{name} files plugin not found" unless @_plugins[name]?
        @_plugins[name].bind(model)(options)
        if name == "noAuth"
          hasNoAuth = true
        if name == "auth"
          hasAuth = true
      # activate auth plugin by default if present
      if @_plugins.auth? and not hasAuth and not hasNoAuth
        @_plugins.auth.bind(model)({})
      model.access.insert ?= model.access.write
      model.access.update ?= model.access.write
      model.access.delete ?= model.access.write
      for hookName in asyncHooks.concat(syncHooks)
        if model[hookName]?
          model[hookName] = [model[hookName]] unless samjs.util.isArray(model[hookName])
          model.addHook hookName, hook for hook in model[hookName]
      model._hooks.beforeCreate.bind(model)
      model.interfaces = []
      model._files = {}
      # check for file/folder existance and type
      check = (type, fullpath) ->
        try
          stats = fs.statSync fullpath
        catch
          debug "Model: #{model.name} #{fullpath} doesn't exist"
        if stats?
          if type == "file" and not stats.isFile()
            throw new Error "files model.#{model.name} #{fullpath} is not a file"
          else if type == "folder" and not stats.isDirectory()
            throw new Error "files model.#{model.name} #{fullpath} is not a folder"

      # resolve path relative to a given cwd
      resolvePath = (relativePath) ->
        if model.cwd?
          return path.resolve model.cwd, relativePath
        else
          return path.resolve relativePath
      isFile = (fullpath) -> check("file", fullpath)
      isFolder = (fullpath) -> check("folder", fullpath)
      # create a file object
      createFile = (file) ->
        if samjs.util.isString(file)
          file = {path: file}
        file.fullpath ?= resolvePath file.path
        if model.cache
          file.dirty = true
        model._files[file.path] = file
        return file
      createFileAndCheck = (file) ->
        file = createFile(file)
        isFile file.fullpath
        return file
      # process model folders prop
      if model.folders?
        model.folders = [model.folders] unless samjs.util.isArray(model.folders)
        model._folders = {}
        # parse folders prop into folder objects
        for entry in model.folders
          if samjs.util.isObject entry
            throw new Error "a folder object needs a path in model: #{model.name}" unless entry.path?
            entry.fullpath = resolvePath entry.path
            model._folders[entry.path] = entry
          else if samjs.util.isString entry
            model._folders[entry] = {fullpath:resolvePath entry, path: entry}
          else
            throw new Error "somethings wrong with folders in model: #{model.name}"
          # check folder object
          isFolder model._folders[entry].fullpath
      else # process model files prop
        model.files = [model.files] unless samjs.util.isArray(model.files)
        for file in model.files
          createFileAndCheck file # create file objects
      # get file object by filepath
      getFile = (filepath) -> new samjs.Promise (resolve, reject) ->
        # get first file object if model only has one
        if not filepath? and model.files? and model.files.length == 1
          filepath = model.files[0]
          filepath = filepath.path if filepath.path?
        if filepath?
          file = model._files[filepath]
          # search filepath in model folders
          unless file?
            if model._folders
              fullpath = resolvePath filepath
              for entry,folderobj of model._folders
                if fullpath.indexOf(folderobj.fullpath) > -1
                  file = samjs.helper.clone folderobj # inherit permissions
                  file.path = filepath
                  file.fullpath = fullpath
                  file = createFile file
                  file.isNew = true
                  break
          if file?
            file.write ?= model.access.write
            file.delete ?= model.access.delete
            file.insert ?= model.access.insert
            file.read ?= model.access.read
            if file.isNew
              return fs.stat file.fullpath, (err,stats) ->
                return resolve(file) if err?
                if stats.isFile()
                  file.isNew = false
                  return resolve(file)
                return reject(new Error("not a file"))
            else
              return resolve(file)
        return reject(new Error("file not in model"))
      # update cache of file
      updateFile = (file, data) ->
        if model.cache
          file.data = data
          file.dirty = false
          if not file.watcher?
            file.watcher = fs.watch file.fullpath, (event) ->
              file.dirty = true
        return
      parseFile = (file) ->
        if samjs.util.isObject(file)
          samjs.Promise.resolve(file)
        else
          getFile(file)

      model._get = (file) ->
        parseFile file
        .then model._hooks.before_Get(file)
        .then (file) -> new samjs.Promise (resolve, reject) ->
          if model.cache and not file.dirty and file.data?
            return resolve file.data
          else
            fs.readFile file.fullpath, model.options, (err, data) ->
              return resolve(null) if err
              updateFile(file, data)
              return resolve(data)
        .then model._hooks.after_Get

      model.get = (filepath, client) ->
        getFile filepath
        .then (file) ->
          new Error("no permission") unless file.read
          model._hooks.beforeGet(client: client, file:file)
        .then ({file}) -> model._get(file)
        .then model._hooks.afterGet


      model.interfaces.push (socket) ->
        socket.on "get", (request) ->
          if request?.token?
            model.get request.content, socket.client
            .then (fileContent) -> success: true, content: fileContent
            .catch (err) -> success: false, content: undefined
            .then (response) -> socket.emit "get." + request.token, response

      model.tokens = {}

      model.getToken = (filepath, client) ->
        getFile filepath
        .then (file) ->
          new Error("no permission") unless file.read
          model._hooks.beforeGet(client: client, file:file)
        .then ({file}) ->
          return samjs.helper.generateToken 24
          .then (token) ->
            model.tokens[token] = file
            setTimeout (() -> delete model.tokens[token]),5000
            return token

      model.getByToken = (filepath, token) ->
        getFile filepath
        .then (file) ->
          if model.tokens[token]? and model.tokens[token] == file
            return file
          throw new Error("wrong token")

      model.interfaces.push (socket) ->
        socket.on "getToken", (request) ->
          if request?.token?
            model.getToken request.content, socket.client
            .then (token) -> success: true, content: token
            .catch (err) -> success: false, content: err
            .then (response) -> socket.emit "getToken." + request.token, response

      model.interfaces.push (socket) ->
        socket.on "deleteToken", (request) ->
          if request?.token?
            if model.tokens[request.content]?
              delete model.tokens[request.content]
              response = success: true
            else
              response = success: false
            socket.emit "deleteToken." + request.token, response

      model._set = (file, data) ->
        unless data?
          data = file
          file = null
        parseFile file
        .then (file) ->
          model._hooks.before_Set(file: file, data: data)
        .then ({file,data}) -> new samjs.Promise (resolve,reject) ->
          fs.writeFile file.fullpath, data, (err) ->
            if err
              reject(err)
            else
              updateFile(file, data)
              resolve(file)
        .then model._hooks.after_Set

      model.set = (query, client) ->
        unless query.path?
          query = {path: null, data: query}
        getFile query.path
        .then (file) ->
          throw new Error("no permission") unless file.write
          model._hooks.beforeSet(data: query.data,file:file, client: client)
        .then ({data,file}) -> model._set(file,data)
        .then model._hooks.afterSet

      model.interfaces.push (socket) ->
        socket.on "set", (request) ->
          if request?.token?
            model.set request.content, socket.client
            .then (obj) ->
              socket.broadcast.emit("updated", obj.path)
              return success: true, content: undefined
            .catch (err) -> success: false, content: err.message
            .then (response) -> socket.emit "set." + request.token, response

      if model.folders?
        model._delete = (file) ->
          parseFile file
          .then model._hooks.before_Delete
          .then (file) -> new samjs.Promise (resolve,reject) ->
            fs.unlink file.fullpath, (err) ->
              if err
                reject(err)
              else
                updateFile(file, null)
                resolve(file)
          .then model._hooks.after_Delete

        model.delete = (query, client) ->
          getFile query
          .then (file) ->
            throw new Error("no permission") unless file.delete
            model._hooks.beforeDelete(client: client, file:file)
          .then ({file}) -> model._delete(file)
          .then model._hooks.afterDelete

        model.interfaces.push (socket) ->
          socket.on "delete", (request) ->
            if request?.token?
              model.delete request.content, socket.client
              .then (obj) ->
                socket.broadcast.emit("deleted", obj.path)
                return success: true, content: undefined
              .catch (err) -> success: false, content: err.message
              .then (response) -> socket.emit "delete." + request.token, response

      model.startup = ->
        debug "model "+@name+" - loaded"
        return true

      model.shutdown = ->
        for fileobj of @_files
          fileobj.watcher?.close()
        return true
      model._hooks.afterCreate.bind(model)
      return model
