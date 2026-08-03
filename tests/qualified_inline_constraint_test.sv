typedef struct packed {
  bit [31:0] addr;
  bit [31:0] data;
} qualified_bus_op_t;

class qualified_bus_item;
  rand bit [2:0] opcode;
  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit [3:0] mask;
endclass

class qualified_adapter;
  int failures;

  function void fill_bus_write(const ref qualified_bus_op_t rw,
                               ref qualified_bus_item bus_req);
    int unsigned msb = 31;
    if (!bus_req.randomize() with {
          bus_req.opcode inside {3'd0, 3'd1};
          bus_req.addr == 32'(rw.addr);
          bus_req.data == 32'(rw.data);
          bus_req.mask[0] == 1;
          bus_req.mask[msb/8] == 1;
        }) begin
      failures++;
    end
  endfunction
endclass

module qualified_inline_constraint_test;
  qualified_adapter adapter;
  qualified_bus_item item;
  qualified_bus_op_t op;
  initial begin
    adapter = new;
    item = new;
    op.addr = 32'h4000_0018;
    op.data = 32'h0123_4567;
    adapter.fill_bus_write(op, item);
    if (adapter.failures != 0 || item.addr !== op.addr ||
        item.data !== op.data || item.mask[0] !== 1'b1 ||
        item.mask[3] !== 1'b1 || !(item.opcode inside {3'd0, 3'd1})) begin
      $error("qualified inline constraints were dropped: op=%0d addr=%h data=%h mask=%h",
             item.opcode, item.addr, item.data, item.mask);
      $finish_and_return(1);
    end
    $display("PASSED: qualified inline constraints and packed casts");
    $finish;
  end
endmodule
