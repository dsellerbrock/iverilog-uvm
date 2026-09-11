class Recorder; function void record();
for(int i=0;i<2;i++)
  if(1) fork
    if(1) begin
      (1,"field",i)
    end else $display("field");
  join_none
endfunction endclass
module main; endmodule
