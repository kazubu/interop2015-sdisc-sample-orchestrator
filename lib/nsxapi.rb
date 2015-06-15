#!/usr/bin/env ruby

require 'rest-client'
require 'rexml/document'

class NSXManagerApi
  @hostname = nil
  @port = 443
  @user = nil
  @pass = nil
  @schema = "https"

  @vcenter_hostname = nil

  def initialize(_hostname, _port, _user, _pass)
    setManager(_hostname, _port, _user, _pass, "https")
    retrievevCenterConfig
  end

  ### virtualWires
  def createVirtualWire(_scope, _name, _description, _tenantId, _mode = :MULTICAST_MODE)
    response = RestClient.post(getAPIBaseURL+"vdn/scopes/#{_scope}/virtualwires", 
                              hash2xml({:virtualWireCreateSpec => {
                                :name => _name,
                                :description => _description,
                                :tenantId => _tenantId,
                                :controlPlaneMode => _mode }}),
                              {:accept => :xml, :content_type => :xml})
    return response # virtualwire-XX
  end

  def getVirtualWire(_name)
    response = RestClient.get(getAPIBaseURL+"vdn/virtualwires/"+_name)
    xml2hash(response)
  end

  def getVirtualWires(_scope = nil)
    response = RestClient.get(getAPIBaseURL+"vdn/"+ (_scope.nil? ? "" : "scopes/#{_scope}/") +"virtualwires")
    xml2hash(response)
  end

  def deleteVirtualWire(_name)
    response = RestClient.delete(getAPIBaseURL+"vdn/virtualwires/"+_name)
  end

  def addVnicToVirtualWire(_deviceUuid, _vnicVDID=0, _virtualwire)
    response = RestClient.post(getAPIBaseURL+"vdn/virtualwires/vm/vnic",
                               hash2xml({"com.vmware.vshield.vsm.inventory.dto.VnicDto" => {
                                  :objectId => _deviceUuid+".000",
                                  :vnicUuid => _deviceUuid+"."+format("%03d",_vnicVDID),
                                  :portgroupId => _virtualwire}}),
                                {:accept => :xml, :content_type => :xml})
    return response
  end

  def findVirtualWires(key, value)
    results = []
    vws = getVirtualWires
    vws[:virtualWires][:dataPage][:virtualWire].each do|vw|
      results << vw[:objectId] if vw[key] == value
    end
    results
  end
  
  private

  ### Private ###
  def setManager(_hostname, _port, _user, _pass, _schema)
     @hostname = _hostname unless _hostname.nil?
     @port = _port unless _port.nil?
     @user = _user unless _user.nil?
     @pass = _pass unless _pass.nil?
     @schema = _schema unless _schema.nil?
     raise "lack of required information" if (@hostname.nil? || @port.nil? || @user.nil? || @pass.nil? || @schema.nil? )
  end

  def getAPIBaseURL
    return @schema+"://"+@user+":"+@pass+"@"+@hostname+":"+@port.to_s+"/api/2.0/"
  end

  def retrievevCenterConfig
    response = RestClient.get(getAPIBaseURL+"services/vcconfig")
    @vcenter_hostname = xml2hash(response)[:vcInfo][:ipAddress]
  end

  ### Generic Utils ###
  def xml2hash(_body)
    xml_elem_to_hash(REXML::Document.new(_body))
  end
  def xml_elem_to_hash(elem)
    value = if elem.has_elements?
      children = {}
      elem.each_element do |e|
        children.merge!(xml_elem_to_hash(e)) do |k,v1,v2|
          v1.class == Array ?  v1 << v2 : [v1,v2]
        end
      end
      children
    else
      elem.text
    end
    return value if elem.name==""
    { elem.name.to_sym => value } 
  end

  def hash2xml(_hash)
    doc = REXML::Document.new
    doc << REXML::XMLDecl.new('1.0', 'UTF-8')

    root = doc.add_element(_hash.keys[0].to_s)
    xml_add_hash(root, _hash[_hash.keys[0]])

    return doc.to_s
  end

  def xml_add_hash(_elem, _hash)

    _hash.each_key{|key|
      new_elem = _elem.add_element(key.to_s)
      xml_add_hash(new_elem, _hash[key]) if _hash[key].class == Hash
      new_elem.add_text _hash[key].to_s if _hash[key].class == String or _hash[key].class == Symbol
    }
  end
end


