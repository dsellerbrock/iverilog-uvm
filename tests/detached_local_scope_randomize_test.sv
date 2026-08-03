class detached_random_item;
  rand bit [31:0] addr;
  rand bit write;
  rand bit [3:0] mask;
  rand bit [31:0] data;
  rand bit [3:0] instr_type;
endclass

class detached_random_sequence;
  bit done;
  int failures;

  task access(input bit [31:0] addr,
              input bit write,
              inout bit [31:0] data,
              input bit [3:0] mask,
              input bit [3:0] instr_type);
    bit completed;
    access_w_abort(addr, write, data, completed, mask, instr_type);
  endtask

  task access_w_abort(input bit [31:0] addr,
                      input bit write,
                      inout bit [31:0] data,
                      output bit completed,
                      input bit [3:0] mask,
                      input bit [3:0] instr_type);
    fork
      access_sub(addr, write, data, completed, mask, instr_type);
    join_none
    #0;
  endtask

  task access_sub(input bit [31:0] addr,
                  input bit write,
                  inout bit [31:0] data,
                  output bit completed,
                  input bit [3:0] mask,
                  input bit [3:0] instr_type);
    detached_random_item item;
    item = new;
    if (!item.randomize() with {
          addr == local::addr;
          write == local::write;
          mask == local::mask;
          data == local::data;
          instr_type == local::instr_type;
        }) begin
      failures++;
    end
    if (item.addr !== addr || item.write !== write || item.mask !== mask ||
        item.data !== data || item.instr_type !== instr_type) begin
      $error("detached local values changed: addr=%h/%h data=%h/%h mask=%h/%h",
             item.addr, addr, item.data, data, item.mask, mask);
      failures++;
    end
    completed = 1'b1;
    done = 1'b1;
  endtask
endclass

module detached_local_scope_randomize_test;
  detached_random_sequence seq;
  bit [31:0] data;
  initial begin
    seq = new;
    data = 32'h0123_4567;
    seq.access(32'h4000_0018, 1'b1, data, 4'hf, 4'h9);
    wait (seq.done);
    if (seq.failures != 0)
      $finish_and_return(1);
    $display("PASSED: detached task preserves local:: randomize values");
    $finish;
  end
endmodule
