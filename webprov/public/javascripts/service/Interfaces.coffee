((app)->
  'use strict'

  Interfaces = ($scope, $http) ->
    this.init($scope, $http)
    return

  p = Interfaces.prototype

  p.init = ($scope, $http)->
    this.$http = $http
    this.$scope = $scope
    return

  p.setCurrentItem = (item)->
    this.current = item
    return

  p.getCurrentItem = ()->
    return this.current

  p.list = (callback)->
    this.$http({
      method  : 'GET'
      url     : 'api/interface_config'
      params  : {}
    }).success((response, status, headers, config, statusText) ->
      console.log(config);
      callback.call(this, response)
    )
    return

  p.available_list = (callback)->
    this.$http({
      method  : 'GET'
      url     : 'api/interface'
      params  : {}
    }).success((response, status, headers, config, statusText) ->
      console.log(config)
      callback.call(this, response)
    )
    return
  
  p.post_interface = (item, callback)->
    console.log("posting")
    console.log(item)
    $scope = this.$scope
    this.$http({
      method  : 'POST'
      url     : 'api/interface/'
      data    : item
    }).success((response) ->
      $scope.$broadcast('changeInterfaces')
      callback.call(this, response.data)
    )
    return
  
  p.remove = (item, callback)->
    $scope = this.$scope
    this.$http({
      method  : 'DELETE'
      url     : 'api/interface/'
      data    : item
    }).success((response) ->
      $scope.$broadcast('changeInterfaces')
      callback.call(this, response)
    )
    return

  app.Interfaces = Interfaces
  return
) this.app

