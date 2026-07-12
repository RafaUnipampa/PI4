`timescale 1ns/1ps

module cache_hierarchy_synth_top (
    input  wire clk,
    input  wire rst,

    // Requisição externa
    input  wire req,
    input  wire [15:0] addr,

    // Saídas principais da hierarquia
    output wire done,
    output wire l1_hit,
    output wire l2_hit,
    output wire mem_access,

    // Contadores para análise
    output wire [31:0] total_access_count,
    output wire [31:0] l1_hit_count,
    output wire [31:0] l1_miss_count,
    output wire [31:0] l2_hit_count,
    output wire [31:0] mem_access_count,
    output wire [31:0] qlearning_call_count
);

    // ============================================================
    // Instância da hierarquia:
    // L1 com LRU + L2 com Q-Learning
    // ============================================================

    cache_hierarchy_l1_lru_l2_ql #(
        .ADDR_WIDTH(16)
    ) hierarchy_inst (
        .clk(clk),
        .rst(rst),

        .req(req),
        .addr(addr),

        .done(done),
        .l1_hit(l1_hit),
        .l2_hit(l2_hit),
        .mem_access(mem_access),

        .total_access_count(total_access_count),
        .l1_hit_count(l1_hit_count),
        .l1_miss_count(l1_miss_count),
        .l2_hit_count(l2_hit_count),
        .mem_access_count(mem_access_count),
        .qlearning_call_count(qlearning_call_count)
    );

endmodule