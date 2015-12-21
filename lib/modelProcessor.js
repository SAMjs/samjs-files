(function() {
  module.exports = function(samjs, mongo) {
    return function(model) {
      var base, base1, base2, base3, base4, name, name1, options, ref;
      if (model.schema == null) {
        throw new Error("mongo model needs a schema");
      }
      if (model.interfaces == null) {
        model.interfaces = {};
      }
      if (model.interfaceGenerators == null) {
        model.interfaceGenerators = {};
      }
      if (model.dbModelGenerators == null) {
        model.dbModelGenerators = {};
      }
      if (model.mutators == null) {
        model.mutators = {};
      }
      if ((base = model.mutators).find == null) {
        base.find = [];
      }
      if ((base1 = model.mutators).update == null) {
        base1.update = [];
      }
      if ((base2 = model.mutators).insert == null) {
        base2.insert = [];
      }
      if ((base3 = model.mutators).remove == null) {
        base3.remove = [];
      }
      if (model.dbModels == null) {
        model.dbModels = {};
      }
      if (samjs.util.isFunction(model.schema)) {
        model.schema = model.schema(this.mongoose.Schema);
      }
      if (!(model.schema instanceof this.mongoose.Schema)) {
        model.schema = new this.mongoose.Schema(model.schema);
      }
      if ((base4 = model.interfaceGenerators)[name1 = model.name] == null) {
        base4[name1] = [];
      }
      model.dbModelGenerators[model.name] = function(addName) {
        var name;
        if (addName == null) {
          addName = "";
        }
        name = addName ? addName + "." + this.name : this.name;
        return samjs.mongo.mongoose.model(name, this.schema);
      };
      model.startup = function() {
        var base5, i, interfaceGenerator, interfaceGenerators, interfaces, len, name, ref;
        this.dbModel = this.dbModelGenerators[this.name].bind(this)();
        mongo.debug("model " + this.name + " - loaded");
        ref = this.interfaceGenerators;
        for (name in ref) {
          interfaceGenerators = ref[name];
          interfaces = (base5 = this.interfaces)[name] != null ? base5[name] : base5[name] = [];
          for (i = 0, len = interfaceGenerators.length; i < len; i++) {
            interfaceGenerator = interfaceGenerators[i];
            interfaces.push(interfaceGenerator());
          }
        }
        return samjs.Promise.resolve();
      };
      model.processMutators = function(query, socket, type) {
        return new Promise((function(_this) {
          return function(resolve, reject) {
            var i, len, mutator, ref;
            if (!((query != null) || (socket != null) || (type != null))) {
              return reject();
            }
            ref = _this.mutators[type];
            for (i = 0, len = ref.length; i < len; i++) {
              mutator = ref[i];
              try {
                query = mutator.bind(_this)(query, socket);
              } catch (_error) {
                return reject();
              }
            }
            return resolve(query);
          };
        })(this));
      };
      model.find = function(query, socket, addName) {
        query = samjs.mongo.cleanQuery(query);
        return this.processMutators.bind(this)(query, socket, "find").then((function(_this) {
          return function(query) {
            return new Promise(function(resolve, reject) {
              var dbModel;
              dbModel = addName ? _this.dbModels[addName + "." + _this.name] : _this.dbModel;
              return dbModel.find(query.find, query.fields, query.options, function(err, data) {
                if (err != null) {
                  return reject(err);
                }
                return resolve(data);
              });
            });
          };
        })(this));
      };
      model.interfaceGenerators[model.name].push(function(addName) {
        return function(socket) {
          mongo.debug("listening on " + this.name + ".find");
          return socket.on("find", (function(_this) {
            return function(request) {
              if ((request != null ? request.token : void 0) != null) {
                return _this.find(request.content, socket, addName).then(function(data) {
                  return {
                    success: true,
                    content: data
                  };
                })["catch"](function(err) {
                  console.log(err);
                  return {
                    success: false,
                    content: void 0
                  };
                }).then(function(response) {
                  return socket.emit("find." + request.token, response);
                });
              }
            };
          })(this));
        };
      });
      model.count = function(query, socket, addName) {
        query = samjs.mongo.cleanQuery(query);
        return this.processMutators.bind(this)(query, socket, "find").then((function(_this) {
          return function(query) {
            return new Promise(function(resolve, reject) {
              var dbModel;
              dbModel = addName ? _this.dbModels[addName + "." + _this.name] : _this.dbModel;
              return dbModel.find(query.find, null, query.options).count(function(err, count) {
                if (err != null) {
                  return reject(err);
                }
                return resolve(count);
              });
            });
          };
        })(this));
      };
      model.interfaceGenerators[model.name].push(function(addName) {
        return function(socket) {
          mongo.debug("listening on " + this.name + ".count");
          return socket.on("count", (function(_this) {
            return function(request) {
              if ((request != null ? request.token : void 0) != null) {
                return _this.count(request.content, socket, addName).then(function(count) {
                  return {
                    success: true,
                    content: count
                  };
                })["catch"](function(err) {
                  return {
                    success: false,
                    content: void 0
                  };
                }).then(function(response) {
                  return socket.emit("count." + request.token, response);
                });
              }
            };
          })(this));
        };
      });
      model.insert = function(query, socket, addName) {
        return this.processMutators.bind(this)(query, socket, "insert").then((function(_this) {
          return function(query) {
            return new Promise(function(resolve, reject) {
              var dbModel;
              dbModel = addName ? _this.dbModels[addName + "." + _this.name] : _this.dbModel;
              return dbModel.create(query, function(err, obj) {
                if (err != null) {
                  return reject(err);
                }
                return resolve({
                  _id: obj._id
                });
              });
            });
          };
        })(this));
      };
      model.interfaceGenerators[model.name].push(function(addName) {
        return function(socket) {
          mongo.debug("listening on " + this.name + ".insert");
          return socket.on("insert", (function(_this) {
            return function(request) {
              if ((request != null ? request.token : void 0) != null) {
                return _this.insert(request.content, socket, addName).then(function(modelObj) {
                  socket.broadcast.emit("inserted", modelObj._id);
                  return {
                    success: true,
                    content: modelObj
                  };
                })["catch"](function(err) {
                  return {
                    success: false,
                    content: void 0
                  };
                }).then(function(response) {
                  return socket.emit("insert." + request.token, response);
                });
              }
            };
          })(this));
        };
      });
      model.update = function(query, socket, addName) {
        return this.processMutators.bind(this)(query, socket, "update").then((function(_this) {
          return function(query) {
            return new Promise(function(resolve, reject) {
              var dbModel;
              if (!((query.cond != null) && (query.doc != null))) {
                return reject();
              }
              dbModel = addName ? _this.dbModels[addName + "." + _this.name] : _this.dbModel;
              return dbModel.update(query.cond, query.doc, function(err) {
                if (err != null) {
                  return reject(err);
                }
                return _this.find.bind(_this)({
                  find: query.cond,
                  fields: "_id"
                }, socket, addName).then(resolve);
              });
            });
          };
        })(this));
      };
      model.interfaceGenerators[model.name].push(function(addName) {
        return function(socket) {
          mongo.debug("listening on " + this.name + ".update");
          return socket.on("update", (function(_this) {
            return function(request) {
              if ((request != null ? request.token : void 0) != null) {
                return _this.update(request.content, socket, addName).then(function(modelObj) {
                  socket.broadcast.emit("updated", modelObj._id);
                  return {
                    success: true,
                    content: modelObj
                  };
                })["catch"](function(err) {
                  return {
                    success: false,
                    content: void 0
                  };
                }).then(function(response) {
                  return socket.emit("update." + request.token, response);
                });
              }
            };
          })(this));
        };
      });
      model.remove = function(query, socket, addName) {
        return this.processMutators.bind(this)(query, socket, "remove").then((function(_this) {
          return function(query) {
            return new Promise(function(resolve, reject) {
              var dbModel;
              dbModel = addName ? _this.dbModels[addName + "." + _this.name] : _this.dbModel;
              return _this.find.bind(_this)({
                find: query,
                fields: "_id"
              }, socket, addName).then(function(results) {
                if (results.length > 0) {
                  return dbModel.remove(query, function(err) {
                    if (err != null) {
                      return reject(err);
                    }
                    return resolve(results);
                  });
                } else {
                  return resolve([]);
                }
              })["catch"](reject);
            });
          };
        })(this));
      };
      model.interfaceGenerators[model.name].push(function(addName) {
        return function(socket) {
          mongo.debug("listening on " + this.name + ".remove");
          return socket.on("remove", (function(_this) {
            return function(request) {
              if ((request != null ? request.token : void 0) != null) {
                return _this.remove(request.content, socket, addName).then(function(id) {
                  socket.broadcast.emit("removed", id);
                  return {
                    success: true,
                    content: id
                  };
                })["catch"](function() {
                  return {
                    success: false,
                    content: void 0
                  };
                }).then(function(response) {
                  return socket.emit("remove." + request.token, response);
                });
              }
            };
          })(this));
        };
      });
      ref = model.plugins;
      for (name in ref) {
        options = ref[name];
        if (this._plugins[name] == null) {
          throw new Error(name + " mongo plugin not found");
        }
        model = this._plugins[name].bind(model)(options);
        if (!samjs.util.isObject(model)) {
          throw new Error("mongo plugins need to return the model");
        }
      }
      return model;
    };
  };

}).call(this);
