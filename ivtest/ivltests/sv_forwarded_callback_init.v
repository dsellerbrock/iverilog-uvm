// Reduced original UVM callback registration; both editions 8.25.
class Object; endclass
typedef class Callback;
typedef class DerivedCallback;
class TagBase; endclass
class Tag #(type T=Object) extends TagBase;
  static Tag#(T) inst = get();
  static function Tag#(T) get();
    if(inst==null) inst=new;
    return inst;
  endfunction
endclass
class RegistryBase; endclass
class TypedRegistry#(type T=Object) extends RegistryBase;
  static TypedRegistry#(T) typed_inst=initialize();
  static function TypedRegistry#(T) initialize();
    if(typed_inst==null) typed_inst=new;
    return typed_inst;
  endfunction
endclass
class Registry#(type T=Object,type CB=Callback) extends TypedRegistry#(T);
  typedef Registry#(T,CB) this_type;
  static this_type inst=initialize();
  static Registry#(T,Callback) base_inst;
  static function this_type get();
    if(inst==null) return initialize();
    return inst;
  endfunction
  static function void create();
    Tag#(Callback) a=Tag#(Callback)::get();
    TagBase abase=a;
    Tag#(CB) b=Tag#(CB)::get();
    TagBase bbase=b;
    if(inst!=null) return;
    inst=new;
    if(abase==bbase) begin
      if(!$cast(base_inst,inst)) $fatal(1,"same specialization cast failed");
    end else base_inst=Registry#(T,Callback)::get();
  endfunction
  static function this_type initialize();
    if(inst!=null) return inst;
    void'(TypedRegistry#(T)::initialize());
    create();
    return inst;
  endfunction
endclass
class DerivedRegistry#(type ST=Object);
  static Registry#(ST) st=Registry#(ST)::get();
endclass
class Callback;
  int value;
endclass
class DerivedCallback extends Callback; endclass
module sv_forwarded_callback_init;
  initial begin
    Registry#(Object,Callback) a;
    Registry#(Object,DerivedCallback) b;
    a=Registry#(Object,Callback)::get();
    b=Registry#(Object,DerivedCallback)::get();
    if(DerivedRegistry#(Object)::st==null) $fatal(1,"derived registry");
    if(a==null || b==null) $fatal(1,"null registry");
    $display("PASSED");
  end
endmodule
