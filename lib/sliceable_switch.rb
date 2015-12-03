require 'path_manager'
require 'slice'
require 'slice_exceptions'
require 'slice_extensions'

# L2 routing switch with virtual slicing.
class SliceableSwitch < PathManager
  def start
    super
    logger.info "#{name} started."
  end

  def packet_in(_dpid, packet_in)
    slice = find_slice(packet_in.slice_source,
                       packet_in.slice_destination(@graph))
    if slice
      path = maybe_create_shortest_path_in_slice(slice.name, packet_in)
      packet_out_to_destination(packet_in, path.out_port) if path
    else
      flood_to_external_ports(packet_in)
    end
  end

  private

  def find_slice(source, destination)
    Slice.find { |each| each.member?(source) && each.member?(destination) }
  end

  def maybe_create_shortest_path_in_slice(slice_name, packet_in)
    path = maybe_create_shortest_path(packet_in)
    return unless path
    path.slice = slice_name
    path
  end

  def packet_out_to_destination(packet_in, out_port)
    send_packet_out(out_port.dpid,
                    raw_data: packet_in.raw_data,
                    actions: SendOutPort.new(out_port.number))
  end

  def flood_to_external_ports(packet_in)
    Slice.all.each do |slice|
      next unless slice.member?(packet_in.slice_source)
      external_ports_in_slice(slice, packet_in.source_mac).each do |port|
        send_packet_out(port.dpid,
                        raw_data: packet_in.raw_data,
                        actions: SendOutPort.new(port.port_no))
      end
    end
  end

  def external_ports_in_slice(slice, packet_in_mac)
    slice.each_with_object([]) do |(port, macs), result|
      next unless @graph.external_ports.any? { |each| port == each }
      result << port unless macs.include?(packet_in_mac)
    end
  end
end
