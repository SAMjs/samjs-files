# out: ../lib/files.js

module.exports = (samjs) ->
  debug = samjs.debug("files")
  name = "files"
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
