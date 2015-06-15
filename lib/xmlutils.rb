#!/usr/bin/env ruby

require 'rexml/document'

class XMLUtils
  class << self
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
end
