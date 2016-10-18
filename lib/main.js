(function() {
  var fs, path;

  fs = require("fs");

  path = require("path");

  module.exports = function(samjs) {
    var Files, asyncHooks, debug, syncHooks;
    debug = samjs.debug("files");
    asyncHooks = ["afterGet", "afterSet", "after_Set", "beforeGet", "beforeSet", "before_Set"];
    syncHooks = ["afterCreate", "beforeCreate"];
    return new (Files = (function() {
      function Files() {
        this._plugins = {};
      }

      Files.prototype.name = "files";

      Files.prototype.plugins = function(plugins) {
        var k, results, v;
        results = [];
        for (k in plugins) {
          v = plugins[k];
          results.push(this._plugins[k] = v);
        }
        return results;
      };

      Files.prototype.processModel = function(model) {
        var check, createFile, entry, file, getFile, hasAuth, hasNoAuth, hook, hookName, i, isFile, isFolder, j, l, len, len1, len2, len3, m, name, options, parseFile, ref, ref1, ref2, ref3, ref4, resolvePath, updateFile;
        if (!((model.files != null) || (model.folders != null))) {
          throw new Error("files model need files or folders property");
        }
        samjs.helper.initiateHooks(model, asyncHooks, syncHooks);
        if (model.options == null) {
          model.options = {};
        }
        hasNoAuth = false;
        hasAuth = false;
        ref = model.plugins;
        for (name in ref) {
          options = ref[name];
          if (this._plugins[name] == null) {
            throw new Error(name + " files plugin not found");
          }
          model = this._plugins[name].bind(model)(options);
          if (!samjs.util.isObject(model)) {
            throw new Error("files plugins need to return the model");
          }
          if (name === "noAuth") {
            hasNoAuth = true;
          }
          if (name === "auth") {
            hasAuth = true;
          }
        }
        if ((this._plugins.auth != null) && !hasAuth && !hasNoAuth) {
          model = this._plugins.auth.bind(model)({});
        }
        ref1 = asyncHooks.concat(syncHooks);
        for (i = 0, len = ref1.length; i < len; i++) {
          hookName = ref1[i];
          if (model[hookName] != null) {
            if (!samjs.util.isArray(model[hookName])) {
              model[hookName] = [model[hookName]];
            }
            ref2 = model[hookName];
            for (j = 0, len1 = ref2.length; j < len1; j++) {
              hook = ref2[j];
              model.addHook(hookName, hook);
            }
          }
        }
        model = model._hooks.beforeCreate(model);
        model.interfaces = [];
        model._files = {};
        check = function(type, fullpath) {
          var stats;
          try {
            stats = fs.statSync(fullpath);
          } catch (error) {
            debug(model.name + " WARNING: " + fullpath + " doesn't exist");
          }
          if (stats != null) {
            if (type === "file" && !stats.isFile()) {
              throw new Error("files model." + model.name + " " + fullpath + " is not a file");
            } else if (type === "folder" && !stats.isDirectory()) {
              throw new Error("files model." + model.name + " " + fullpath + " is not a folder");
            }
          }
        };
        resolvePath = function(relativePath) {
          if (model.cwd != null) {
            return path.resolve(model.cwd, relativePath);
          } else {
            return path.resolve(relativePath);
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
            file.fullpath = resolvePath(file.path);
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
          ref3 = model.folders;
          for (l = 0, len2 = ref3.length; l < len2; l++) {
            entry = ref3[l];
            if (samjs.util.isObject(entry)) {
              if (entry.path == null) {
                throw new Error("a folder object needs a path in model: " + model.name);
              }
              entry.fullpath = resolvePath(entry.path);
              model._folders[entry.path] = entry;
            } else if (samjs.util.isString(entry)) {
              model._folders[entry] = {
                fullpath: resolvePath(entry, {
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
          ref4 = model.files;
          for (m = 0, len3 = ref4.length; m < len3; m++) {
            file = ref4[m];
            createFile(file);
          }
        }
        getFile = function(filepath) {
          var folderobj, fullpath, ref5;
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
            fullpath = resolvePath(filepath);
            ref5 = model._folders;
            for (entry in ref5) {
              folderobj = ref5[entry];
              if (fullpath.indexOf(folderobj.fullpath) > -1) {
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
          var read;
          file = getFile(filepath);
          if (file == null) {
            return samjs.Promise.reject(new Error("file not in model"));
          }
          read = file.read;
          if (read == null) {
            read = model.read;
          }
          if (!read) {
            return samjs.Promise.reject(new Error("no permission"));
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
        model.tokens = {};
        model.getToken = function(filepath, client) {
          var read;
          file = getFile(filepath);
          if (file == null) {
            return samjs.Promise.reject("file not in model");
          }
          read = file.read;
          if (read == null) {
            read = model.read;
          }
          if (!read) {
            return samjs.Promise.reject(new Error("no permission"));
          }
          return model._hooks.beforeGet({
            client: client,
            file: file
          }).then(function(arg) {
            var file;
            file = arg.file;
            return samjs.helper.generateToken(24).then(function(token) {
              model.tokens[token] = file;
              setTimeout((function() {
                return delete model.tokens[token];
              }), 5000);
              return token;
            });
          });
        };
        model.getByToken = function(filepath, token) {
          file = getFile(filepath);
          return new samjs.Promise(function(resolve, reject) {
            if ((model.tokens[token] != null) && model.tokens[token] === file) {
              return resolve(file);
            } else {
              return reject(new Error("wrong token"));
            }
          });
        };
        model.interfaces.push(function(socket) {
          return socket.on("getToken", function(request) {
            if ((request != null ? request.token : void 0) != null) {
              return model.getToken(request.content, socket.client).then(function(token) {
                return {
                  success: true,
                  content: token
                };
              })["catch"](function(err) {
                return {
                  success: false,
                  content: err
                };
              }).then(function(response) {
                return socket.emit("getToken." + request.token, response);
              });
            }
          });
        });
        model.interfaces.push(function(socket) {
          return socket.on("deleteToken", function(request) {
            var response;
            if ((request != null ? request.token : void 0) != null) {
              if (model.tokens[request.content] != null) {
                delete model.tokens[request.content];
                response = {
                  success: true
                };
              } else {
                response = {
                  success: false
                };
              }
              return socket.emit("deleteToken." + request.token, response);
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
          var write;
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
          write = file.write;
          if (write == null) {
            write = model.write;
          }
          if (!write) {
            return samjs.Promise.reject(new Error("no permission"));
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
                  content: err
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
          var fileobj, ref5;
          for (fileobj in this._files) {
            if ((ref5 = fileobj.watcher) != null) {
              ref5.close();
            }
          }
          return true;
        };
        model = model._hooks.afterCreate(model);
        return model;
      };

      return Files;

    })());
  };

}).call(this);
