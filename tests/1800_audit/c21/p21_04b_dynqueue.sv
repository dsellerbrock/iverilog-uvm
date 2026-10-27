module p21f;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
logic [7:0] dm[]; logic [7:0] q[$]; integer g;
initial begin
 g=$fopen("p21f_a.txt","w"); $fwrite(g,"11 22 33\n"); $fclose(g);
 dm=new[2]; $readmemh("p21f_a.txt",dm); ck("dyn_loaded_fixed_size",dm.size()==2&&dm[0]==8'h11&&dm[1]==8'h22);
 q='{8'h00,8'h00}; $readmemh("p21f_a.txt",q); ck("queue_loaded_fixed_size",q.size()==2&&q[0]==8'h11&&q[1]==8'h22);
 dm[0]=8'hAA; dm[1]=8'hBB; $writememh("p21f_b.txt",dm); dm[0]=0; dm[1]=0; $readmemh("p21f_b.txt",dm); ck("dyn_roundtrip",dm[0]==8'hAA&&dm[1]==8'hBB);
 $display("RESULT pass=%0d fail=%0d",p,f); end endmodule
