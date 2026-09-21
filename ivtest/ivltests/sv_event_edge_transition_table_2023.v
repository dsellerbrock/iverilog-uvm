interface edge_table_if;
  logic [1:0] value;
endinterface
class edge_table_cfg;
  virtual edge_table_if vif;
endclass
module test;
  edge_table_if bus();
  edge_table_cfg cfg;
  logic [3:0] states = 4'bzx10;
  int pos_count, neg_count, any_count;
  bit expected_pos, expected_neg;
  initial begin
    cfg=new; cfg.vif=bus;
    for (int a=0;a<4;a++) begin
      for (int b=0;b<4;b++) begin
        bus.value={1'b0,states[a]};
        #1; // settle initialization before arming event controls
        pos_count=0; neg_count=0; any_count=0;
        fork : waits
          begin @(posedge cfg.vif.value[0]); pos_count++; end
          begin @(negedge cfg.vif.value[0]); neg_count++; end
          begin @(edge cfg.vif.value[0]); any_count++; end
        join_none
        #1;
        if(pos_count || neg_count || any_count) $fatal(1,"early transition %0d->%0d",a,b);
        bus.value={1'b0,states[b]};
        #1;
        expected_pos=(a==0 && b!=0) || ((a==2 || a==3) && b==1);
        expected_neg=(a==1 && b!=1) || ((a==2 || a==3) && b==0);
        if(pos_count!=expected_pos || neg_count!=expected_neg || any_count!=(expected_pos || expected_neg))
          $fatal(1,"edge table %0d->%0d got %0d/%0d/%0d expected %0d/%0d",a,b,pos_count,neg_count,any_count,expected_pos,expected_neg);
        disable waits;
      end
    end
    $display("PASSED 16 four-state transitions");
  end
endmodule
