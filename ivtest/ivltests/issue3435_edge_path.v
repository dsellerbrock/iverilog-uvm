`timescale 1ns/1ns
module edge_path_scalar(input clk, output reg qp, qn);
  initial begin qp = 0; qn = 0; end
  always @(clk) begin qp <= ~qp; qn <= ~qn; end
  specify
    (posedge clk => (qp : 1'b0)) = 3;
    (negedge clk => (qn : 1'b0)) = 3;
  endspecify
endmodule

module edge_path_vector(input [1:0] clk, output reg qp, qn);
  initial begin qp = 0; qn = 0; end
  always @(clk) begin qp <= ~qp; qn <= ~qn; end
  specify
    (posedge clk *> (qp : 1'b0)) = 3;
    (negedge clk *> (qn : 1'b0)) = 3;
  endspecify
endmodule

module issue3435_edge_path;
  reg [1:0] clk = 0;
  wire sp, sn, vp, vn;
  reg scalar_value = 0, vector_value = 0;
  edge_path_scalar s(clk[0], sp, sn);
  edge_path_vector v(clk, vp, vn);

  task step(input [1:0] next_clk, input scalar_change,
            input pos_edge, input neg_edge);
    reg old_scalar, old_vector;
    begin
      old_scalar = scalar_value;
      old_vector = vector_value;
      if (scalar_change) scalar_value = ~scalar_value;
      vector_value = ~vector_value;
      clk = next_clk;
      repeat (2) begin
      #1;
      if (sp !== (scalar_change && pos_edge ? old_scalar : scalar_value) ||
          sn !== (scalar_change && neg_edge ? old_scalar : scalar_value) ||
          vp !== (pos_edge ? old_vector : vector_value) ||
          vn !== (neg_edge ? old_vector : vector_value))
        $fatal(1, "incorrect early values at %0t: %b%b%b%b", $time, sp, sn, vp, vn);
      end
      #2;
      if (sp !== scalar_value || sn !== scalar_value ||
          vp !== vector_value || vn !== vector_value)
        $fatal(1, "incorrect settled values at %0t: %b%b%b%b", $time, sp, sn, vp, vn);
      #6;
    end
  endtask

  initial begin
    #10;
    scalar_value = sp;
    vector_value = vp;
    step(2'b01, 1, 1, 0);
    step(2'b00, 1, 0, 1);
    step(2'b10, 0, 0, 0);
    step(2'b00, 0, 0, 0);
    step(2'b0x, 1, 1, 0);
    step(2'b01, 1, 1, 0);
    step(2'b0z, 1, 0, 1);
    step(2'b00, 1, 0, 1);
    $display("PASS");
    $finish;
  end
endmodule
