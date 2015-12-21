(function() {
  var bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  module.exports = function(samjs) {
    var Mongo, URI, debug, mongoose, name;
    mongoose = samjs.Promise.promisifyAll(require("mongoose"));
    debug = samjs.debug("mongo");
    name = "mongo";
    URI = "mongoURI";
    return new (Mongo = (function() {
      function Mongo() {
        this.plugins = bind(this.plugins, this);
        this.mongoose = mongoose;
        this.mongoose.options.pluralization = false;
        this.name = name;
        this.URI = URI;
        this._plugins = {};
        this.processModel = require("./modelProcessor")(samjs, this).bind(this);
      }

      Mongo.prototype.plugins = function(plugins) {
        var k, results, v;
        results = [];
        for (k in plugins) {
          v = plugins[k];
          results.push(this._plugins[k] = v);
        }
        return results;
      };

      Mongo.prototype.cleanQuery = function(query) {
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

      Mongo.prototype.debug = function(name) {
        return samjs.debug("mongo:" + name);
      };

      Mongo.prototype.testConnection = function(string) {
        var options;
        debug("testing mongoose connection to '" + string + "'");
        options = {
          server: {
            auto_reconnect: false,
            socketOptions: {
              connectTimeoutMS: 200
            }
          }
        };
        return new samjs.Promise(function(resolve, reject) {
          var conn;
          if (!string) {
            reject();
          }
          conn = mongoose.createConnection(string, options);
          conn.once("open", function() {
            return conn.db.listCollections().toArray(function(err, collections) {
              if (!err && collections.length === 0) {
                conn.db.dropDatabase();
              }
              return conn.close(function() {
                if (err) {
                  return reject(err);
                } else {
                  debug("mongoose connection to '" + string + "' successful");
                  return resolve("db:" + conn.name + ";collections:" + collections.length);
                }
              });
            });
          });
          return conn.on("error", function(err) {
            debug("mongoose connection to '" + string + "' failed");
            return reject(err);
          });
        });
      };

      Mongo.prototype.startup = function() {
        debug("connecting with mongodb");
        return samjs.configs[samjs.options.mongoURI]._getBare().then(function(connectionString) {
          var conn;
          conn = mongoose.connection;
          return new Promise(function(resolve, reject) {
            conn.once("open", function() {
              debug("connected successfully with mongodb");
              return resolve();
            });
            conn.once("error", function(err) {
              debug("connecting failed with mongodb");
              return reject(err);
            });
            return mongoose.connect(connectionString);
          });
        });
      };

      Mongo.prototype.shutdown = function() {
        debug("closing mongoose connection");
        if ((mongoose.connection.readyState != null) === 0) {
          debug("mongoose connection already closed");
          return Promise.resolve();
        }
        return new Promise(function(resolve) {
          mongoose.connection.once("close", function() {
            debug("mongoose connection closed");
            return resolve();
          });
          return mongoose.connection.close();
        });
      };

      return Mongo;

    })());
  };

}).call(this);
