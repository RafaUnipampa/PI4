module qlearning_top #(
    parameter Q_WIDTH = 32,
    parameter STATE_WIDTH = 10,
    parameter NUM_STATES = 1024
)(
    input  wire clk,
    input  wire rst,

    input  wire en_regs,
    input  wire wr_table,

    input  wire [STATE_WIDTH-1:0] state,
    input  wire hit,

    output wire victim_way,

    output wire signed [Q_WIDTH-1:0] q0_dbg,
    output wire signed [Q_WIDTH-1:0] q1_dbg,

    output wire signed [Q_WIDTH-1:0] new_q_dbg,
    output wire [STATE_WIDTH-1:0] state_d3_dbg,
    output wire action_d3_dbg,

    output wire wr_way0_dbg,
    output wire wr_way1_dbg
);

    wire signed [Q_WIDTH-1:0] q0;
    wire signed [Q_WIDTH-1:0] q1;

    wire signed [Q_WIDTH-1:0] new_q_reg;
    wire [STATE_WIDTH-1:0] state_d3;
    wire action_d3;

    wire wr_way0;
    wire wr_way1;

    q_table #(
        .Q_WIDTH(Q_WIDTH),
        .STATE_WIDTH(STATE_WIDTH),
        .NUM_STATES(NUM_STATES)
    ) qtable_inst (
        .clk(clk),

        .read_state(state),
        .write_state(state_d3),
        .write_data(new_q_reg),

        .wr_way0(wr_way0),
        .wr_way1(wr_way1),

        .q0(q0),
        .q1(q1)
    );

    qlearning_datapath #(
        .Q_WIDTH(Q_WIDTH),
        .STATE_WIDTH(STATE_WIDTH)
    ) datapath_inst (
        .clk(clk),
        .rst(rst),

        .en_regs(en_regs),
        .wr_table(wr_table),

        .q0(q0),
        .q1(q1),
        .state(state),
        .hit(hit),

        .victim_way(victim_way),

        .action_reg(),
        .old_q_reg(),
        .best_next_reg(),

        .target_reg(),
        .diff_reg(),
        .new_q_reg(new_q_reg),

        .state_reg(),
        .state_d1(),
        .state_d2(),
        .state_d3(state_d3),

        .action_d1(),
        .action_d2(),
        .action_d3(action_d3),

        .wr_way0(wr_way0),
        .wr_way1(wr_way1)
    );

    assign q0_dbg = q0;
    assign q1_dbg = q1;

    assign new_q_dbg = new_q_reg;
    assign state_d3_dbg = state_d3;
    assign action_d3_dbg = action_d3;

    assign wr_way0_dbg = wr_way0;
    assign wr_way1_dbg = wr_way1;

endmodule