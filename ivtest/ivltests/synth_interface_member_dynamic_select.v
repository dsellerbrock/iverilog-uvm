`begin_keywords "1800-2012"

// A dynamic packed select reads both the interface member and its ordinary
// index expression. Continuous-assignment sensitivity must react to either;
// synthesis must retain the selector in the combinational data path.
interface dynamic_select_if;
  logic [3:0] vector;
endinterface

module dynamic_select_bridge(
  dynamic_select_if bus,
  input logic [1:0] index,
  output wire selected
);
  assign selected = bus.vector[index];
endmodule

module synth_interface_member_dynamic_select;
  dynamic_select_if bus();
  logic [1:0] index;
  wire selected;

  dynamic_select_bridge dut(.bus(bus), .index(index), .selected(selected));

  (* ivl_synthesis_off *)
  initial begin
    bus.vector = 4'b1010;
    index = 2'd0;
    #1;
    if (selected !== 1'b0)
      $fatal(1, "initial select: %b", selected);

    // Change only the ordinary index.
    index = 2'd1;
    #1;
    if (selected !== 1'b1)
      $fatal(1, "index reactivity: %b", selected);

    // Change only the interface member.
    bus.vector = 4'b0101;
    #1;
    if (selected !== 1'b0)
      $fatal(1, "member reactivity: %b", selected);

    index = 2'd2;
    #1;
    if (selected !== 1'b1)
      $fatal(1, "synthesized selector: %b", selected);

    $display("PASSED");
  end
endmodule

`end_keywords
