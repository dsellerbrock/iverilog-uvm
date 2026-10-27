module r21d_enum;
typedef enum {A0,A1,A2} en_t;
en_t em[0:1];
initial begin
 em[1]=A0;
 $readmemh("r21d_enum.txt",em);
 $display("RESULT em0=%0d em1=%0d valid0=%0d valid1=%0d",int'(em[0]),int'(em[1]),em[0]==A1,em[1]==A0);
end
endmodule
