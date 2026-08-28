// IEEE 1800-2017/2023 25.9 permits the optional `interface` keyword in a
// virtual-interface data type.  Exercise both lexer classifications and all
// four class-property grammar shapes: known/forward interface names, with and
// without a modport, including parameter syntax and multiple declarators.

// This is the exact OpenTitan spi_host_env_cfg declaration shape.  The
// interface is declared later, so its name is an IDENTIFIER while the class is
// parsed.
class spi_host_env_cfg;
  virtual interface spi_host_fsm_if force_spi_fsm_vif, second_spi_fsm_vif;
endclass

// Forward IDENTIFIER plus parameter value assignment and modport.
class late_parameterized_holder;
  virtual interface late_parameterized_if #(.WIDTH(8)).drive vif;
endclass

interface spi_host_fsm_if ();
  bit fast_mode;
endinterface

// The remaining interfaces precede their class declarations, so their names
// are TYPE_IDENTIFIER tokens.
interface known_if ();
  bit [7:0] data;
endinterface

class known_holder;
  virtual interface known_if vif;
endclass

interface known_parameterized_if #(parameter int WIDTH = 8) ();
  bit [WIDTH-1:0] data;
  modport drive(output data);
endinterface

class known_parameterized_holder;
  virtual interface known_parameterized_if #(.WIDTH(8)).drive vif;
endclass

interface late_parameterized_if #(parameter int WIDTH = 8) ();
  bit [WIDTH-1:0] data;
  modport drive(output data);
endinterface

module virtual_interface_explicit_class_positive;
  spi_host_fsm_if spi_fsm();
  known_if known_bus();
  known_parameterized_if #(.WIDTH(8)) known_parameterized_bus();
  late_parameterized_if #(.WIDTH(8)) late_parameterized_bus();

  spi_host_env_cfg cfg;
  known_holder known;
  known_parameterized_holder known_parameterized;
  late_parameterized_holder late_parameterized;

  initial begin
    cfg = new();
    known = new();
    known_parameterized = new();
    late_parameterized = new();

    cfg.force_spi_fsm_vif = spi_fsm;
    cfg.second_spi_fsm_vif = spi_fsm;
    known.vif = known_bus;
    known_parameterized.vif = known_parameterized_bus;
    late_parameterized.vif = late_parameterized_bus;

    cfg.force_spi_fsm_vif.fast_mode = 1'b1;
    if (cfg.second_spi_fsm_vif.fast_mode !== 1'b1)
      $fatal(1, "OpenTitan-shaped virtual-interface property lost its handle");

    known.vif.data = 8'h3c;
    if (known_bus.data !== 8'h3c)
      $fatal(1, "known explicit virtual-interface property write failed");

    known_parameterized.vif.data = 8'ha5;
    if (known_parameterized_bus.data !== 8'ha5)
      $fatal(1, "known parameterized modport virtual-interface write failed");

    late_parameterized.vif.data = 8'h5a;
    if (late_parameterized_bus.data !== 8'h5a)
      $fatal(1, "forward parameterized modport virtual-interface write failed");

    $display("PASSED virtual interface explicit class properties");
    $finish(0);
  end
endmodule
