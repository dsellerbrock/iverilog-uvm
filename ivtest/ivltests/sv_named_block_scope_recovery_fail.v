class Recorder; function void record();
for(int i=0;i<2;i++)
  if(1) begin : named
    if(1) begin
      (1,"field",i)
    end else $display("field");
  end
endfunction endclass
module main; endmodule
