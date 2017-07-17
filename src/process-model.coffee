helper = require "./helper"
{sep} = require "path"
listener = (model, socket) =>
  try
    await model.before.listen(socket)
  catch e
    return
  socket.join(name = model.name)
  socket.on "read", (request, cb) =>
    model.read path: request, socket: socket
    .then ({data}) => success: true, content: data
    .catch (err) => success: false, content: err.message
    .then cb

  socket.on "write", (request, cb) =>
    model.write Object.assign request, socket: socket
    .then ({file}) =>
      socket.to(name).broadcast.emit("updated", file.path)
      return success: true, content: file.path
    .catch (err) => success: false, content: err.message
    .then cb

  socket.on "delete", (request, cb) =>
    model.delete path: request, socket: socket
    .then ({file}) =>
      socket.to(name).broadcast.emit("deleted", file.path)
      return success: true, content: undefined
    .catch (err) => success: false, content: err.message
    .then cb

  if model.folders?
    socket.on "list", (request, cb) =>
      model.list path: request, socket: socket
      .then ({list}) => success: true, content: list
      .catch (err) =>
        success: false, content: err.message
      .then cb
    socket.on "rename", (request, cb) =>
      model.rename Object.assign request, socket: socket
      .then ({file}) => success: true, content: file.path
      .catch (err) =>
        success: false, content: err.message
      .then cb
  await model.after.listen(socket)

module.exports = (samjs, model, debug) =>
    throw new Error "files model need files or folders property" unless model.files? or model.folders?
    model._files = {}
    model.hooks.register ["write","update","insert","delete","read","list","listen"]
    {isFile, isFolder, createFile, createFileAndCheck, pathResolve} = helper(samjs, model, debug)
    samjs.helper.hookInterface samjs, model.name, listener.bind(null, model)
    samjs.helper.hookTypeResponder model
    # process model folders prop
    if model.folders?
      model.folders = "." if model.folders == "/"
      model.folders = samjs.helper.arrayize model.folders
      model._folders = {}
      # parse folders prop into folder objects
      for entry in model.folders
        entry = path: entry if samjs.util.isString entry
        throw new Error "a folder object needs a path in model: #{model.name}" unless (path = entry.path)?
        model._folders[path] = entry
        # check folder object
        await isFolder(entry.fullpath = pathResolve path)
    else # process model files prop
      model.files = samjs.helper.arrayize model.files
      for entry in model.files
        await createFileAndCheck entry # create file objects
    # get file object by filepath
    getFile = model.getFile = (filepath) =>
      return filepath if filepath and not samjs.util.isString(filepath)
      # get first file object if model only has one
      if not filepath? and model.files? and model.files.length == 1
        filepath = model.files[0]
        filepath = filepath.path if filepath.path?
      if filepath?
        file = model._files[filepath]
        # search filepath in model folders
        unless file?
          if model._folders
            fullpath = pathResolve filepath
            for entry,folderobj of model._folders
              if fullpath.indexOf(folderobj.fullpath) > -1
                file = createFile path: filepath, fullpath: fullpath, isNew: true
                break
        if file?
          if file.isNew
            await isFile file.fullpath
          return file
      throw new Error("file not in model")
    # update cache of file
    updateFile = model.updateFile = (file, data) =>
      if model.cache
        file.data = data
        file.dirty = false
        if not file.watcher?
          file.watcher = fs.watch file.fullpath, (event) => file.dirty = true
      file.isNew = !data?
      return
    # cleanup file watchers on shutdown
    samjs.before.shutdown.call =>
      for file of model._files
        file.watcher?.close()

    model.read = (o = {}) =>
      file = o.file = await getFile o.path
      await model.before.read(o)
      if model.cache and not file.dirty and file.data?
        o.data = file.data
      else
        o.data = await samjs.fs.readFile file.fullpath, model.options
        updateFile(file, o.data)
      await model.after.read(o)
      return o

    model.write = (o) =>
      file = o.file = await getFile o.path
      await model.before.write(o)
      if file.isNew
        await model.before.insert(o)
      else
        await model.before.update(o)
      await samjs.fs.writeFile file.fullpath, o.data
      if file.isNew
        await model.after.insert(o)
      else
        await model.after.update(o)
      updateFile(file, o.data)
      await model.after.write(o)
      return o

    model.delete = (o = {}) =>
      file = o.file = await getFile o.path
      await model.before.delete(o)
      await samjs.fs.remove file.fullpath
      updateFile(file, null)
      await model.after.delete(o)
      return o

    model.list = (o = {}) =>
      unless o.path
        if model.folders? and model.folders.length == 1
          o.path = model.folders[0]
      throw new Error "need path for list in model #{model.name}" unless o.path
      await model.before.read(o)
      await model.before.list(o)
      if (path = model._folders[o.path]?.fullpath)?
        o.list = await samjs.fs.readdir(path).then (files) =>
          result = []
          for file in files
            result.push await samjs.fs.stat(path + sep + file).then ({size,mtimeMs}) =>
              return size: size, lastModified: mtimeMs, name: file
          return result
      else
        throw new Error "#{o.path} not in model #{model.name}"
      await model.after.list(o)
      await model.after.read(o)
      return o

    model.rename = (o = {}) =>
      file = o.file = await getFile o.path
      newFile = o.newFile = await getFile o.newPath
      await model.before.write(o)
      await model.before.update(o)
      await samjs.fs.rename file.fullpath, newFile.fullpath
      updateFile(newFile, file.data or true)
      updateFile(file, null)
      await model.after.update(o)
      await model.after.write(o)
      return o
     