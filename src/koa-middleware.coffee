# out: ../lib/koa-middleware.js
extname = require('path').extname
calculate = require('etag')
querystring = require "querystring"

notfound = {
  ENOENT: true,
  ENAMETOOLONG: true,
  ENOTDIR: true,
}

module.exports = (samjs) ->
  fs = samjs.Promise.promisifyAll(require('fs'))
  return (next) ->
    url = @request.url
    if url.indexOf('/samjsfiles/') == 0
      url = url.slice(12)
      splitted = url.split("?")
      path = splitted[0]
      token = splitted[1]
      splitted = path.split("/")
      model = splitted.shift()
      if samjs.models[model]?
        path = querystring.unescape(splitted.join("/"))
        yield samjs.models[model].getByToken(path,token)
        .then (file) =>
          path = file.fullpath
          fs.statAsync(path)
          .then (stats) =>
            return @throw(404) unless stats? or stats.isFile()?
            @response.status = 200
            @response.lastModified = stats.mtime
            @response.length = stats.size
            @response.type = extname(path)
            @response.etag ?= calculate stats, weak: true
            fresh = @request.fresh
            switch @request.method
              when 'HEAD'
                @response.status = fresh ? 304 : 200
                break
              when 'GET'
                if fresh
                  @response.status = 304
                else
                  @body = fs.createReadStream(path)
            return stats
          .catch (e) =>
            @throw(403)
      else
        yield @throw(404)
    else
      yield next
