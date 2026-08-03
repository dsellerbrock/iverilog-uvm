import uvm_pkg::*;

typedef enum bit {AddrChannel, DataChannel} channel_e;

class detached_tagged_item extends uvm_object;
  int tag;

  function new(string name = "detached_tagged_item", int value = 0);
    super.new(name);
    tag = value;
  endfunction
endclass

class detached_default_item extends uvm_object;
  int tag;
endclass

class detached_object_consumer_base #(type ITEM_T = detached_default_item);
  int seen[$];
  bit done;

  task launch(uvm_tlm_analysis_fifo #(channel_e) direction_fifo,
              uvm_tlm_analysis_fifo #(ITEM_T) a_fifo,
              uvm_tlm_analysis_fifo #(ITEM_T) d_fifo);
    begin
      automatic string instance_name = "fifo";
      start(direction_fifo, a_fifo, d_fifo);
    end
  endtask

  task start(uvm_tlm_analysis_fifo #(channel_e) direction_fifo,
             uvm_tlm_analysis_fifo #(ITEM_T) a_fifo,
             uvm_tlm_analysis_fifo #(ITEM_T) d_fifo);
    channel_e direction;
    ITEM_T item;
    bit ok;

    fork
      begin
        repeat (4) begin
          direction_fifo.get(direction);
          case (direction)
            AddrChannel: ok = a_fifo.try_get(item);
            DataChannel: ok = d_fifo.try_get(item);
          endcase
          if (!ok || item == null) begin
            $error("detached object FIFO unexpectedly returned no item");
            $finish_and_return(1);
          end
          process_item(item);
        end
        done = 1;
      end
    join_none
  endtask

  virtual task process_item(ITEM_T item);
    seen.push_back(item.tag);
  endtask
endclass

class detached_object_consumer extends
    detached_object_consumer_base #(.ITEM_T(detached_tagged_item));
  virtual task process_item(detached_tagged_item item);
    process_item_inner(item);
  endtask

  virtual task process_item_inner(detached_tagged_item item);
    super.process_item(item);
  endtask
endclass

module uvm_tlm_fifo_detached_object_test;
  uvm_tlm_analysis_fifo #(channel_e) direction_fifo;
  uvm_tlm_analysis_fifo #(detached_tagged_item) a_fifo;
  uvm_tlm_analysis_fifo #(detached_tagged_item) d_fifo;
  detached_object_consumer consumer;
  detached_tagged_item a0;
  detached_tagged_item d0;
  detached_tagged_item a1;
  detached_tagged_item d1;

  initial begin
    direction_fifo = new("direction_fifo", null);
    a_fifo = new("a_fifo", null);
    d_fifo = new("d_fifo", null);
    consumer = new;
    a0 = new("a0", 42);
    d0 = new("d0", 84);
    a1 = new("a1", 43);
    d1 = new("d1", 85);

    fork
      consumer.launch(direction_fifo, a_fifo, d_fifo);
    join_none
    #0;

    #1 a_fifo.analysis_export.write(a0);
    direction_fifo.analysis_export.write(AddrChannel);
    #1 d_fifo.analysis_export.write(d0);
    direction_fifo.analysis_export.write(DataChannel);
    #1 a_fifo.analysis_export.write(a1);
    direction_fifo.analysis_export.write(AddrChannel);
    #1 d_fifo.analysis_export.write(d1);
    direction_fifo.analysis_export.write(DataChannel);
    wait (consumer.done);

    if (consumer.seen.size() != 4 ||
        consumer.seen[0] != 42 ||
        consumer.seen[1] != 84 ||
        consumer.seen[2] != 43 ||
        consumer.seen[3] != 85) begin
      $error("detached object FIFO reused a stale local: size=%0d values=%p",
             consumer.seen.size(), consumer.seen);
      $finish_and_return(1);
    end

    $display("PASSED: detached UVM FIFO object propagation");
    $finish;
  end
endmodule
