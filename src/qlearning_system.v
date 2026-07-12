module qlearning_system #(
    parameter Q_WIDTH = 32,
    parameter STATE_WIDTH = 10,
    parameter NUM_STATES = 1024
)(
    input  wire clk,
    input  wire rst,

    input  wire start,

    input  wire [STATE_WIDTH-1:0] state,
    input  wire hit,

    output wire busy,
    output wire done,

    output wire victim_way,

    output wire signed [Q_WIDTH-1:0] q0_dbg,
    output wire signed [Q_WIDTH-1:0] q1_dbg,
    output wire signed [Q_WIDTH-1:0] new_q_dbg,

    output wire [STATE_WIDTH-1:0] state_d3_dbg,
    output wire action_d3_dbg,

    output wire wr_way0_dbg,
    output wire wr_way1_dbg,

    output wire en_regs_dbg,
    output wire wr_table_dbg
);

    wire en_regs;
    wire wr_table;

    qlearning_control control_inst (
        .clk(clk),
        .rst(rst),
        .start(start),

        .en_regs(en_regs),
        .wr_table(wr_table),
        .busy(busy),
        .done(done)
    );

    qlearning_top #(
        .Q_WIDTH(Q_WIDTH),
        .STATE_WIDTH(STATE_WIDTH),
        .NUM_STATES(NUM_STATES)
    ) top_inst (
        .clk(clk),
        .rst(rst),

        .en_regs(en_regs),
        .wr_table(wr_table),

        .state(state),
        .hit(hit),

        .victim_way(victim_way),

        .q0_dbg(q0_dbg),
        .q1_dbg(q1_dbg),

        .new_q_dbg(new_q_dbg),
        .state_d3_dbg(state_d3_dbg),
        .action_d3_dbg(action_d3_dbg),

        .wr_way0_dbg(wr_way0_dbg),
        .wr_way1_dbg(wr_way1_dbg)
    );

    assign en_regs_dbg = en_regs;
    assign wr_table_dbg = wr_table;

endmodule