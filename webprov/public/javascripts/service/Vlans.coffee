((app)->
  'use strict'

  Vlans = ($scope, $http) ->
    this.init($scope, $http)
    return

  p = Vlans.prototype

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
      url     : 'api/vlan'
      params  : {}
    }).success((response, status, headers, config, statusText) ->
      console.log(config);
      callback.call(this, response)
    )
    return
  
  p.post_vlans = (item, callback)->
    $scope = this.$scope
    this.$http({
      method  : 'POST'
      url     : 'api/vlan'
      data    : item.vlan_configs
    }).success((response) ->
      $scope.$broadcast('changeVlans')
      callback.call(this, response.data)
    )
    return

  p.post_vlan = (item, callback)->
    console.log("posting")
    console.log(item)
    $scope = this.$scope
    this.$http({
      method  : 'POST'
      url     : 'api/vlan/'+item.name
      data    : item
    }).success((response) ->
      $scope.$broadcast('changeVlans')
      callback.call(this, response.data)
    )
    return
  
  p.remove = (item, callback)->
    $scope = this.$scope
    this.$http({
      method  : 'DELETE'
      url     : 'api/vlan/'+item.name
      data    : {}
    }).success((response) ->
      $scope.$broadcast('changeVlans')
      callback.call(this, response)
    )
    return

  app.Vlans = Vlans
  return
) this.app

