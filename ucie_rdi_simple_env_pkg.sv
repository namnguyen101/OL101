`ifndef UCIE_RDI_SIMPLE_ENV_PKG_SV
`define UCIE_RDI_SIMPLE_ENV_PKG_SV

package ucie_rdi_simple_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ucie_rdi_simple_agent_pkg::*;
  import ucie_rdi_simple_scb_pkg::*;

  `include "ucie_rdi_simple_monitor_a.sv"
  `include "ucie_rdi_simple_monitor_b.sv"

  class ucie_rdi_simple_svt_env extends uvm_env;
    `uvm_component_utils(ucie_rdi_simple_svt_env)

    virtual svt_ucie_d2d_if rdi_a_vif;
    virtual svt_ucie_d2d_if rdi_b_vif;
    ucie_rdi_simple_sequencer sequencer;
    ucie_rdi_simple_driver driver;
    ucie_rdi_simple_monitor_a mon_a;
    ucie_rdi_simple_monitor_b mon_b;
    ucie_rdi_simple_scb scb;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual svt_ucie_d2d_if)::get(this, "", "rdi_a_vif", rdi_a_vif))
        `uvm_fatal("RDI_SIMPLE_ENV", "Missing rdi_a_vif")
      if (!uvm_config_db#(virtual svt_ucie_d2d_if)::get(this, "", "rdi_b_vif", rdi_b_vif))
        `uvm_fatal("RDI_SIMPLE_ENV", "Missing rdi_b_vif")

      sequencer = ucie_rdi_simple_sequencer::type_id::create("sequencer", this);
      driver = ucie_rdi_simple_driver::type_id::create("driver", this);
      mon_a = ucie_rdi_simple_monitor_a::type_id::create("mon_a", this);
      mon_b = ucie_rdi_simple_monitor_b::type_id::create("mon_b", this);
      scb = ucie_rdi_simple_scb::type_id::create("scb", this);

      uvm_config_db#(virtual svt_ucie_d2d_if)::set(this, "driver", "rdi_vif", rdi_a_vif);
      uvm_config_db#(virtual svt_ucie_d2d_if)::set(this, "mon_a", "rdi_vif", rdi_a_vif);
      uvm_config_db#(virtual svt_ucie_d2d_if)::set(this, "mon_b", "rdi_vif", rdi_b_vif);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      mon_a.ap.connect(scb.mon_a_export);
      mon_b.ap.connect(scb.mon_b_export);
    endfunction
  endclass
endpackage

`endif
