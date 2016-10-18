Vue = require("vue")
Vue.config.debug = true
Router = require("/home/peaul/dev/vue-dev-server/node_modules/vue-router/dist/vue-router.js")
Vue.use(Router)
routes = [
  {path: "/basic", component: require("./basic.vue")},

]
router = new Router({routes:[
  {path: "/basic", component: require("./basic.vue")},

  {path:"/",component: require("/home/peaul/dev/vue-dev-server/app/main.js")}
]})
router.afterEach(function(to) {
  document.title = to.path + " - vue-dev-server"
})
app = new Vue({
  data: function() {return {availableRoutes: routes}},
  template: "<router-view></router-view>",
  router: router
  }).$mount("#app")