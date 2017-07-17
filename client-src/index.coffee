# out: ../lib/main.js
plugin = ->
plugin.model = (model, type) ->
  if type == "files"
    model.prependFolder = (filename) -> "./#{model.name}/#{filename}"
    for type in ["read","write","delete","list","rename"]
      model[type] = model.getter.bind(null, type)
module.exports = plugin
