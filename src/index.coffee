module.exports = (samjs) =>
  debug = samjs.debug.files
  processModel = require("./process-model").bind(null, samjs)
  samjs.after.models.call
    prio: samjs.prio.PROCESS
    hook: (models) =>
      for name, model of models
        if model.db == "files"
          processModel(model, debug)
  