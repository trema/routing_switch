require "trema"
require "lldp-frame"


class TopologyDB
  extend Forwardable


  def_delegators :@db, :each_pair


  def initialize
    @db = Hash.new { [].freeze }
    @links = []
  end


  def delete_switch dpid
    @db.delete dpid
  end


  def add_port dpid, port
    return if port.local? or port.down?
    @db[ dpid ] += [ port ]
  end


  def delete_port dpid, port
    @db[ dpid ] -= [ port ]
  end


  def add_link_by dpid, packet_in
    raise "Not an LLDP packet!" if not packet_in.lldp?

    lldp = Lldp.read( packet_in )
    @links << format(
                "%#x (port %d) <-> %#x (port %d)",
                lldp.dpid, lldp.port_number,
                dpid, packet_in.in_port
              )
  end


  def to_s
    @links.uniq.sort.join "\n"
  end


  # FIXME
  def clear
    @links.clear
  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End: