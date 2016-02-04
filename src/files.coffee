# out: ../lib/files.js

fs = require "fs"
path = require "path"

module.exports = (samjs) ->
  debug = samjs.debug("files")
  name = "files"
  asyncHooks = ["afterGet","afterSet","after_Set"
    "beforeGet","beforeSet","before_Set"]
  syncHooks = ["afterCreate","beforeCreate"]
  return new class files
    constructor: ->
      @name = name
    cleanQuery: (query) ->
      return null unless query?
      query.find = {} unless query.find? and samjs.util.isObject(query.find)
      if samjs.util.isArray(query.fields)
        query.fields = query.fields.join(" ")
      else unless samjs.util.isString(query.fields)
        query.fields = ""
      unless samjs.util.isObject(query.options)
        query.options = null
      return query
    debug: (name) ->
      samjs.debug("files:#{name}")
    processModel: (model) ->
      unless model.files? or model.folders?
        throw new Error "files model need files or folders property"
      samjs.helper.initiateHooks model, asyncHooks,syncHooks
      model.options ?= {}
      for hookName in asyncHooks.concat(syncHooks)
        if model[hookName]?
          model[hookName] = [model[hookName]] unless samjs.util.isArray(model[hookName])
          model.addHook hookName, hook for hook in model[hookName]
      model.options = model._hooks.beforeCreate model.options
      model.cache ?= true
      model.cache ?= true
      model.options.encoding ?= "utf8"
      model.interfaces = []
      model._files = {} if model.cache
      check = (type, fullpath) ->
        try
          stats = fs.statSync fullpath
        catch
          debug "#{model.name} WARNING: #{fullpath} doesn't exist"
        if stats?
          if type == "file" and not stats.isFile()
            throw new Error "files model.#{model.name} #{temp} is not a file"
          else if type == "folder" and not stats.isDirectory()
            throw new Error "files model.#{model.name} #{temp} is not a folder"
      resolvePath = (relativePath) ->
        if model.options.cwd?
          return path.resolve model.options.cwd, relativePath
        else
          return path.resolve relativePath
      isFile = (fullpath) -> check("file", fullpath)
      isFolder = (fullpath) -> check("folder", fullpath)
      createFile = (file) ->
        if samjs.util.isString(file)
          file = {path: file}
        file.fullpath ?= resolvePath file.path
        if model.cache
          file.dirty = true
        model._files[file.path] = file
        isFile file.fullpath
        return file
      if model.folders?
        model.folders = [model.folders] unless samjs.util.isArray(model.folders)
        model._folders = {}
        for entry in model.folders
          if samjs.util.isObject entry
            throw new Error "a folder object needs a path in model: #{model.name}" unless entry.path?
            entry.fullpath = resolvePath entry.path
            model._folders[entry.path] = entry
          else if samjs.util.isString entry
            model._folders[entry] = {fullpath:resolvePath entry, path: entry}
          else
            throw new Error "somethings wrong with folders in model: #{model.name}"
          isFolder model._folders[entry].fullpath
      else
        model.files = [model.files] unless samjs.util.isArray(model.files)
        for file in model.files
          createFile file
      getFile = (filepath) ->
        if not filepath? and model.files? and model.files.length == 1
          filepath = model.files[0]
          filepath = filepath.path if filepath.path?
        return null unless filepath?
        file = model._files[filepath]
        unless file?
          return null unless model._folders?
          fullpath = resolvePath filepath
          for entry,folderobj of model._folders
            if fullpath.indexOf folderobj.fullpath > -1
              file = samjs.helper.clone folderobj # inherit permissions
              file.path = filepath
              file.fullpath = fullpath
              file = createFile file
              break
        return file
      updateFile = (file, data) ->
        if model.cache
          file.data = data
          file.dirty = false
          if not file.watcher?
            file.watcher = fs.watch file.fullpath, (event) ->
              file.dirty = true
        return
      parseFile = (file) ->
        return file if samjs.util.isObject(file)
        return getFile(file)
      model._get = (file) -> new samjs.Promise (resolve, reject) ->
        file = parseFile file
        return reject("file not in model") unless file?
        if model.cache and not file.dirty and file.data?
          return resolve file.data
        else
          fs.readFile file.fullpath, model.options, (err, data) ->
            return resolve(null) if err
            updateFile(file, data)
            return resolve(data)
      model.get = (filepath, client) ->
        file = getFile filepath
        return samjs.Promise.reject("file not in model") unless file?
        return model._hooks.beforeGet(client: client, file:file)
        .then ({file}) -> model._get(file)
        .then model._hooks.afterGet


      model.interfaces.push (socket) ->
        socket.on "get", (request) ->
          if request?.token?
            model.get request.content, socket.client
            .then (fileContent) -> success: true, content: fileContent
            .catch (err) -> success: false, content: undefined
            .then (response) -> socket.emit "get." + request.token, response
      model._set = (file, data) ->
        unless data?
          data = file
          file = null
        file = parseFile file
        return samjs.Promise.reject(new Error "file not in model") unless file?
        return model._hooks.before_Set(file: file, data: data)
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
        file = getFile query.path
        return samjs.Promise.reject("file not in model") unless file?
        return model._hooks.beforeSet(data: query.data,file:file, client: client)
        .then ({data,file}) -> model._set(file,data)
        .then model._hooks.afterSet
      model.interfaces.push (socket) ->
        socket.on "set", (request) ->
          if request?.token?
            model.set request.content, socket.client
            .then (obj) ->
              socket.broadcast.emit("updated", obj.path)
              return success: true, content: undefined
            .catch (err) -> success: false, content: undefined
            .then (response) -> socket.emit "set." + request.token, response
      model.startup = ->
        debug "model "+@name+" - loaded"
        return true
      model.shutdown = ->
        for fileobj of @_files
          fileobj.watcher?.close()
        return true
      if samjs.auth?
        model.addHook "beforeGet", ({file, client}) ->
          read = file.read
          read ?= model.read
          samjs.auth.isAllowed(client,read,model.permissionCheckers)
          return file: file, client:client
        model.addHook "beforeSet", ({data,file, client}) ->
          write = file.write
          write ?= model.write
          samjs.auth.isAllowed(client,write,model.permissionCheckers)
          return data: data, file:file, client:client
      model = model._hooks.afterCreate model
      return model
