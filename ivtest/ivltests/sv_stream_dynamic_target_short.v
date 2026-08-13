// A source shorter than the fixed portion of a dynamic streaming target is
// a run-time error. Recovery left-aligns the source and zero-fills on the
// right, without asserting or partially corrupting the target.
module test;
  logic [15:0] fixed;
  byte data[];
  byte source[$];
  initial begin
    source.push_back(8'hA5);
    {>>{fixed, data}} = source;
    $display("fixed=%h data=%0d", fixed, data.size());
  end
endmodule
