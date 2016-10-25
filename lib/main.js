(function() {
  var fs, path;

  fs = require("fs");

  path = require("path");

  module.exports = function(samjs) {
    var Files, asyncHooks, debug, syncHooks;
    debug = samjs.debug("files");
    asyncHooks = ["afterGet", "after_Get", "afterSet", "after_Set", "afterDelete", "after_Delete", "beforeGet", "before_Get", "beforeSet", "before_Set", "beforeDelete", "before_Delete"];
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
        var base, base1, base2, base3, check, createFile, createFileAndCheck, entry, file, getFile, hook, hookName, i, isFile, isFolder, j, l, len, len1, len2, len3, m, name, options, parseFile, ref, ref1, ref2, ref3, ref4, resolvePath, updateFile;
        if (!((model.files != null) || (model.folders != null))) {
          throw new Error("files model need files or folders property");
        }
        samjs.helper.initiateHooks(model, asyncHooks, syncHooks);
        if (model.options == null) {
          model.options = {};
        }
        if (model.access == null) {
          model.access = {};
        }
        if (this._plugins.auth != null) {
          if (model.plugins.noAuth) {
            delete model.plugins.noAuth;
          } else {
            if ((base = model.plugins).auth == null) {
              base.auth = {};
            }
          }
        }
        ref = model.plugins;
        for (name in ref) {
          options = ref[name];
          if (this._plugins[name] == null) {
            throw new Error(name + " files plugin not found");
          }
          this._plugins[name].bind(model)(options);
        }
        if ((base1 = model.access).insert == null) {
          base1.insert = model.access.write;
        }
        if ((base2 = model.access).update == null) {
          base2.update = model.access.write;
        }
        if ((base3 = model.access)["delete"] == null) {
          base3["delete"] = model.access.write;
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
        model._hooks.beforeCreate.bind(model);
        model.interfaces = [];
        model._files = {};
        check = function(type, fullpath) {
          var stats;
          try {
            stats = fs.statSync(fullpath);
          } catch (error) {
            debug("Model: " + model.name + " " + fullpath + " doesn't exist");
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
          return file;
        };
        createFileAndCheck = function(file) {
          file = createFile(file);
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
            createFileAndCheck(file);
          }
        }
        getFile = function(filepath) {
          return new samjs.Promise(function(resolve, reject) {
            var folderobj, fullpath, ref5;
            if ((filepath == null) && (model.files != null) && model.files.length === 1) {
              filepath = model.files[0];
              if (filepath.path != null) {
                filepath = filepath.path;
              }
            }
            if (filepath != null) {
              file = model._files[filepath];
              if (file == null) {
                if (model._folders) {
                  fullpath = resolvePath(filepath);
                  ref5 = model._folders;
                  for (entry in ref5) {
                    folderobj = ref5[entry];
                    if (fullpath.indexOf(folderobj.fullpath) > -1) {
                      file = samjs.helper.clone(folderobj);
                      file.path = filepath;
                      file.fullpath = fullpath;
                      file = createFile(file);
                      file.isNew = true;
                      break;
                    }
                  }
                }
              }
              if (file != null) {
                if (file.write == null) {
                  file.write = model.access.write;
                }
                if (file.update == null) {
                  file.update = model.access.update;
                }
                if (file["delete"] == null) {
                  file["delete"] = model.access["delete"];
                }
                if (file.insert == null) {
                  file.insert = model.access.insert;
                }
                if (file.read == null) {
                  file.read = model.access.read;
                }
                if (file.isNew) {
                  return fs.stat(file.fullpath, function(err, stats) {
                    if (err != null) {
                      return resolve(file);
                    }
                    if (stats.isFile()) {
                      file.isNew = false;
                      return resolve(file);
                    }
                    return reject(new Error("not a file"));
                  });
                } else {
                  return resolve(file);
                }
              }
            }
            return reject(new Error("file not in model"));
          });
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
            return samjs.Promise.resolve(file);
          } else {
            return getFile(file);
          }
        };
        model._get = function(file) {
          return parseFile(file).then(model._hooks.before_Get(file)).then(function(file) {
            return new samjs.Promise(function(resolve, reject) {
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
            }).then(model._hooks.after_Get);
          });
        };
        model.get = function(filepath, client) {
          return getFile(filepath).then(function(file) {
            if (!file.read) {
              new Error("no permission");
            }
            return model._hooks.beforeGet({
              client: client,
              file: file
            });
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
          return getFile(filepath).then(function(file) {
            if (!file.read) {
              new Error("no permission");
            }
            return model._hooks.beforeGet({
              client: client,
              file: file
            });
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
          return getFile(filepath).then(function(file) {
            if ((model.tokens[token] != null) && model.tokens[token] === file) {
              return file;
            }
            throw new Error("wrong token");
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
          return parseFile(file).then(function(file) {
            return model._hooks.before_Set({
              file: file,
              data: data
            });
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
          return getFile(query.path).then(function(file) {
            if (!file.write) {
              throw new Error("no permission");
            }
            return model._hooks.beforeSet({
              data: query.data,
              file: file,
              client: client
            });
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
                  content: err.message
                };
              }).then(function(response) {
                return socket.emit("set." + request.token, response);
              });
            }
          });
        });
        if (model.folders != null) {
          model._delete = function(file) {
            return parseFile(file).then(model._hooks.before_Delete).then(function(file) {
              return new samjs.Promise(function(resolve, reject) {
                return fs.unlink(file.fullpath, function(err) {
                  if (err) {
                    return reject(err);
                  } else {
                    updateFile(file, null);
                    return resolve(file);
                  }
                });
              }).then(model._hooks.after_Delete);
            });
          };
          model["delete"] = function(query, client) {
            return getFile(query).then(function(file) {
              if (!file["delete"]) {
                throw new Error("no permission");
              }
              return model._hooks.beforeDelete({
                client: client,
                file: file
              });
            }).then(function(arg) {
              var file;
              file = arg.file;
              return model._delete(file);
            }).then(model._hooks.afterDelete);
          };
          model.interfaces.push(function(socket) {
            return socket.on("delete", function(request) {
              if ((request != null ? request.token : void 0) != null) {
                return model["delete"](request.content, socket.client).then(function(obj) {
                  socket.broadcast.emit("deleted", obj.path);
                  return {
                    success: true,
                    content: void 0
                  };
                })["catch"](function(err) {
                  return {
                    success: false,
                    content: err.message
                  };
                }).then(function(response) {
                  return socket.emit("delete." + request.token, response);
                });
              }
            });
          });
        }
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
        model._hooks.afterCreate.bind(model);
        return model;
      };

      return Files;

    })());
  };

}).call(this);
