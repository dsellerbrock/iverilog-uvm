// Test class with fixed-size integer array properties
`include "uvm_macros.svh"
import uvm_pkg::*;

class fifo_model;
  int data[8];  // fixed-size array of 8 ints
  int head, tail, count;

  function new();
    head  = 0;
    tail  = 0;
    count = 0;
    for (int i = 0; i < 8; i++) data[i] = 0;
  endfunction

  function void push(int val);
    if (count < 8) begin
      data[tail] = val;
      tail = (tail + 1) % 8;
      count++;
    end
  endfunction

  function int pop();
    int v;
    if (count > 0) begin
      v    = data[head];
      head = (head + 1) % 8;
      count--;
      return v;
    end
    return -1;
  endfunction
endclass

class class_array_test extends uvm_test;
  `uvm_component_utils(class_array_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    fifo_model fifo;
    int pass_count;
    phase.raise_objection(this);

    fifo = new();
    pass_count = 0;

    // Push 5 values
    fifo.push(10);
    fifo.push(20);
    fifo.push(30);
    fifo.push(40);
    fifo.push(50);

    // Pop and verify FIFO order
    if (fifo.pop() == 10) pass_count++;
    if (fifo.pop() == 20) pass_count++;
    if (fifo.pop() == 30) pass_count++;
    if (fifo.pop() == 40) pass_count++;
    if (fifo.pop() == 50) pass_count++;

    if (pass_count == 5)
      `uvm_info("ARR_TEST", "PASS: class fixed-size array works correctly", UVM_NONE)
    else
      `uvm_error("ARR_TEST", $sformatf("FAIL: only %0d/5 checks passed", pass_count))

    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("class_array_test");
endmodule
