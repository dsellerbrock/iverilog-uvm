import uvm_pkg::*;

typedef enum bit {AddrChannel, DataChannel} channel_e;

class tagged_item extends uvm_object;
  int tag;
  function new(string name = "tagged_item", int value = 0);
    super.new(name);
    tag = value;
  endfunction
endclass

module uvm_tlm_fifo_io_test;
  uvm_tlm_analysis_fifo #(tagged_item) object_fifo;
  uvm_tlm_analysis_fifo #(tagged_item) object_fifo2;
  uvm_tlm_analysis_fifo #(channel_e) direction_fifo;
  uvm_analysis_port #(tagged_item) object_port;
  uvm_analysis_port #(tagged_item) object_port2;
  uvm_analysis_port #(channel_e) direction_port;
  tagged_item sent;
  tagged_item sent2;
  tagged_item got;
  channel_e direction;
  bit ok;

  task consume_through_formals(
      uvm_tlm_analysis_fifo #(tagged_item) object_fifo_arg,
      uvm_tlm_analysis_fifo #(channel_e) direction_fifo_arg);
    tagged_item item_arg;
    channel_e direction_arg = AddrChannel;
    bit local_ok;

    local_ok = object_fifo_arg.try_get(item_arg);
    if (!local_ok || item_arg == null || item_arg.tag != 42) begin
      $error("UVM FIFO object failed through a task formal");
      $finish_and_return(1);
    end

    local_ok = direction_fifo_arg.try_get(direction_arg);
    if (!local_ok || direction_arg != DataChannel) begin
      $error("UVM FIFO enum failed through a task formal: got=%0d", direction_arg);
      $finish_and_return(1);
    end
  endtask

  initial begin
    object_fifo = new("object_fifo", null);
    object_fifo2 = new("object_fifo2", null);
    direction_fifo = new("direction_fifo", null);
    sent = new("sent", 42);
    sent2 = new("sent2", 84);

    object_fifo.analysis_export.write(sent);
    ok = object_fifo.try_get(got);
    if (!ok || got == null || got.tag != 42) begin
      $error("UVM analysis FIFO object path failed");
      $finish_and_return(1);
    end

    direction_fifo.analysis_export.write(DataChannel);
    direction = AddrChannel;
    ok = direction_fifo.try_get(direction);
    if (!ok || direction != DataChannel) begin
      $error("UVM analysis FIFO enum path failed: got=%0d", direction);
      $finish_and_return(1);
    end

    object_port = new("object_port", null);
    object_port2 = new("object_port2", null);
    direction_port = new("direction_port", null);
    object_port.connect(object_fifo.analysis_export);
    object_port2.connect(object_fifo2.analysis_export);
    direction_port.connect(direction_fifo.analysis_export);
    object_port.resolve_bindings();
    object_port2.resolve_bindings();
    direction_port.resolve_bindings();

    object_port.write(sent);
    object_port.write(sent2);
    direction_port.write(DataChannel);
    consume_through_formals(object_fifo, direction_fifo);

    ok = object_fifo.try_get(got);
    if (!ok || got == null || got.tag != 84) begin
      $error("consecutive analysis writes reused a stale object argument");
      $finish_and_return(1);
    end

    object_port.write(sent);
    object_port2.write(sent2);
    ok = object_fifo.try_get(got);
    if (!ok || got == null || got.tag != 42) begin
      $error("first analysis-port instance delivered the wrong object");
      $finish_and_return(1);
    end
    ok = object_fifo2.try_get(got);
    if (!ok || got == null || got.tag != 84) begin
      $error("analysis-port instances shared stale receiver or argument state");
      $finish_and_return(1);
    end

    $display("PASSED: connected UVM analysis FIFO object/enum propagation");
    $finish;
  end
endmodule
