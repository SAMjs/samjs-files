<template lang="pug">
.samjs-files
  input#file(name="Datei" type="file" ref="input" @change="upload")
  br
  span {{status}}
  br
  button(@click="download") download
</template>

<script lang="coffee">
samjs = require("samjs-client")()
samjsFiles = require "samjs-files-client"
samjs.plugins(samjsFiles)
module.exports =
  computed:
    files: -> new samjs.Files("test")
  data: ->
    status: ""
    filename: "0poctzV.jpg"
  methods:
    upload: (e) ->
      @status = "uploading"
      file = e.target.files[0]
      @filename = file.name
      @files.set(path: file.name, data: file)
      .then => @status = "done"
      .catch (e) =>
        console.log (e)
        @status = "error"
    download: (e) ->
      @status = "downloading"
      @files.dlByHTTP(@filename)
      .then => @status = "done"
      .catch (e) =>
        console.log (e)
        @status = "error"
</script>
