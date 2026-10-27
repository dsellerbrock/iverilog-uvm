module p21a;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
logic [11:0] r1=10; logic [31:0] rv=101; string s;
initial begin
 s=$sformatf("\\\t\\\n\"\123"); ck("esc",s.len()==6&&s[0]==8'h5c&&s[1]==9&&s[2]==8'h5c&&s[3]==10&&s[4]==8'h22&&s[5]=="S");
 ck("esc_unknown",$sformatf("\b")=="b"); ck("pct",$sformatf("%%")=="%");
 ck("radix",$sformatf("%h|%d|%o|%b",rv,rv,rv,rv)=="00000065|       101|00000000145|00000000000000000000000001100101");
 ck("c",$sformatf("%c",rv)=="e");
 ck("auto12",$sformatf("%d|%h|%0d|%0h",r1,r1,r1,r1)=="  10|00a|10|a");
 ck("t1",$sformatf("%d|%0d|%h|%0h",32'd10,32'd10,32'd10,32'd10)=="        10|10|0000000a|a");
 ck("t2",$sformatf("%3d|%3d|%3d",32'd5,32'd100,32'd1234)=="  5|100|1234");
 ck("t3",$sformatf("%3h|%3h|%3h",32'h5,32'h100,32'h1234)=="005|100|1234");
 ck("t4",$sformatf("%s|%3s|%3s|%3s","abc","a","abc","abcdef")=="abc|  a|abc|abcdef");
 ck("w797",$sformatf("%02X",32'h3)=="03"&&$sformatf("%02X",8'h3)=="03");
 ck("x1",$sformatf("%d|%d",1'bx,1'bz)=="x|z"); ck("x2",$sformatf("%h",14'bx01010)=="xxXa");
 ck("x3",$sformatf("%h %o",12'b001xxx101x01,12'b001xxx101x01)=="XXX 1x5X");
 ck("real",$sformatf("%10.3f|%e|%g",3.14159,1.5,0.5)=="     3.142|1.500000e+00|0.5");
 $display("INFO empty: a",,"b"); $displayh(255); $displayb(5); $displayo(8); $write("INFO nowrite"); $write; $display;
 $display("RESULT pass=%0d fail=%0d",p,f); end endmodule
