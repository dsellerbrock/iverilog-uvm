module p21c;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
integer fd,c,code,d,a,b; reg [7:0] h; real r; string s,l; logic [31:0] v32; byte bm[4]; logic [7:0] mem[0:7]; logic [3:0] mb[0:2];
initial begin
 fd=$fopen("p21c_t.txt","w"); $fwrite(fd,"12 ab 3.5 xyz\nline2\n"); $fclose(fd); fd=$fopen("p21c_t.txt","r");
 c=$fgetc(fd); ck("fgetc",c=="1"); code=$ungetc(c,fd); ck("ungetc",code==0&&$fgetc(fd)=="1"); ck("ftell",$ftell(fd)==1);
 code=$rewind(fd); ck("rewind",code==0&&$ftell(fd)==0);
 code=$fscanf(fd,"%d %h %f %s",d,h,r,s); ck("fscanf",code==4&&d==12&&h==8'hab&&r==3.5&&s=="xyz");
 code=$fgets(l,fd); ck("fgets_rest",l=="\n"&&code==1); code=$fgets(l,fd); ck("fgets",l=="line2\n"&&code==6);
 c=$fgetc(fd); ck("eof_char",c==-1); ck("feof",$feof(fd)!=0);
 code=$fseek(fd,3,0); ck("fseek",code==0&&$fgetc(fd)=="a"); code=$fseek(fd,0,2); ck("fseek_end",$ftell(fd)==20); $fclose(fd);
 ck("sscanf",$sscanf("10 20","%d %d",a,b)==2&&a==10&&b==20); ck("sscanf_skip",$sscanf("5 6","%*d %d",b)==1&&b==6);
 fd=$fopen("p21c_b.bin","wb"); $fwrite(fd,"%c%c%c%c",8'h01,8'h02,8'h03,8'h04); $fclose(fd); fd=$fopen("p21c_b.bin","rb");
 code=$fread(v32,fd); ck("fread_int",code==4&&v32==32'h01020304); code=$rewind(fd); code=$fread(bm,fd); ck("fread_mem",code==4&&bm[0]==1&&bm[3]==4); $fclose(fd);
 fd=$fopen("p21c_m.txt","w"); $fwrite(fd,"@2 AB CD // c\n/* x */ EF 01 xx\n"); $fclose(fd); $readmemh("p21c_m.txt",mem);
 ck("readmemh",mem[2]==8'hAB&&mem[3]==8'hCD&&mem[4]==8'hEF&&mem[5]==8'h01&&mem[6]===8'hxx);
 fd=$fopen("p21c_mb.txt","w"); $fwrite(fd,"@1 1x0z\n"); $fclose(fd); $readmemb("p21c_mb.txt",mb); ck("readmemb",mb[1]===4'b1x0z);
 $display("RESULT pass=%0d fail=%0d",p,f); end endmodule
