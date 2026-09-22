interface edge_transition_table_if;
  logic [1:0] value;
endinterface
class edge_transition_table_waiter;
  virtual edge_transition_table_if vif;
  int index;
  int pos_count, neg_count;
  task automatic pos_wait;
    @(posedge vif.value[index]); pos_count++;
  endtask
  task automatic neg_wait;
    @(negedge vif.value[index]); neg_count++;
  endtask
endclass
module edge_transition_table;
  edge_transition_table_if bus();
  edge_transition_table_waiter w;
  function automatic logic bit_value(input int n);
    case(n)
      0: return 1'b0;
      1: return 1'b1;
      2: return 1'bx;
      3: return 1'bz;
    endcase
  endfunction
  initial begin
    w=new; w.vif=bus; w.index=1;
    for(int old=0;old<4;old++) begin
      for(int next=0;next<4;next++) begin
        bus.value={bit_value(old),1'b0};
        w.pos_count=0;w.neg_count=0;
        fork: waits w.pos_wait(); w.neg_wait(); join_none
        #1 bus.value[1]=bit_value(next);
        #1;
        // IEEE 1800-2017/2023 Table 9-2; equal and X/Z swaps are not edges.
        if(w.pos_count != ((old==0 && next!=0) || (old>=2 && next==1)))
          $fatal(1,"posedge table mismatch %0d -> %0d",old,next);
        if(w.neg_count != ((old==1 && next!=1) || (old>=2 && next==0)))
          $fatal(1,"negedge table mismatch %0d -> %0d",old,next);
        disable waits;
      end
    end
    $display("PASS complete four-state edge table");$finish;
  end
  initial #100 $fatal(1,"edge table timeout");
endmodule
