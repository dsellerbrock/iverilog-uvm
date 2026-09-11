class holder;
  typedef enum logic [1:0] {IDLE, RUN=2} state;
  typedef logic [7:0] byte_t;
endclass
class child extends holder; endclass
typedef holder alias_t;
module leaf(output logic alive); initial alive=1; endmodule
module test;
  holder::state s=holder::RUN, t=holder::IDLE;
  holder::byte_t [1:0] lanes=16'ha5c3;
  holder::byte_t data[2]='{8'h12,8'h34};
  child::state inherited=holder::RUN;
  alias_t::state aliased=holder::IDLE;
  process::state current;
  logic alive;
  leaf inst(alive);
  initial begin
    process p;
    p=process::self(); current=p.status();
    #1;
    if(s.name()!="RUN" || t.name()!="IDLE" || inherited!=s || aliased!=t) $fatal(1,"enum identity");
    if($bits(lanes)!=16 || lanes!==16'ha5c3 || data[0]!==8'h12 || data[1]!==8'h34) $fatal(1,"shape/value");
    if(current!=process::RUNNING || !alive) $fatal(1,"builtin/instance");
    $display("PASSED");
  end
endmodule
