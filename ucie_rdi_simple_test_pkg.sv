`ifndef UCIE_RDI_SIMPLE_TEST_PKG_SV
`define UCIE_RDI_SIMPLE_TEST_PKG_SV

package ucie_rdi_simple_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ucie_phy_uvm_pkg::*;
  import ucie_rdi_simple_seq_pkg::*;
  import ucie_rdi_simple_env_pkg::*;

  class rdi_simple_svt_skeleton_smoke extends ucie_phy_base_test;
    `uvm_component_utils(rdi_simple_svt_skeleton_smoke)
    ucie_rdi_simple_svt_env simple_env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      simple_env = ucie_rdi_simple_svt_env::type_id::create("simple_env", this);
    endfunction

    task run_phase(uvm_phase phase);
      ucie_rdi_simple_known_pattern_seq seq;
      phase.raise_objection(this);
      start_link(0);
      wait_status(1, 0, 2200);

      seq = ucie_rdi_simple_known_pattern_seq::type_id::create("seq");
      seq.num_flits = 32;
      seq.start(simple_env.sequencer);

      repeat (80) @(posedge simple_env.rdi_a_vif.lclk);
      if (simple_env.scb.compare_count != 32)
        `uvm_fatal("RDI_SIMPLE_COUNT",
                   $sformatf("Expected 32 scoreboard compares, got %0d",
                             simple_env.scb.compare_count))
      if (simple_env.scb.mismatch_count != 0)
        `uvm_fatal("RDI_SIMPLE_MISMATCH",
                   $sformatf("Scoreboard saw %0d mismatches", simple_env.scb.mismatch_count))
      phase.drop_objection(this);
    endtask
  endclass

  class rdi_simple_no_capture_before_active extends rdi_simple_svt_skeleton_smoke;
    `uvm_component_utils(rdi_simple_no_capture_before_active)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);

      @(posedge simple_env.rdi_a_vif.lclk);
      simple_env.rdi_a_vif.lp_data <= 256'hdead_beef;
      simple_env.rdi_a_vif.lp_valid <= 1'b1;
      simple_env.rdi_a_vif.lp_irdy <= 1'b1;
      repeat (4) @(posedge simple_env.rdi_a_vif.lclk);
      simple_env.rdi_a_vif.lp_valid <= 1'b0;
      simple_env.rdi_a_vif.lp_irdy <= 1'b0;
      simple_env.rdi_a_vif.lp_data <= '0;
      repeat (4) @(posedge simple_env.rdi_a_vif.lclk);

      if (simple_env.scb.a_tx_count != 0 || simple_env.scb.b_rx_count != 0)
        `uvm_fatal("RDI_PRE_ACTIVE", "Simple monitors captured traffic before ACTIVE")

      phase.drop_objection(this);
    endtask
  endclass

  class rdi_simple_data_mismatch extends rdi_simple_svt_skeleton_smoke;
    `uvm_component_utils(rdi_simple_data_mismatch)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass
endpackage

`endif
