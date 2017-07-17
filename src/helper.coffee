path = require "path"
module.exports = (samjs, model, debug) =>
  pathResolve = if model.cwd then path.resolve.bind(path, model.cwd) else path.resolve.bind(path)
  check = (type, fullpath) =>
    try
      stats = await samjs.stat fullpath
    catch
      debug "Model: #{model.name} #{fullpath} doesn't exist"
    if stats?
      if type == "file" and not stats.isFile()
        throw new Error "files model.#{model.name} #{fullpath} is not a file"
      else if type == "folder" and not stats.isDirectory()
        throw new Error "files model.#{model.name} #{fullpath} is not a folder"
  isFile = check.bind null, "file"
  isFolder = check.bind null, "folder"
  createFile = (file) =>
    file = {path: file} if samjs.util.isString(file)
    file.fullpath ?= pathResolve file.path
    file.dirty = true if model.cache
    model._files[file.path] = file
    return file
  createFileAndCheck = (file) =>
    file = createFile(file)
    await isFile(file.fullpath)
    return file
  return {
          isFile: isFile
          isFolder: isFolder
          createFile: createFile
          createFileAndCheck: createFileAndCheck
          pathResolve: pathResolve
         }