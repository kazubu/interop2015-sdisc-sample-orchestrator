((app)->
  'use strict'

  ArrayItems = ($scope)->
    this.init($scope)
    return

  p = ArrayItems.prototype

  p.init = ($scope)->
    this.$scope = $scope
    this.items = new Array
    this.serial = 0
    return

  p.setCurrentItem = (item)->
    this.current = item
    return

  p.getCurrentItem = ()->
    return this.current

  p.list = (callback)->
    callback.call(this, this.items)
    return
  
  p.add = (item, callback)->
    this.serial += 1
    item.id = "id_" + this.serial
    $scope = this.$scope
    this.items.push(item)
    $scope.$broadcast('changeItems')
    callback.call(this, item)
    return
  
  p.remove = (_item, callback)->
    id = _item.id
    tmp = new Array

    for item in this.items
      tmp.push(item) if _item.id != item.id
    this. items = tmp
    this.$scope.$broadcast('changeItems')
    callback.call(this, item)

  app.ArrayItems = ArrayItems
  return
) this.app

