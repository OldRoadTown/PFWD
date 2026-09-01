// Syntax-only UVM surface for the local Verilator lint target.
// Production simulation must use the simulator's real UVM library.
package uvm_pkg;
  parameter int UVM_NONE = 0;
  parameter int UVM_LOW = 100;
  parameter int UVM_MEDIUM = 200;
  parameter int UVM_HIGH = 300;
  parameter int UVM_DEFAULT = 0;
  parameter int UVM_DEC = 0;
  parameter int UVM_BIN = 0;
  parameter int UVM_HEX = 0;
  typedef enum int {UVM_INFO, UVM_WARNING, UVM_ERROR, UVM_FATAL} uvm_severity;

  typedef class uvm_component;
  typedef class uvm_phase;

  class uvm_object;
    string name;
    function new(string name = ""); this.name = name; endfunction
    virtual function uvm_object clone(); return this; endfunction
  endclass

  class uvm_sequence_item extends uvm_object;
    function new(string name = ""); super.new(name); endfunction
  endclass

  class uvm_phase;
    task raise_objection(uvm_object source); endtask
    task drop_objection(uvm_object source); endtask
  endclass

  class uvm_component extends uvm_object;
    uvm_component parent;
    function new(string name, uvm_component parent); super.new(name); this.parent = parent; endfunction
    virtual function void build_phase(uvm_phase phase); endfunction
    virtual function void connect_phase(uvm_phase phase); endfunction
    virtual function void check_phase(uvm_phase phase); endfunction
    virtual function void report_phase(uvm_phase phase); endfunction
    virtual function void final_phase(uvm_phase phase); endfunction
    virtual task run_phase(uvm_phase phase); endtask
  endclass

  class uvm_agent extends uvm_component;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass
  class uvm_env extends uvm_component;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass
  class uvm_test extends uvm_component;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class uvm_object_registry #(type T = uvm_object);
    static function T create(string name = "");
      T value = new(name);
      return value;
    endfunction
  endclass

  class uvm_component_registry #(type T = uvm_component);
    static function T create(string name, uvm_component parent);
      T value = new(name, parent);
      return value;
    endfunction
  endclass

  class uvm_seq_item_pull_export #(type T = uvm_sequence_item);
  endclass

  class uvm_seq_item_pull_port #(type T = uvm_sequence_item);
    function void connect(uvm_seq_item_pull_export#(T) target); endfunction
    task try_next_item(output T item); item = null; endtask
    function void item_done(); endfunction
  endclass

  class uvm_sequencer #(type REQ = uvm_sequence_item) extends uvm_component;
    uvm_seq_item_pull_export#(REQ) seq_item_export;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      seq_item_export = new;
    endfunction
  endclass

  class uvm_driver #(type REQ = uvm_sequence_item) extends uvm_component;
    uvm_seq_item_pull_port#(REQ) seq_item_port;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      seq_item_port = new;
    endfunction
  endclass

  class uvm_sequence #(type REQ = uvm_sequence_item) extends uvm_object;
    function new(string name = ""); super.new(name); endfunction
    virtual task body(); endtask
    task start(uvm_sequencer#(REQ) sequencer); body(); endtask
    task start_item(REQ item); endtask
    task finish_item(REQ item); endtask
  endclass

  virtual class uvm_analysis_if #(type T = uvm_object);
    pure virtual function void write(T value);
  endclass

  class uvm_analysis_port #(type T = uvm_object);
    function new(string name, uvm_component parent); endfunction
    function void connect(uvm_analysis_if#(T) target); endfunction
    function void write(T value); endfunction
  endclass

  class uvm_config_db #(type T = int);
    static function bit get(uvm_component cntxt, string inst_name,
                            string field_name, output T value);
      return 1'b1;
    endfunction
    static function void set(uvm_component cntxt, string inst_name,
                             string field_name, T value);
    endfunction
  endclass

  class uvm_root extends uvm_component;
    function new(string name = "uvm_top", uvm_component parent = null);
      super.new(name, parent);
    endfunction
    function void set_timeout(time timeout, bit overridable = 1'b1); endfunction
  endclass

  class uvm_report_server;
    static function uvm_report_server get_server();
      uvm_report_server server = new;
      return server;
    endfunction
    function int get_severity_count(uvm_severity severity); return 0; endfunction
  endclass

  uvm_root uvm_top = new;
  task run_test(string test_name = ""); endtask
endpackage
