((app)->
  'use strict'

  VirtualNetworks = ($scope, $http) ->
    this.init($scope, $http)
    return

  p = VirtualNetworks.prototype

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
    this.cached_list = {}
    this.$http({
      method  : 'GET'
      url     : 'api/vn'
      params  : {}
    }).success((response, status, headers, config, statusText) ->
      console.log(config);
      parent.cached_list = response
      console.log(parent.cached_list)
      callback.call(this, parent.cached_list)
    )
    return
  
  p.add = (item, callback)->
    $scope = this.$scope
    this.$http({
      method  : 'POST'
      url     : 'api/vn'
      data    : {
        network_name : item.network_name
        network_descr : item.network_descr
        vdn_scope : item.vdn_scope
        vlan : item.vlan
      }
    }).success((response) ->
      $scope.$broadcast('changeVirtualNetworks')
      $scope.$broadcast('changeVlans') if item.vlan
      callback.call(this, response.data)
    )
    return
  
  p.remove = (item, callback)->
    $scope = this.$scope
    this.$http({
      method  : 'DELETE'
      url     : 'api/vn/'+item.vw_id
      data    : {
        with_vlan : item.delete_with_vlan
        vlan : item.vlan
      }
    }).success((response) ->
      $scope.$broadcast('changeVirtualNetworks')
      $scope.$broadcast('changeVlans') if item.vlan
      callback.call(this, response)
    )
    return

  #p.find = (item, callback)->
  #  $scope = this.$scope

    #vns = this.cached_list

    #for key,vn of vns
    #  console.log("VN:"+vn)
    #  if item.vni == vn.vn_id && item['multicast-address'] == vn.vn_mcaddr
    #    callback.call(this, vn)
    #return
  p.find = (item)->
    vns = this.cached_list
    for key,vn of vns
      console.log("Finding")
      console.log(vn)
      if item.vni == vn.vni_id && item['multicast-address'] == vn.vn_mcaddr
        return vn
    return

  app.VirtualNetworks = VirtualNetworks
  return
) this.app

