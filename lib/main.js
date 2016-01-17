(function() {
  module.exports = function(samjs) {
    var files, plugin;
    files = require("./files")(samjs);
    plugin = {};
    plugin.name = files.name;
    plugin.obj = files;
    plugin.startup = files.startup;
    return plugin;
  };

}).call(this);
