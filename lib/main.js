(function() {
  module.exports = function(samjs) {
    var files, plugin;
    files = require("./files")(samjs);
    plugin = {};
    plugin.name = files.name;
    plugin.obj = files;
    return plugin;
  };

}).call(this);
