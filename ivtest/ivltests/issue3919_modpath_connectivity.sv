`timescale 1ns/1ns

module scalar_path(input wire trigger, data, output wire y);
  wire local_q;
  not data_driver(y, data);
  buf local_consumer(local_q, y);
  specify
    (trigger => y) = 2;
  endspecify
endmodule

module resolved_path(input wire trigger, data_one, data_zero, output wire y);
  wire q;
  assign y = data_one;
  assign y = data_zero;
  buf resolved_consumer(q, y);
  specify
    (trigger => y) = 2;
  endspecify
endmodule

module ranged_path(input wire trigger, a, input wire [1:0] b,
                   output wire [2:0] y);
  wire q0, q1, q2;
  assign y[0] = a;
  assign y[2:1] = b;
  buf low_consumer(q0, y[0]);
  buf mid_consumer(q1, y[1]);
  buf high_consumer(q2, y[2]);
  specify
    (trigger *> y) = 2;
  endspecify
endmodule

module nested_path(input wire trigger, data, output wire y);
  scalar_path inner(trigger, data, y);
  specify
    (trigger => y) = 2;
  endspecify
endmodule

module split_path(input wire trigger, input wire [1:0] data,
                  output wire y, sibling);
  assign {y, sibling} = data;
  specify
    (trigger => y) = 2;
  endspecify
endmodule

module top;
  reg start = 0, data = 1, enable = 0;
  reg a = 1;
  reg [1:0] b = 2'b10;
  wire trigger, scalar_y, resolved_y, nested_y, external_q, unrelated_q;
  wire [2:0] ranged_y;
  wire split_y, split_sibling;
  buf trigger_driver(trigger, start);
  buf sibling_load(unrelated_q, trigger);
  buf external_consumer(external_q, scalar_y);
  scalar_path scalar_dut(trigger, data, scalar_y);
  resolved_path resolved_dut(trigger, data, enable, resolved_y);
  ranged_path ranged_dut(trigger, a, b, ranged_y);
  nested_path nested_dut(trigger, data, nested_y);
  split_path split_dut(trigger, b, split_y, split_sibling);
  assign resolved_y = enable ? data : 1'bz;
  assign ranged_y[0] = enable ? data : 1'bz;

  initial begin
    #5 $issue3919_probe;
    $finish(0);
  end
endmodule
