((module)->
  'use strict'

  module.factory('Vlans', ($rootScope, $http) ->
    console.log(app.Vlans)
    new app.Vlans($rootScope, $http)
  )

  module.factory('VirtualNetworks', ($rootScope, $http) ->
    console.log(app.VirtualNetworks)
    new app.VirtualNetworks($rootScope, $http)
  )

  module.factory('Interfaces', ($rootScope, $http) ->
    console.log(app.Interfaces)
    new app.Interfaces($rootScope, $http)
  )


  return
) ProvModule
