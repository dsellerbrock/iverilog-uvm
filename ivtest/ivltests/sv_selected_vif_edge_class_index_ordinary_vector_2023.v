class class_index_ordinary_vector_cfg; int index; endclass
module class_index_ordinary_vector;
  logic [2:0] bits; class_index_ordinary_vector_cfg cfg; int wakes;
  initial begin
    bits=0;cfg=new;cfg.index=1;
    fork begin @(posedge bits[cfg.index]); wakes++; end join_none
    #1 bits[0]=1;
    #1 if(wakes!=0) $fatal(1,"ordinary vector nonselected bit woke");
    bits[1]=1;
    #1 if(wakes!=1) $fatal(1,"ordinary vector class-selected bit missed");
    $display("PASS class index ordinary vector");$finish;
  end
endmodule
