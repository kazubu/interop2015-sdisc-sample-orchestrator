# Helper methods defined here can be accessed in any controller or view in the application

module Webprov
  class App
    module ApiHelper
      # def simple_helper_method
      # ...
      # end

      def make_vw_hash(vw)
        result = {
            "vw_id" => vw[:objectId],
            "vdn_scope" => vw[:vdnScopeId],
            "network_name" => vw[:name],
            "network_descr" => vw[:description],
            "vn_id" => vw[:vdnId],
            "vn_mcaddr" => vw[:multicastAddr],
            "instances" => []
          }
        return result
      end

      def make_vlan_hash(vlan)
        result = {}
        result["vlan_name"] = vlan[:name]
        result["vlan_id"] = vlan[:"vlan-id"]
        result["vxlan_id"] = vlan[:vxlan][:vni] unless vlan[:vxlan].nil? || vlan[:vxlan][:vni].nil?
        result["vxlan_mcaddr"] = vlan[:vxlan][:"multicast-group"] unless vlan[:vxlan].nil? || vlan[:vxlan][:"multicast-group"].nil?
      end

      def nm_refresh
        if @nm.nil?
          puts "nm is nil! refreshing..."
          @nm = NSXManagerApi.new(HOSTNAME, PORT, USER, PASS)
        end
      end

      def qfx_refresh
        if @qfx.nil?
          puts "qfx is nil! refreshing..."
          @qfx = QFX::QFXLib.new(QFX_HOSTNAME, QFX_USER, QFX_PASS) 
        end
      end
    end

    helpers ApiHelper
  end
end
