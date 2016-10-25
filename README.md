# samjs-files

Adds a model and interface for file/folder interaction.

Client: [samjs-files-client](https://github.com/SAMjs/samjs-files-client)

## Getting Started
```sh
npm install --save samjs-files
npm install --save-dev samjs-files-client
```
## Usage

```js
// server-side
samjs
.plugins(require("samjs-files"))
.options()
.configs()
.models({
  name:"someFile",
  db:"files",
  files:"package.json",
  access: {
    read:true
  }

  },{
  name:"someFolder",
  db:"files",
  folders:"assets/",
  access: {
    read:true
  }
}
})
.startup(server)

// client-side
samjs.plugins(require("samjs-files-client"))

model1 = samjs.getFilesModel("someFile")
model1.get("package.json") // filename can be omitted when model only has one file
.then(function(response){
  // success
})
.catch(function(){
  // failed
})

model1.set("package.json","{'content':'newContent'}")
.then(function(){
  // success
})
.catch(function(){
  // failed
})

model1.on("update",function(){
  // file has changed
})

model2 = samjs.getFilesModel("someFolder")
model2.get("someFileInAssetsFolder").then(function(){
  // success
})
```

### model props

name | type | default | description
---: | --- | --- | ---
cache | Boolean | `false` | set `false` when files are large, many or seldom used. Will load the files in memory and activate a `fs.watch`
options | Object |`{encoding: null}` | will be passed to `fs.readFile`
access | Object | `{}` | use to control access, with, e.g. `samjs-files-auth`

### model hooks

each hook has to return its arguments.

name | arguments| description
---: | --- | ---
beforeGet | `{file, client}` | will be called before each `get`
afterGet | `data` | will be called after each `get`
beforeSet | `{data, file, client}` | will be called before each `set`
afterSet | `file` | will be called after each `set`
before_Set | `{data, file}` | will be called before each server-side `_set`
after_Set | `file` | will be called after each server-side `_set`
beforeCreate | `model` | will be called before model creation
afterCreate | `model` | will be called after model creation

example:
```js
samjs
.plugins(require("samjs-files"))
.options()
.configs()
.models({
  name:"someFile",
  db:"files",
  files:"package.json",
  access: {
    read: true
  },
  beforeGet: [
    function(obj) {
      if (notPermitted){
        throw new Error("no Permission")
      }
      return obj
    }
  ]
})
```

### plugins
plugins are activated on model level
```js
samjs
.plugins(require("samjs-files"),require("samjs-files-auth"))
.options()
.configs()
.models({
  name:"someFile",
  db:"files",
  files:"package.json",
  read:true,
  plugins: {
    "auth": null // or a options object to interact with the plugin
    }
  }
})
```
