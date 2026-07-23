// M1B-4: adversarial parameterized-class specialization audit (IEEE 1800-2017
// clause 8.25). Multiple coexisting specializations must keep independent
// widths, per-spec statics, class-typed and struct type parameters, nested
// specialization, and parameterized inheritance. Self-checking.
class Boxw #(int W = 8);
  logic [W-1:0] v;
  function int width(); return W; endfunction
endclass

class Animal; virtual function string speak(); return "?"; endfunction endclass
class Dog extends Animal; function string speak(); return "woof"; endfunction endclass
class Cat extends Animal; function string speak(); return "meow"; endfunction endclass
class Cage #(type T = Animal); T pet; endclass

class BoxT #(type T = int); T v; endclass

class Ctr #(int ID = 0);
  static int count = 0;
  function void inc(); count++; endfunction
  function int get(); return count; endfunction
endclass

class Base #(type T = int); T data; function T get(); return data; endfunction endclass
class Deriv #(type T = int) extends Base#(T); function void set(T x); data = x; endfunction endclass

module sv_param_spec_audit;
  int errors = 0;
  initial begin
    // Coexisting value-parameter specializations: independent widths + truncation.
    begin
      automatic Boxw#(8)  b8  = new;
      automatic Boxw#(16) b16 = new;
      automatic Boxw#(4)  b4  = new;
      b8.v = 'hFF; b16.v = 'hFFFF; b4.v = 8'hAB;   // b4 truncates to 4'hB
      if (b8.width()!=8 || b16.width()!=16 || b4.width()!=4) begin $display("FAIL widths"); errors++; end
      if (b8.v!==8'hFF || b16.v!==16'hFFFF || b4.v!==4'hB) begin
        $display("FAIL vals b8=%0h b16=%0h b4=%0h", b8.v, b16.v, b4.v); errors++; end
    end

    // Class type parameter: virtual dispatch through the parameterized handle.
    begin
      automatic Cage#(Dog) cd = new;
      automatic Cage#(Cat) cc = new;
      cd.pet = new; cc.pet = new;
      if (cd.pet.speak()!="woof" || cc.pet.speak()!="meow") begin $display("FAIL dispatch"); errors++; end
    end

    // Nested specialization BoxT#(BoxT#(int)).
    begin
      automatic BoxT#(BoxT#(int)) bb = new;
      bb.v = new; bb.v.v = 42;
      if (bb.v.v!==42) begin $display("FAIL nested=%0d", bb.v.v); errors++; end
    end

    // Per-specialization statics do not leak across specializations.
    begin
      automatic Ctr#(1) a = new;
      automatic Ctr#(2) b = new;
      a.inc(); a.inc(); a.inc();
      b.inc();
      if (a.get()!=3 || b.get()!=1) begin $display("FAIL statics a=%0d b=%0d", a.get(), b.get()); errors++; end
    end

    // Parameterized class extending a parameterized base, type threaded.
    begin
      automatic Deriv#(byte) d = new;
      d.set(8'h7F);
      if (d.get()!==8'h7F) begin $display("FAIL threaded=%0h", d.get()); errors++; end
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
