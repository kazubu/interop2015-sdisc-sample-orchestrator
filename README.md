#  VMware NSX for vSphere / QFX5100 VXLAN Integration Sample Orchestrator

## Description

_It is a demo software for Juniper Networks Booth of Interop Tokyo 2015 SDI Showcase._
_Please do not use this program in production environment._

This program provide a Web GUI for following features:

 * Creation a Virtual Network in VMware NSX for vSphere and Configure a VLAN/VXLAN in QFX5100.
 * Deletion a Virtual Network in VMware NSX for vSphere and VXLAN configuration from QFX5100.
 * Creation a VLAN/VXLAN configuration in QFX5100.
 * Deletion a VLAN configuration in QFX5100.
 * Edit a VLAN configuration in QFX5100.
 * Creation a Port configuration in QFX5100.
 * Deletion a Port configuration in QFX5100.
 * Attach an interface to VLAN in QFX5100.

The program written in Ruby and JavaScript with some libraries as below. All rights of these that this repository has included are under original developers.

 * Ruby
   * Padrino
   * net/netconf
 * JavaScript
   * Angular.JS
   * ui-bootstrap
 * HTML/CSS
   * Bootstrap

## Requirement environment

This program require following environments:

 * Server Environment
   * Ubuntu 14.04 LTS (Or maybe any linux but not tested.)
   * Ruby 1.9.3 or above with some rubygems.
 * Network Environment
   * VMware NSX for vSphere 6.x
   * QFX5100 with Junos 14.1X53-D26

## How to use

 * Install required components.
 * `bundle install` at top dir
 * `bundle install` at webprov dir
 * copy /webprov/config/config.rb.example to /webprov/config/config.rb and edit configurations.
 * `padrino s -h 0.0.0.0` at webprov dir
 * You can access to http://HOSTNAME:3000/ .

## License

The program has published under MIT license.
