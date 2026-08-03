import uvm_pkg::*;

typedef enum bit {AddrChannel, DataChannel} channel_e;

class detached_fifo_consumer_base;
  int seen[$];
  bit done;

  task launch(uvm_tlm_analysis_fifo #(channel_e) fifo);
    begin
      automatic string instance_name = "fifo";
      start(fifo);
    end
  endtask

  virtual task process_direction(channel_e direction);
    seen.push_back(direction);
  endtask

  task start(uvm_tlm_analysis_fifo #(channel_e) fifo);
    channel_e direction;

    fork
      begin
        repeat (2) begin
          fifo.get(direction);
          process_direction(direction);
        end
        done = 1;
      end
    join_none
  endtask
endclass

class detached_fifo_consumer extends detached_fifo_consumer_base;
  virtual task process_direction(channel_e direction);
    process_direction_inner(direction);
  endtask

  virtual task process_direction_inner(channel_e direction);
    super.process_direction(direction);
  endtask
endclass

module uvm_tlm_fifo_detached_blocking_test;
  uvm_tlm_analysis_fifo #(channel_e) fifo;
  detached_fifo_consumer consumer;

  initial begin
    fifo = new("fifo", null);
    consumer = new;
    fork
      consumer.launch(fifo);
    join_none
    #0;

    #1 fifo.analysis_export.write(AddrChannel);
    #1 fifo.analysis_export.write(DataChannel);
    wait (consumer.done);

    if (consumer.seen.size() != 2 ||
        consumer.seen[0] != AddrChannel ||
        consumer.seen[1] != DataChannel) begin
      $error("detached blocking FIFO enum propagation failed: size=%0d values=%p",
             consumer.seen.size(), consumer.seen);
      $finish_and_return(1);
    end

    $display("PASSED: detached blocking UVM FIFO enum propagation");
    $finish;
  end
endmodule
