Webprov::App.controllers :api do
  require Padrino.root('/../lib/nsxapi.rb')
  require Padrino.root('/../lib/qfxlib.rb')

  # get :index, :map => '/foo/bar' do
  #   session[:foo] = 'bar'
  #   render 'index'
  # end

  # get :sample, :map => '/sample/url', :provides => [:any, :js] do
  #   case content_type
  #     when :js then ...
  #     else ...
  # end

  # get :foo, :with => :id do
  #   'Maps to url '/foo/#{params[:id]}''
  # end

  # get '/example' do
  #   'Hello world!'
  # end
  
  @nm = nil

  ###### Virtual Networks ######

  get :vn do
    result = []
    #@nm = NSXManagerApi.new(HOSTNAME, PORT, USER, PASS)
    nm_refresh
    #vws = @nm.getVirtualWires
    vws = @nm.getVirtualWires[:virtualWires][:dataPage][:virtualWire]
    vws = [vws] if vws.class != Array
    vws.each{|vw|
      result << make_vw_hash(vw)
    }
    return result.to_json
  end

  get :vn, :with => :id do
    puts params[:id]
    nm_refresh
    vw = @nm.getVirtualWire(params[:id])[:virtualWire]
    p vw
    return make_vw_hash(vw).to_json unless vw.nil?
    return {:result => :not_found}.to_json
  end

  # create vn
  post :vn do
    puts request.query_string
    req = JSON.parse(request.body.read)
    p req
    nm_refresh
    vw_name = @nm.createVirtualWire(VDNSCOPE, req["network_name"], req["network_descr"], "virtual wire tenant")
    unless req["vlan"].nil?
      puts "VLAN knob detected. creating vlan..."
      qfx_refresh
      vw = make_vw_hash(@nm.getVirtualWire(vw_name)[:virtualWire])
      vlan = req["vlan"]
      return '{"result":"duplicate"}' unless vlan["vxlan"].nil?
      vlan["vxlan"] = {"vni" => vw["vn_id"], "multicast-group" => vw["vn_mcaddr"]}
      @qfx.set_vlan(vlan)
    end
    puts req.to_json
  end

  # delete vn
  delete :vn, :with => :id do
    puts request.query_string
    req = JSON.parse(request.body.read)
    p req
    puts "Deleting: " + params[:id]
    nm_refresh
    unless req["vlan"].nil?
      puts "VLAN knob detected."
      vlan = req["vlan"]
      p vlan
      qfx_refresh
      if req["delete_with_vlan"]
        puts "Delete with VLAN knob detected. deleteing VLAN..."
        @qfx.delete_vlan(vlan)
      else
        puts "deleting VXLAN configuration of VLAN..."
        p vlan.delete("vxlan")
        @qfx.set_vlan(vlan)
      end
    end
    @nm.deleteVirtualWire(params[:id])
    return '{"result":"ok"}'
  end

  ###### VLANS ######

  get :vlan do
    qfx_refresh
    pp @qfx.config.vlans_ary
    return @qfx.config.vlans_ary.to_json
  end

  get :vlan, :with => :name do
    qfx_refresh
    return @qfx.config.vlans[params[:name]].to_hash.to_json unless @qfx.config.vlans[params[:name]].nil?
    return ""
  end

  # refresh
  post :vlan, :with => :name do
    begin
      qfx_refresh
      req = request.body.read
      req = JSON.parse(req)
      @qfx.set_vlan(req)
    rescue => e
      puts "ERROR:" + e.to_s
      return '{"result":"failed", "detail":"'+e.to_s+'"}'
    end
  end

  # refresh
  post :vlan do
    begin
      qfx_refresh
      req = request.body.read
      req = JSON.parse(req)

      configs = []
      req.each_key{|name|
        configs << [name, req[name]]
      }
      @qfx.set_vlan(configs)
    rescue => e
      puts "ERROR:" + e.to_s
      return '{"result":"failed", "detail":"'+e.to_s+'"}'
    end
  end

  delete :vlan, :with => :name do
    qfx_refresh
    interfaces = @qfx.config.interfaces_ary
    interfaces.each{|interface|
      if !interface[:unit].nil? && interface[:unit].class == Hash && !interface[:unit][:family].nil? && !interface[:unit][:family][:"ethernet-switching"].nil? && !interface[:unit][:family][:"ethernet-switching"][:vlan].nil?
        p "searching interfaces"
        vlan_members= interface[:unit][:family][:"ethernet-switching"][:vlan][:members]
        vlan_members = [vlan_members] if vlan_members.class != Array
        vlan_members.each{|vlan|
          p vlan
          if vlan == params[:name]
            return '{"result":"failed", "err":"1", "detail":"VLAN is already used."}'
          end
        }
      end
    }
    @qfx.delete_vlan params[:name]
    return '{"result":"success"}'
  end

  ###### Interfaces ######
  
  get :interface do
    qfx_refresh
    pp @qfx.interfaces
    return @qfx.interfaces.to_json
  end
  
  get :interface_config do
    qfx_refresh
    config = @qfx.config.interfaces_ary

    return @qfx.config.interfaces_ary.to_json
  end

  get :interface_config, :with => :name do
    qfx_refresh
    return @qfx.config.interfaces[params[:name]].to_hash.to_json unless @qfx.config.interfaces[params[:name]].nil?
  end

  post :interface do
    #begin
      qfx_refresh
      req = request.body.read
      req = JSON.parse(req)
      puts req.to_s
      @qfx.set_interface(req)
    #rescue => e
    #  puts "ERROR:" + e.to_s
    #  return '{"result":"failed", "detail":"'+e.to_s+'"}'
    #end
  end
  
  delete :interface do
    qfx_refresh
    req = request.body.read
    req = JSON.parse(req)
    puts req.to_s
    unless req["name"].nil?
      @qfx.delete_interface req["name"]
      return '{"result":"success"}'
    else
      return '{"result":"failed"}'
    end
  end
end
