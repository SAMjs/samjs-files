(function() {
  var calculate, extname, notfound;

  extname = require('path').extname;

  calculate = require('etag');

  notfound = {
    ENOENT: true,
    ENAMETOOLONG: true,
    ENOTDIR: true
  };

  module.exports = function(samjs) {
    var fs;
    fs = samjs.Promise.promisifyAll(require('fs'));
    return function*(next) {
      var model, path, splitted, token, url;
      url = this.request.url;
      if (url.indexOf('/samjsfiles/') === 0) {
        url = url.slice(12);
        splitted = url.split("?");
        path = splitted[0];
        token = splitted[1];
        splitted = path.split("/");
        model = splitted.shift();
        if (samjs.models[model] != null) {
          return (yield samjs.models[model].getByToken(splitted.join("/"), token).then((function(_this) {
            return function(file) {
              path = file.fullpath;
              return fs.statAsync(path).then(function(stats) {
                var base, fresh;
                if (!((stats != null) || (stats.isFile() != null))) {
                  return _this["throw"](404);
                }
                _this.response.status = 200;
                _this.response.lastModified = stats.mtime;
                _this.response.length = stats.size;
                _this.response.type = extname(path);
                if ((base = _this.response).etag == null) {
                  base.etag = calculate(stats, {
                    weak: true
                  });
                }
                fresh = _this.request.fresh;
                switch (_this.request.method) {
                  case 'HEAD':
                    _this.response.status = fresh != null ? fresh : {
                      304: 200
                    };
                    break;
                  case 'GET':
                    if (fresh) {
                      _this.response.status = 304;
                    } else {
                      _this.body = fs.createReadStream(path);
                    }
                }
                return stats;
              })["catch"](function(e) {
                return _this["throw"](403);
              });
            };
          })(this)));
        } else {
          return (yield this["throw"](404));
        }
      } else {
        return (yield next);
      }
    };
  };

}).call(this);
