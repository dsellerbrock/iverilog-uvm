module test;
string source, sink;
assign sink=source;
initial begin
source="first"; #1; if(sink!="first") $fatal(1,"initial update");
source=""; #1; if(sink!="") $fatal(1,"empty update");
source="last longer"; #1; if(sink!="last longer") $fatal(1,"resized update");
$display("PASS dynamic continuous string"); end
endmodule
