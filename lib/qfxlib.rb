#!/usr/bin/env ruby

require '../../utils/xmlutils.rb'
require 'net/netconf'
require 'pp'
require 'json'

class Hash
  def symbolize_keys2!
    keys.each do |key|
      case (v = delete(key))
      when Hash
        v.symbolize_keys2!
      when Array
        v = v.map{|x| (x.symbolize_keys rescue x) }
      end
      self[(key.to_sym rescue key) || key] = v
    end
    self
  end
  def delete_nil_keys!
    keys.each do |key|
      case (v = delete(key))
      when Hash
        v.delete_nil_keys!
      when nil || "" || {}
        self.delete(key)
        next
      end
      if v == nil || v.length == 0
        self.delete(key)
        next
      end
      self[key] = v
    end
    self
  end

end

module QFX
  QFX_USER = "root"
  QFX_PASS = "Juniper"
  QFX_HOST = "172.27.113.125"

    class QFXLib
    
    @config = nil
    @interfaces = nil
    @vlans = nil

    @qfx_host = QFX_HOST
    @qfx_user = QFX_USER
    @qfx_pass = QFX_PASS

    attr_accessor :config, :interfaces, :vlans

    def initialize(_host=nil, _user=nil, _pass=nil)
      @qfx_host = _host unless _host.nil?
      @qfx_user = _user unless _user.nil?
      @qfx_pass = _pass unless _pass.nil?

      refresh
    end

    def refresh
      fetch_config
      fetch_interfaces
      fetch_vlans
    end

    def netconf_rpc
      Netconf::SSH.new({:target => @qfx_host, :username => @qfx_user, :password => @qfx_pass}) do |device|
        yield device
      end
    end

    # delete
    def delete_vlan(name)
      put_config delete_vlan_config(name)
    end

    def delete_interface(name)
      put_config delete_interface_config(name)
    end

    #set
    def set_vlan(vlans)
      # single input: {:name => "XXX", :"vlan-id" => "123", :vxlan => {:vni => "1111", :"multicast-group" => "239.1.1.1"}}
      # multiple input: [{:name => "XXX", :"vlan-id" => "123", :vxlan => {:vni => "1111", :"multicast-group" => "239.1.1.1"}}, ...]
      vlans = [vlans] if vlans.class != Array

      configs = []
      vlans.each{|vlan|
        vlan.symbolize_keys2!
        vlan.delete_nil_keys!
        puts "retrieved config:" + vlan.to_s
        configs << delete_vlan_config(vlan[:name]) 
        configs << make_vlan_config(vlan[:name], vlan)
      }
      put_config configs
    end

    def set_interface(interfaces)
      # single input: {:name=>"xe-0/0/0", :unit=>{:name=>"0", :family=>{:"ethernet-switching"=>{:vlan=>{:members=>"vlan_name"}}}}
      # multiple input: [{:name=>"xe-0/0/0", :unit=>{:name=>"0", :family=>{:"ethernet-switching"=>{:vlan=>{:members=>"vlan_name"}}}}, ...]
      interfaces = [interfaces] if interfaces.class != Array

      configs = []
      interfaces.each{|interface|
        interface.symbolize_keys2!
        interface.delete_nil_keys!
        pp interface
        configs << delete_interface_config(interface[:name])
        configs << make_interface_config(interface[:name], interface)
      }
      put_config configs
    end

private

    def lock
      netconf_rpc{|x|
        x.rpc.lock 'candidate'
      }
    end

    def unlock
      netconf_rpc{|x|
        x.rpc.lock 'candidate'
      }
    end

    # Fetch Datas from QFX
    def fetch_config
      _config = nil
      netconf_rpc{|x| _config = x.rpc.get_config }
      _config = _config.xpath('//configuration')[0]

      _config.keys.each{|attr| _config.delete attr}

      _config = XMLUtils.xml2hash(_config.to_s)
      @config = QFX::Configurations.new(_config[:configuration])
    end

    def fetch_interfaces
      _interfaces = nil
      netconf_rpc{|x| _interfaces = x.rpc.get_interface_information({:interface_name => "[gxe][et]-*", :terse => ""}) }
      _interfaces = _interfaces.xpath('//interface-information')[0].to_xml
      _interfaces.gsub!("junos:","").gsub!("\n","")
      result = []

      XMLUtils.xml2hash(_interfaces.to_s)[:"interface-information"][:"physical-interface"].each{|intf| result << intf[:name]}
      @interfaces = result
    end

    def fetch_vlans
      _vlans = nil
      netconf_rpc{|x| _vlans = x.rpc.get_vlan_information }
      _vlans = _vlans.xpath('//l2ng-l2ald-vlan-instance-information')[0].to_xml
      _vlans.gsub!("junos:","").gsub!("\n","")
      result = {}

      XMLUtils.xml2hash(_vlans.to_s)[:"l2ng-l2ald-vlan-instance-information"][:"l2ng-l2ald-vlan-instance-group"].each{|vlan|
        result[vlan[:"l2ng-l2rtb-vlan-name"]] = {:vlan_id => vlan[:"l2ng-l2rtb-vlan-tag"]}

      }
      @vlans = result
    end

    # Push and Commit configurations to QFX
    def put_config(config)
      config = [config] if config.class != Array

      netconf_rpc{|x|
        x.rpc.lock 'candidate'
        begin
          config.each{|cfg|
            puts "sending an configurations:"+cfg.to_xml.to_s
            x.rpc.edit_config cfg
          }
        rescue
          x.rpc.discard_changes
          x.rpc.unlock 'candidate'
        end
        x.rpc.commit
        x.rpc.unlock 'candidate'
      }
      refresh
      return true
    end

    # VLAN Delete Configuration Generator
    def delete_vlan_config(name)
      config = Nokogiri::XML::Builder.new{|x|
        x.configuration {
          x.vlans {
            x.vlan(:operation => "delete") {
              x.name name
            }
          }
        }
      }
      return config
    end

    # Interface Delete Configuration Generator
    def delete_interface_config(name)
      config = Nokogiri::XML::Builder.new{|x|
        x.configuration {
          x.interfaces {
            x.interface(:operation => "delete") {
              x.name name 
            }
          }
        }
      }
      return config
    end

    # VLAN Configuration Generator
    def make_vlan_config(name, vlan)
      vlan = vlan.to_hash if vlan.class == Vlan
      vlan_config = Nokogiri::XML::Builder.new{|x|
        x.configuration{
          x.vlans {
            x.vlan {
              x.name name
              x.send(:"vlan-id", vlan[:"vlan-id"])
              x.vxlan {
                x.vni vlan[:vxlan][:vni] unless vlan[:vxlan][:vni].nil?
                x.send(:"multicast-group", vlan[:vxlan][:"multicast-group"]) unless vlan[:vxlan][:"multicast-group"].nil?
              } unless vlan[:vxlan].nil?
            }
          }
        }
      }
      return vlan_config
    end

    # Interface Configuration Generator
    def make_interface_config(name, interface)
      interface = interface.to_hash if interface.class == Interface
      interface_config = Nokogiri::XML::Builder.new{|x|
        x.configuration{
          x.interfaces {
            x.interface {
              x.name name
              x.unit {
                i = 0
                units = interface[:unit].class == Array ? interface[:unit] : [interface[:unit]]
                units.each{|unit|
                  x.name (unit[:name].nil?? "0" : unit[:name])
                  x.family {
                    unit[:family].each_key{|family|
                      puts "family:"+family.to_s
                      pp unit[:family][family]
                      next if family.to_s != "ethernet-switching"
                      # {"interface-mode"=>"trunk", "vlan"=>{"members"=>["v1001"]}}
                      puts "not skipped"
                      x.send(family.to_sym) {
                        x.send(:"interface-mode", unit[:family][family][:"interface-mode"]) unless unit[:family][family].nil? || unit[:family][family][:"interface-mode"].nil?
                        x.vlan {
                          members = unit[:family][family][:vlan][:members].class == Array ? unit[:family][family][:vlan][:members] : [unit[:family][family][:vlan][:members]] 
                          members.each{|member|
                            x.members member
                          } unless  members.nil? || members == [nil]
                        } unless unit[:family][family][:vlan].nil?
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      return interface_config
    end
  end

  class Configurations
    def initialize(config=nil)
      # loop回してvlan_add, interface_addを呼びまくる
      @vlans = {}
      @interfaces = {}

      unless config.nil?
        unless config[:vlans].nil? || config[:vlans][:vlan].nil?
          config[:vlans][:vlan].each{|vlan|
            vlan_add(vlan)
          }
        end
        unless config[:interfaces].nil? || config[:interfaces][:interface].nil?
          config[:interfaces][:interface].each{|intf|
            interface_add(intf)
          }
        end
      end
    end

    attr_accessor :vlans, :interfaces

    def vlans_hash
      result = {}
      @vlans.each_key{|vlans_key|
        result[vlans_key] = @vlans[vlans_key].to_hash
      }
      return result
    end

    def vlans_ary
      result = []
      @vlans.each{|vlan|
        result << vlan[1].to_hash
      }
      return result
    end

    def interfaces_hash
      result = {}
      @interfaces.each_key{|interfaces_key|
        result[vlans_key] = @interfaces[interfaces_key].to_hash
      }
      return result
    end

    def interfaces_ary
      result = []
      @interfaces.each{|interface|
        result << interface[1].to_hash
      }
      return result
    end

    def vlan_add(vlan_config)
      vlan_name = vlan_config[:name]
      @vlans[vlan_name] =  Vlan.new(vlan_config)
    end

    def interface_add(interface_config)
      interface_name = interface_config[:name]
      @interfaces[interface_name] = Interface.new(interface_config)
      puts "adding: "+interface_name
    end

    def to_hash
    end
  end

  class Vlan
    def initialize(vlan_config=nil)
      @name = vlan_config[:name] unless vlan_config[:name].nil?
      @vlan_id = nil
      @vxlan = {}
      @l3_interface = vlan_config[:"l3-interface"] unless vlan_config[:"l3-interface"].nil?
      unless vlan_config.nil?
        @vlan_id = vlan_config[:"vlan-id"] unless vlan_config[:"vlan-id"].nil?
        @vxlan = vlan_config[:vxlan] unless vlan_config[:vxlan].nil?
      end
    end

    attr_accessor :vlan_id, :vxlan, :l3_interface

    def to_hash
      result = {}
      result[:name] = @name unless @name.nil?
      result[:"vlan-id"] = @vlan_id
      result[:"l3-interface"] = @l3_interface unless @l3_interface.nil?
      result[:vxlan] = @vxlan unless @vxlan.nil? or @vxlan.length == 0
      return result
    end
  end

  class Interface
    def initialize(interface_config=nil)
      @name = interface_config[:name] unless interface_config[:name].nil?
      @units = {}
      @units[interface_config[:unit][:name]] = Unit.new(interface_config[:unit]) if interface_config[:unit].class == Hash
      interface_config[:unit].each{|unit|
        @units[unit[:name]] = Unit.new(unit)
      } if interface_config[:unit].class == Array
    end
    attr_accessor :units

    def to_hash
      result = {}
      result[:name] = @name unless @name.nil?
      result[:unit] = []
      i = 0
      @units.each_key{|unit_name|
        result[:unit][i] = @units[unit_name].to_hash
        result[:unit][i][:name] = unit_name
        i += 1
      }
      if result[:unit].length == 1
        result[:unit] = result[:unit][0]
      end
      return result
    end
  end

  class Unit
    def initialize(unit_config=nil)
      @family = []
      unless unit_config[:family].nil?
        @family << Ethernet_Switching.new(unit_config[:family][:"ethernet-switching"]) unless unit_config[:family][:"ethernet-switching"].nil?
      end

      def to_hash
        result = {}
        result[:family] = {}
        @family.each{|family|
          result[:family].update family.to_hash
        }
        return result
      end
    end
  end

  class Ethernet_Switching
    def initialize(ethernet_switching_config=nil)
      @vlan_members = []
      @interface_mode = nil
      unless ethernet_switching_config.nil?
        unless ethernet_switching_config.class != Hash || ethernet_switching_config[:vlan].nil?
          @vlan_members = ethernet_switching_config[:vlan][:members] unless ethernet_switching_config[:vlan][:members].nil?
        end
        @interface_mode = ethernet_switching_config[:"interface-mode"] unless ethernet_switching_config.class != Hash || ethernet_switching_config[:"interface-mode"].nil?
      end
    end
    attr_accessor :vlan_members, :interface_mode

    def to_hash
      result = {}
      result[:vlan] = {} unless @vlan_members.length == 0
      result[:vlan][:members] = @vlan_members unless @vlan_members.length == 0
      result[:"interface-mode"] = @interface_mode unless @interface_mode.nil?
      return {:"ethernet-switching" => result}
    end
  end
end
