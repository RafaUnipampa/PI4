module q_table #(
    parameter Q_WIDTH = 32,
    parameter STATE_WIDTH = 10,
    parameter NUM_STATES = 1024
)(
    input  wire clk,

    // Estado usado para leitura da Q-table
    input  wire [STATE_WIDTH-1:0] read_state,

    // Estado usado no write back
    input  wire [STATE_WIDTH-1:0] write_state,

    // Valor novo calculado pelo datapath
    input  wire signed [Q_WIDTH-1:0] write_data,

    // Sinais de escrita por via
    input  wire wr_way0,
    input  wire wr_way1,

    // Saídas lidas da Q-table
    output reg signed [Q_WIDTH-1:0] q0,
    output reg signed [Q_WIDTH-1:0] q1
);

    // Sugestão para o Quartus inferir RAM interna da FPGA
    (* ramstyle = "M10K" *) reg signed [Q_WIDTH-1:0] q_way0 [0:NUM_STATES-1];
    (* ramstyle = "M10K" *) reg signed [Q_WIDTH-1:0] q_way1 [0:NUM_STATES-1];

    integer i;

    initial begin
        for (i = 0; i < NUM_STATES; i = i + 1) begin
            q_way0[i] = 0;
            q_way1[i] = 0;
        end
    end

    // Leitura e escrita síncronas
    always @(posedge clk) begin
        q0 <= q_way0[read_state];
        q1 <= q_way1[read_state];

        if (wr_way0) begin
            q_way0[write_state] <= write_data;
        end

        if (wr_way1) begin
            q_way1[write_state] <= write_data;
        end
    end

endmodule