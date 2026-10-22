module p21d;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
integer fd; logic [7:0] m[1:8],w[1:3],w2[1:3]; int im[0:1]; typedef enum {A0,A1,A2} en_t; en_t em[0:1]; int aa[int]; logic [7:0] md[0:1][0:2]; logic [3:0] wb[0:1],wb2[0:1];
task automatic wf(input string n, input string c); integer g; g=$fopen(n,"w"); $fwrite(g,"%s",c); $fclose(g); endtask
initial begin
 wf("p21d_a.txt","AA BB CC DD\n"); $readmemh("p21d_a.txt",m); ck("default_start",m[1]==8'hAA&&m[4]==8'hDD&&m[5]===8'hxx);
 $readmemh("p21d_a.txt",m,6); ck("start_arg",m[6]==8'hAA&&m[8]==8'hCC);
 wf("p21d_b.txt","AA BB CC\n"); $readmemh("p21d_b.txt",m,6,4); ck("descending",m[6]==8'hAA&&m[5]==8'hBB&&m[4]==8'hCC);
 wf("p21d_c.txt","@2 11 22\n"); $readmemh("p21d_c.txt",m,1,4); ck("addr_in_range",m[2]==8'h11&&m[3]==8'h22);
 wf("p21d_d.txt","@9 55\n"); m[1]=8'h99; $readmemh("p21d_d.txt",m,1,4); ck("addr_out_of_range_stops",m[1]==8'h99);
 wf("p21d_e.txt","x1 zz\n"); $readmemh("p21d_e.txt",im); ck("two_state",im[0]==1&&im[1]==0);
 wf("p21d_f.txt","1 7\n"); $readmemh("p21d_f.txt",em); ck("enum_stops",em[0]==A1&&em[1]==A0);
 wf("p21d_g.txt","@5 11 22\n"); $readmemh("p21d_g.txt",aa); ck("assoc",aa[5]==17&&aa[6]==34&&aa.size()==2);
 wf("p21d_h.txt","01 02 03 04 05 06\n"); $readmemh("p21d_h.txt",md); ck("multidim",md[0][2]==3&&md[1][0]==4&&md[1][2]==6);
 w[1]=8'hAB; w[2]=8'hCD; w[3]=8'hxx; $writememh("p21d_w.txt",w); $readmemh("p21d_w.txt",w2); ck("writememh_roundtrip",w2[1]==8'hAB&&w2[2]==8'hCD&&w2[3]===8'hxx);
 fd=$fopen("p21d_w.txt","r"); ck("no_at_unpacked",$fgetc(fd)!="@"); $fclose(fd);
 wb[0]=4'b1x0z; wb[1]=4'b0101; $writememb("p21d_wb.txt",wb); $readmemb("p21d_wb.txt",wb2); ck("writememb",wb2[0]===4'b1x0z&&wb2[1]==4'b0101);
 $writememh("p21d_wa.txt",aa); fd=$fopen("p21d_wa.txt","r"); ck("assoc_has_at",$fgetc(fd)=="@"); $fclose(fd);
 $display("RESULT pass=%0d fail=%0d",p,f); end endmodule
