module packed_struct_array_member_test;
  typedef struct packed {
    bit pend;
    logic [2:0] opcode;
    logic [2:0] size;
    logic [7:0] mask;
  } pend_req_t;

  pend_req_t [3:0] pend_req;
  logic [1:0] index;
  logic clk;
  wire selected = pend_req[index].pend;
  default clocking cb @(posedge clk); endclocking
  selected_member_A: assert property (pend_req[index].pend == selected);

  initial begin
    pend_req = '0;
    pend_req[2].pend = 1'b1;
    index = 2;
    clk = 0;
    #1;
    clk = 1;
    #1;
    if (selected === 1'b1)
      $display("PASS: packed array of struct member select");
    else
      $display("FAIL: packed array of struct member select");
  end
endmodule
