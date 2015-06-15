((module) ->
  'use strict'

  module.controller 'pageController', ($scope, $modal, $log, $timeout, VirtualNetworks, Vlans, Interfaces) ->
    $scope.show =
      vnlist: true
      vnadd: false
      vninfo: false
      iflist: false
      ifadd : false
      vlanlist: false
      vlanadd: false

    $scope.message = 
      type: 'alert-info'
      text: ''
      show: false

    $scope.modalMessage =
      yesno: false
      title: 'deftitle'
      text: 'deft'

    $scope.latest_vlans = []

    $scope.changePage = (type) ->
      console.log(type)
      for name, value of $scope.show
        if (name == type)
          $scope.show[name] = true
        else
          $scope.show[name] = false
      if type == 'vninfo'
        item = VirtualNetworks.getCurrentItem()
        console.log(item)
        $scope.active = item
        console.log($scope.active)
      if type == 'vlanadd'
        vlan = Vlans.getCurrentItem()
        console.log(vlan)
        $scope.active = vlan
        console.log($scope.active)
      if type == 'ifadd'
        intf = Interfaces.getCurrentItem()
        console.log(intf)
        $scope.active = intf 
        console.log($scope.active)
        
      return

    $scope.deleteVirtualNetwork = ()->
      item = VirtualNetworks.getCurrentItem()
      modalInstance = $scope.showModal({
        yesno: true
        title: 'Proceed to delete it?'
        text: 'Are you sure to delete network "'+item.network_name+'"?'
      })
      modalInstance.result.then(() ->
        progressInstance = $scope.showProgress()
        VirtualNetworks.remove(item, ()->
          $scope.changePage('vnlist')
          progressInstance.close()
          $scope.showMessage {
            type: 'alert-warning'
            text: 'deleted'
            show: true
          }
          return
        )
      , () ->
        $log.info "delete cancelled..."
        return
      )
      return
    

    $scope.showMessage = (msg) ->
      $scope.message = msg
      $log.info('hoge')
      $timeout(() ->
        $scope.message.show = false
        return
      ,3000)
      return

    $scope.showModal = (msg) ->
      $scope.modalMessage = msg
      modalInstance = $modal.open({
        templateUrl: 'modal'
        controller: 'modalController'
        size: 'lg'
        resolve: {
          modalMessage: () ->
            return $scope.modalMessage
        }
      }
      )

    $scope.showProgress = () ->
      modalInstance = $modal.open({
        templateUrl: 'progress'
        controller: 'progressController'
        size: 'lg'
        resolve: {}
      }
      )

    return

  module.controller 'modalController', ($scope, $modalInstance, modalMessage) ->
    $scope.modalMessage = modalMessage
    $scope.ok = () ->
      $modalInstance.close()
      return
    $scope.cancel = () ->
      $modalInstance.dismiss('cancel')
      return
    return

  module.controller 'progressController', ($scope, $modalInstance) ->
    return

  module.controller 'virtualNetworkListController', ($scope, $log, VirtualNetworks, Vlans) ->
    $scope.refreshList = () ->
      progressInstance = $scope.showProgress()
      VirtualNetworks.list((list)->
        $scope.vns = list
        Vlans.list((data) ->
          $scope.vlans = data
          for vnkey, vn of $scope.vns
            for vkey, vlan of $scope.vlans
              if vlan.vxlan == undefined
                continue
              if vlan.vxlan.vni == vn.vn_id && vlan.vxlan['multicast-group'] == vn.vn_mcaddr
                $scope.vns[vnkey].vlan = vlan
          progressInstance.close()
        )
        return
      )

    $scope.refreshList()

    $scope.show = (item) ->
      VirtualNetworks.setCurrentItem(item)
      $scope.$parent.changePage('vninfo')
      return

    $scope.$on('changeVirtualNetworks', ()->
      $scope.refreshList()
    )

    return
    
  module.controller 'interfaceListController', ($scope, $log, Interfaces, Vlans) ->
    $scope.refreshList = () ->
      progressInstance = $scope.showProgress()
      Interfaces.list((list)->
        console.log(list)
        $scope.interfaces = list
        for intfkey, intf of $scope.interfaces
          if (a = intf) != undefined && (a = a.unit) != undefined && (a = a.family) != undefined && (a = a['ethernet-switching']) != undefined 
            if a['interface-mode'] == undefined
              $scope.interfaces[intfkey].unit.family['ethernet-switching']['interface-mode'] = 'access'
            if (a = a.vlan) != undefined && (a = a.members) != undefined 
              if !Array.isArray(intf.unit.family['ethernet-switching'].vlan.members)
                $scope.interfaces[intfkey].unit.family['ethernet-switching'].vlan.members = [intf.unit.family['ethernet-switching'].vlan.members]
        progressInstance.close()
      )

    $scope.refreshList()

    $scope.show = (item) ->
      Interfaces.setCurrentItem(item)
      $scope.$parent.changePage('ifadd')
      return

    $scope.$on('changeInterfaces', ()->
      $scope.refreshList()
    )
      

    return


  module.controller 'vlanListController', ($scope, $log, Vlans, VirtualNetworks, Interfaces) ->
    $scope.refreshList = () ->
      progressInstance = $scope.showProgress()
      Vlans.list((list)->
        $scope.vlans = list

        $scope.vns = {}
        VirtualNetworks.list((data)->
          $scope.vns = data
          for vkey, vlan of $scope.vlans
            for vnkey,vn of $scope.vns
              if vlan.vxlan == undefined
                continue
              if vlan.vxlan.vni == vn.vn_id && vlan.vxlan['multicast-group'] == vn.vn_mcaddr
                $scope.vlans[vkey].vn = vn
          progressInstance.close()
          $scope.$parent.latest_vlans = $scope.vlans
        )
        return
      )

    $scope.refreshList()

    $scope.show = (vlan) ->
      Vlans.setCurrentItem(vlan)
      $scope.$parent.changePage('vlanadd')
      return

    $scope.$on('changeVlans', ()->
      $scope.refreshList()
    )
    
    return

  module.controller 'vnAddController', ($scope, $log, VirtualNetworks, Vlans) ->
    $scope.item = {}
    $scope.selectable_vlans = null

    $scope.addItem = () ->
      if(!$scope.addItemForm.$valid)
        alert('input err')
        return
      modalInstance = $scope.$parent.showModal({
        yesno: true
        title: 'Proceed to create new network?'
        text: 'Are you sure to create new network?'
      })
      modalInstance.result.then(() ->
        modalInstance = $scope.$parent.showProgress()
        VirtualNetworks.add($scope.item, (data) ->
          modalInstance.close()
          $scope.$parent.showMessage({
            type: 'alert-info'
            text: 'added.'
            show: true
          })
          $scope.item = {}
          $scope.selectable_vlans = null
          $scope.$parent.changePage('vnlist')
        )
      , () ->
        $log.info "create cancelled..."
        return
      )

    $scope.getSelectableVlans = () ->
      result = []
      if($scope.selectable_vlans != null)
        return
      if(!$scope.item)
        alert('item is null...')
        return
      modalInstance = $scope.$parent.showProgress()
      Vlans.list((list)->
        $scope.vlans = list
        for vkey, vlan of  $scope.vlans
          console.log(vlan)
          # 新規作成なのでIgnore
          #if vlan.vxlan != undefined && vlan.vxlan.vni == $scope.item.vn_id && vlan.vxlan['multicast-group'] == $scope.item.vn_mcaddr
          #  console.log("unshift")
          #  result.unshift vlan
          if vlan['l3-interface'] == undefined && (vlan.vxlan == undefined || (vlan.vxlan.vni == undefined && vlan.vxlan['multicast-group'] == undefined))
            console.log("push")
            result.push vlan
        modalInstance.close()
        console.log("finished!")
        console.log(result)
        return $scope.selectable_vlans = result
      )

    $scope.setVlan = (vlan) ->
      console.log(vlan)
      $scope.item.vlan = vlan
      console.log($scope.item)
      return


    return

  module.controller 'vlanAddController', ($scope, $log, Vlans, VirtualNetworks) ->
    $scope.vlan = {}
    
    $scope.addVlan = (vlan) ->
      if(!$scope.addVlanForm.$valid)
        alert('input error')
        return
      $scope.vlan = vlan

      if vlan.new
        modalInstance = $scope.$parent.showModal({
          yesno: true
          title: 'Proceed to create a VLAN?'
          text: 'Are you sure to create VLAN?'
        })
      else
        modalInstance = $scope.$parent.showModal({
          yesno: true
          title: 'Proceed to change the VLAN Configuration?'
          text: 'Are you sure to change the VLAN Configuration?'
        })

      modalInstance.result.then(() ->
        modalInstance = $scope.$parent.showProgress()
        Vlans.post_vlan($scope.vlan, (data) ->
          modalInstance.close()
          $scope.$parent.showMessage({
            type: 'alert-info'
            text: 'completed.'
            show: true
          })
          $scope.$parent.changePage('vlanlist')
          $scope.vlan = {}
        )
      , () ->
        $log.info "vlan add cancelled..."
        return
      )
      return

    $scope.deleteVlan = (vlan) ->
      $scope.vlan = vlan

      modalInstance = $scope.$parent.showModal({
        yesno: true
        title: 'Proceed to delete the VLAN?'
        text: 'Are you sure to delete the VLAN?'
      })
      modalInstance.result.then(() ->
        modalInstance = $scope.$parent.showProgress()
        Vlans.remove($scope.vlan, (data) ->
          modalInstance.close()
          $scope.$parent.showMessage({
            type: 'alert-info'
            text: 'completed.'
            show: true
          })
          $scope.$parent.changePage('vlanlist')
          $scope.vlan = {}
        )
      , () ->
        $log.info "vlan delete cancelled..."
        return
      )
      return  

    $scope.getVirtualNetworks = ()->
      console.log("getVirtualNetworks called.")
      #result : [{vxlan:{vni:'1000','multicast-group':'239.1.1.1'}}, ...]
      result = []
      modalInstance = $scope.$parent.showProgress()
      VirtualNetworks.list((list)->
        console.log("VNs:")
        console.log(list)
        for vnkey, vn of list
          console.log("vn:"+vn.network_name)
          available = true
          for vlankey, vlan of $scope.latest_vlans
            if vlan.vxlan && vlan.vxlan.vni && vlan.vxlan['multicast-group'] && vlan.vxlan.vni == vn.vn_id && vlan.vxlan['multicast-group'] == vn.vn_mcaddr
              console.log("is not available")
              available = false
          if $scope.$parent.active.vxlan && $scope.$parent.active.vxlan.vni && $scope.$parent.active.vxlan['multicast-group'] && $scope.$parent.active.vxlan.vni == vn.vn_id && $scope.$parent.active.vxlan['multicast-group'] == vn.vn_mcaddr
            console.log("is currently selected")
            $scope.$parent.active.vxlan.name = vn.network_name
            available = true
          if available
            console.log("is available!")
            result.push({vxlan: {name: vn.network_name, vni: vn.vn_id, 'multicast-group': vn.vn_mcaddr}})
        $scope.available_vns = result
        console.log("available vns:")
        console.log($scope.available_vns)
        modalInstance.close()
      )
      return

    $scope.getVirtualNetworks()


  module.controller 'interfaceAddController', ($scope, $log, Interfaces, Vlans) ->
    $scope.interface = $scope.$parent.active
    $scope.vlans = null
    $scope.if_vlans = []
    $scope.free_interfaces = []

    $scope.addInterface = (intf)->
      $scope.interface = intf
      console.log("AddInterface")
      console.log(intf)
      if intf.name == undefined
        alert("Interface is not selected!!!")
        return
      modalInstance = $scope.$parent.showModal({
        yesno: true
        title: 'Proceed to add the Interface?'
        text: 'Are you sure to add the Interface?'
      })
      modalInstance.result.then(() ->
        modalInstance = $scope.$parent.showProgress()
        Interfaces.post_interface($scope.interface, (data) ->
          modalInstance.close()
          $scope.$parent.showMessage({
            type: 'alert-info'
            text: 'completed.'
            show: true
          })
          $scope.$parent.changePage('iflist')
          $scope.interface = null
        )
      , () ->
        $log.info "interface add cancelled..."
        return
      )
      return

    $scope.deleteInterface = (intf)->
      $scope.interface = intf
      console.log("DeleteInterface")
      console.log(intf)
      modalInstance = $scope.$parent.showModal({
        yesno: true
        title: 'Proceed to add the Interface?'
        text: 'Are you sure to add the Interface?'
      })
      modalInstance.result.then(() ->
        modalInstance = $scope.$parent.showProgress()
        Interfaces.remove($scope.interface, (data) ->
          modalInstance.close()
          $scope.$parent.showMessage({
            type: 'alert-info'
            text: 'completed.'
            show: true
          })
          $scope.$parent.changePage('iflist')
          $scope.interface = null
        )
      , () ->
        $log.info "interface add cancelled..."
        return
      )
      return

    # vlan_listでtrueなVLANをIFのListに入れる
    $scope.refreshVlan = (index)->
      result = []
      for vkey, vlan of $scope.if_vlans
        console.log(vkey)
        console.log(index)
        console.log(vlan)
        if index != null && index != undefined && vlan.enabled && vkey != index
          console.log("access interface have to have only one vlan.")
          vlan.enabled = false
          $scope.if_vlans[vkey].enabled = false
        if vlan.enabled
          console.log("enable!!")
          console.log(vlan)
          result.push(vlan.name)
      console.log(result)
      if result.length == 0
        delete $scope.interface.unit.family['ethernet-switching'].vlan
      if result.length > 0
        if $scope.interface.unit.family['ethernet-switching'].vlan == undefined
          $scope.interface.unit.family['ethernet-switching'].vlan = {}
        $scope.interface.unit.family['ethernet-switching'].vlan.members = result

      console.log($scope.if_vlans)
      console.log($scope.vlans)
      console.log($scope.interface)
      return

    $scope.getVlans = ()->
      result = []
      if($scope.vlans !=  null)
        return
      if(!$scope.interface)
        alert('interface is null???')
        return
      modalInstance = $scope.$parent.showProgress()
      Vlans.list((list)->
        $scope.vlans = list
        for vkey, vlan of $scope.vlans
          console.log(vlan.name)
          console.log($scope.interface)
          if (a = $scope.interface) != undefined && (a = a.unit) != undefined && (a = a.family) != undefined && (a = a['ethernet-switching']) != undefined
            console.log("1")
            if (a = a.vlan) != undefined && (a = a.members) != undefined
              if Array.isArray(a)
                for ivkey, ivlan of a
                  console.log(ivlan)
                  if ivlan == vlan.name
                    $scope.if_vlans[vkey] = { 'name' : vlan.name, 'vlan-id' : vlan['vlan-id'], 'enabled' : true }
              else
                if a == vlan.name
                  $scope.if_vlans[vkey] = { 'name' : vlan.name, 'vlan-id' : vlan['vlan-id'], 'enabled' : true }
          if $scope.if_vlans[vkey] == undefined
            $scope.if_vlans[vkey] = { 'name' : vlan.name, 'vlan-id' : vlan['vlan-id'], 'enabled' : false }
        modalInstance.close()
        console.log($scope.if_vlans)
        console.log($scope.vlans)
        return
      )

      return

    $scope.getFreeInterfaces = ()->
      if !$scope.interface.new
        console.log('this is not new. skipped...')
        return
      modalInstance = $scope.$parent.showProgress()
      Interfaces.available_list((alist)->
        console.log('alist:')
        console.log(alist)
        delete_list = []
        Interfaces.list((list)->
          for ikey, intf of list
            console.log('Cfg Intf:')
            console.log(intf)
            for akey, aintf of alist
              console.log('aintf:'+aintf)
              if intf['name'] == aintf
                console.log('pushing:'+aintf)
                delete_list.push(aintf)
          console.log('delete_list:')
          console.log(delete_list)
          for dkey, dintf of delete_list
            for akey, aintf of alist
              console.log("aintf:"+aintf)
              console.log("dintf:"+dintf)
              if dintf == aintf
                console.log(aintf + "is already used. skipping...")
                alist.splice(akey,1)
          modalInstance.close()
          $scope.free_interfaces = alist
          console.log("free_interfaces:")
          console.log($scope.free_interfaces)
        )
      )
      return 

    $scope.checkAccess = () ->
      vlan_count = null
      if $scope.interface.unit.family['ethernet-switching'].vlan == undefined
        vlan_count = 0
      else
        vlan_count = $scope.interface.unit.family['ethernet-switching'].vlan.members.length
      console.log(vlan_count)
      if(vlan_count > 1)
        alert('Access Interface must have only one Vlan!!')
        $scope.interface.unit.family['ethernet-switching']['interface-mode'] = 'trunk'
      return

    $scope.getVlans()
    $scope.getFreeInterfaces()


  return

) ProvModule

