// IEEE 1800-2017/2023 16.12.7: all endpoint consequences belong to
// one starting implication attempt. Early success cannot discharge it.
module verdict_case #(parameter EARLY=0, LATE=0, NONOVERLAP=0, FORBIDDEN=0);
  reg clk=0, start=1, endpoint=1, b=0;
  localparam SUCCESS = FORBIDDEN ? !(EARLY || LATE) : (EARLY && LATE);
  integer passes=0, failures=0;
  always #5 clk=~clk;
  generate
    if (FORBIDDEN && NONOVERLAP) begin
      p: assert property (@(posedge clk)
           start ##[1:2] endpoint |=> not (b ##1 1'b1))
        passes++; else failures++;
    end else if (FORBIDDEN) begin
      p: assert property (@(posedge clk)
           start ##[1:2] endpoint |-> not (b ##1 1'b1))
        passes++; else failures++;
    end else if (NONOVERLAP) begin
      p: assert property (@(posedge clk) start ##[1:2] endpoint |=> b)
        passes++; else failures++;
    end else begin
      p: assert property (@(posedge clk) start ##[1:2] endpoint |-> b)
        passes++; else failures++;
    end
  endgenerate
  initial begin
    #6 start=0;
    #4 b=EARLY;
    #6;
    if (passes!=1) $fatal(1,"premature parent success: %0d",passes);
    #4 b=NONOVERLAP ? EARLY : LATE;
    #10 b=LATE;
    #10 endpoint=0;
    #6;
    if (failures != !SUCCESS || passes != 4+SUCCESS)
      $fatal(1,"parent verdict %0d/%0d, expected %0d/%0d",
             passes,failures,4+SUCCESS,!SUCCESS);
  end
endmodule
module cancel_case #(parameter KILL=0);
  reg clk=0, start=1, endpoint=1, b=1, dis=0;
  integer passes=0, failures=0;
  always #5 clk=~clk;
  p: assert property (@(posedge clk) disable iff(dis)
       start ##[1:2] endpoint |-> b) passes++; else failures++;
  initial begin
    #6 start=0;
    #10;
    if (KILL) $assertkill(0,p); else dis=1;
    b=0;
    #10;
    if (KILL) $asserton(0,p); else dis=0;
    #20;
    if (passes!=3 || failures!=0)
      $fatal(1,"cancelled parent survived: %0d/%0d",passes,failures);
  end
endmodule
// A failed child's slot is reused for another parent by |=> spawning on
// the same tick. The failure must retain its old owner until aggregation.
module recycled_child_case;
  reg clk=0, start=1, endpoint=0, b=0;
  integer tag=1, route=0, passes=0, failures=0;
  property prop;
    int saved;
    (start, saved=tag) ##[1:2] (endpoint && saved==route) |=> b;
  endproperty
  p: assert property (@(posedge clk) prop) passes++; else failures++;
  initial begin
    #5 clk=1;
    #1 clk=0; tag=2; endpoint=1; route=1;
    #9 clk=1;
    #1 clk=0; start=0; route=2;
    #9 clk=1;
    #1 clk=0;
    if (passes!=1 || failures!=1)
      $fatal(1,"recycled child changed parent identity: %0d/%0d",passes,failures);
    b=1; endpoint=0;
    #9 clk=1;
    #1 clk=0;
    if (passes!=3 || failures!=1)
      $fatal(1,"new parent lost its consequence: %0d/%0d",passes,failures);
  end
endmodule
module test;
  recycled_child_case recycled();
  cancel_case #(.KILL(0)) disabled_parent();
  cancel_case #(.KILL(1)) killed_parent();
  for (genvar i=0; i<16; i++) begin: cases
    verdict_case #(.EARLY(i&1), .LATE((i>>1)&1), .NONOVERLAP((i>>2)&1), .FORBIDDEN((i>>3)&1)) v();
  end
  initial begin
    #48;
    $display("PASSED");
  end
  initial #49 $finish(0);
endmodule
