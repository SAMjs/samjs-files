(function() {
  var fs, path;

  fs = require("fs");

  path = require("path");

  module.exports = function(samjs) {
    var asyncHooks, debug, files, name, syncHooks;
    debug = samjs.debug("files");
    name = "files";
    asyncHooks = ["afterGet", "afterSet", "after_Set", "beforeGet", "beforeSet", "before_Set"];
    syncHooks = ["afterCreate", "beforeCreate"];
    return new (files = (function() {
      function files() {
        this.name = name;
      }

      files.prototype.cleanQuery = function(query) {
        if (query == null) {
          return null;
        }
        if (!((query.find != null) && samjs.util.isObject(query.find))) {
          query.find = {};
        }
        if (samjs.util.isArray(query.fields)) {
          query.fields = query.fields.join(" ");
        } else if (!samjs.util.isString(query.fields)) {
          query.fields = "";
        }
        if (!samjs.util.isObject(query.options)) {
          query.options = null;
        }
        return query;
      };

      files.prototype.debug = function(name) {
        return samjs.debug("files:" + name);
      };

      files.prototype.processModel = function(model) {
        var base, check, createFile, entry, file, getFile, hook, hookName, i, isFile, isFolder, j, k, l, len, len1, len2, len3, parseFile, ref, ref1, ref2, ref3, updateFile;
        if (!((model.files != null) || (model.folders != null))) {
          throw new Error("files model need files or folders property");
        }
        samjs.helper.initiateHooks(model, asyncHooks, syncHooks);
        if (model.options == null) {
          model.options = {};
        }
        ref = asyncHooks.concat(syncHooks);
        for (i = 0, len = ref.length; i < len; i++) {
          hookName = ref[i];
          if (model[hookName] != null) {
            if (!samjs.util.isArray(model[hookName])) {
              model[hookName] = [model[hookName]];
            }
            ref1 = model[hookName];
            for (j = 0, len1 = ref1.length; j < len1; j++) {
              hook = ref1[j];
              model.addHook(hookName, hook);
            }
          }
        }
        model.options = model._hooks.beforeCreate(model.options);
        if (model.cache == null) {
          model.cache = true;
        }
        if (model.cache == null) {
          model.cache = true;
        }
        if ((base = model.options).encoding == null) {
          base.encoding = "utf8";
        }
        model.interfaces = [];
        if (model.cache) {
          model._files = {};
        }
        check = function(type, fullpath) {
          var error, stats;
          try {
            stats = fs.statSync(fullpath);
          } catch (error) {
            debug(model.name + " WARNING: " + fullpath + " doesn't exist");
          }
          if (stats != null) {
            if (type === "file" && !stats.isFile()) {
              throw new Error("files model." + model.name + " " + temp + " is not a file");
            } else if (type === "folder" && !stats.isDirectory()) {
              throw new Error("files model." + model.name + " " + temp + " is not a folder");
            }
          }
        };
        isFile = function(fullpath) {
          return check("file", fullpath);
        };
        isFolder = function(fullpath) {
          return check("folder", fullpath);
        };
        createFile = function(file) {
          if (samjs.util.isString(file)) {
            file = {
              path: file
            };
          }
          if (file.fullpath == null) {
            file.fullpath = path.resolve(file.path);
          }
          if (model.cache) {
            file.dirty = true;
          }
          model._files[file.path] = file;
          isFile(file.fullpath);
          return file;
        };
        if (model.folders != null) {
          if (!samjs.util.isArray(model.folders)) {
            model.folders = [model.folders];
          }
          model._folders = {};
          ref2 = model.folders;
          for (k = 0, len2 = ref2.length; k < len2; k++) {
            entry = ref2[k];
            if (samjs.util.isObject(entry)) {
              if (entry.path == null) {
                throw new Error("a folder object needs a path in model: " + model.name);
              }
              entry.fullpath = path.resolve(entry.path);
              model._folders[entry.path] = entry;
            } else if (samjs.util.isString(entry)) {
              model._folders[entry] = {
                fullpath: path.resolve(entry, {
                  path: entry
                })
              };
            } else {
              throw new Error("somethings wrong with folders in model: " + model.name);
            }
            isFolder(model._folders[entry].fullpath);
          }
        } else {
          if (!samjs.util.isArray(model.files)) {
            model.files = [model.files];
          }
          ref3 = model.files;
          for (l = 0, len3 = ref3.length; l < len3; l++) {
            file = ref3[l];
            createFile(file);
          }
        }
        getFile = function(filepath) {
          var folderobj, fullpath, ref4;
          if ((filepath == null) && (model.files != null) && model.files.length === 1) {
            filepath = model.files[0];
            if (filepath.path != null) {
              filepath = filepath.path;
            }
          }
          if (filepath == null) {
            return null;
          }
          file = model._files[filepath];
          if (file == null) {
            if (model._folders == null) {
              return null;
            }
            fullpath = path.resolve(filepath);
            ref4 = model._folders;
            for (entry in ref4) {
              folderobj = ref4[entry];
              if (fullpath.indexOf(folderobj.fullpath > -1)) {
                file = samjs.helper.clone(folderobj);
                file.path = filepath;
                file.fullpath = fullpath;
                file = createFile(file);
                break;
              }
            }
          }
          return file;
        };
        updateFile = function(file, data) {
          if (model.cache) {
            file.data = data;
            file.dirty = false;
            if (file.watcher == null) {
              file.watcher = fs.watch(file.fullpath, function(event) {
                return file.dirty = true;
              });
            }
          }
        };
        parseFile = function(file) {
          if (samjs.util.isObject(file)) {
            return file;
          }
          return getFile(file);
        };
        model._get = function(file) {
          return new samjs.Promise(function(resolve, reject) {
            file = parseFile(file);
            if (file == null) {
              return reject("file not in model");
            }
            if (model.cache && !file.dirty && (file.data != null)) {
              return resolve(file.data);
            } else {
              return fs.readFile(file.fullpath, model.options, function(err, data) {
                if (err) {
                  return resolve(null);
                }
                updateFile(file, data);
                return resolve(data);
              });
            }
          });
        };
        model.get = function(filepath, client) {
          file = getFile(filepath);
          if (file == null) {
            return samjs.Promise.reject("file not in model");
          }
          return model._hooks.beforeGet({
            client: client,
            file: file
          }).then(function(arg) {
            var file;
            file = arg.file;
            return model._get(file);
          }).then(model._hooks.afterGet);
        };
        model.interfaces.push(function(socket) {
          return socket.on("get", function(request) {
            if ((request != null ? request.token : void 0) != null) {
              return model.get(request.content, socket.client).then(function(fileContent) {
                return {
                  success: true,
                  content: fileContent
                };
              })["catch"](function(err) {
                return {
                  success: false,
                  content: void 0
                };
              }).then(function(response) {
                return socket.emit("get." + request.token, response);
              });
            }
          });
        });
        model._set = function(file, data) {
          if (data == null) {
            data = file;
            file = null;
          }
          file = parseFile(file);
          if (file == null) {
            return samjs.Promise.reject(new Error("file not in model"));
          }
          return model._hooks.before_Set({
            file: file,
            data: data
          }).then(function(arg) {
            var data, file;
            file = arg.file, data = arg.data;
            return new samjs.Promise(function(resolve, reject) {
              return fs.writeFile(file.fullpath, data, function(err) {
                if (err) {
                  return reject(err);
                } else {
                  updateFile(file, data);
                  return resolve(file);
                }
              });
            }).then(model._hooks.after_Set);
          });
        };
        model.set = function(query, client) {
          if (query.path == null) {
            query = {
              path: null,
              data: query
            };
          }
          file = getFile(query.path);
          if (file == null) {
            return samjs.Promise.reject("file not in model");
          }
          return model._hooks.beforeSet({
            data: query.data,
            file: file,
            client: client
          }).then(function(arg) {
            var data, file;
            data = arg.data, file = arg.file;
            return model._set(file, data);
          }).then(model._hooks.afterSet);
        };
        model.interfaces.push(function(socket) {
          return socket.on("set", function(request) {
            if ((request != null ? request.token : void 0) != null) {
              return model.set(request.content, socket.client).then(function(obj) {
                socket.broadcast.emit("updated", obj.path);
                return {
                  success: true,
                  content: void 0
                };
              })["catch"](function(err) {
                return {
                  success: false,
                  content: void 0
                };
              }).then(function(response) {
                return socket.emit("set." + request.token, response);
              });
            }
          });
        });
        model.startup = function() {
          debug("model " + this.name + " - loaded");
          return true;
        };
        model.shutdown = function() {
          var fileobj, ref4;
          for (fileobj in this._files) {
            if ((ref4 = fileobj.watcher) != null) {
              ref4.close();
            }
          }
          return true;
        };
        if (samjs.auth != null) {
          model.addHook("beforeGet", function(arg) {
            var client, file, read;
            file = arg.file, client = arg.client;
            read = file.read;
            if (read == null) {
              read = model.read;
            }
            samjs.auth.isAllowed(client, read, model.permissionCheckers);
            return {
              file: file,
              client: client
            };
          });
          model.addHook("beforeSet", function(arg) {
            var client, data, file, write;
            data = arg.data, file = arg.file, client = arg.client;
            write = file.write;
            if (write == null) {
              write = model.write;
            }
            samjs.auth.isAllowed(client, write, model.permissionCheckers);
            return {
              data: data,
              file: file,
              client: client
            };
          });
        }
        model = model._hooks.afterCreate(model);
        return model;
      };

      return files;

    })());
  };

}).call(this);
