//top level module
`timescale 1ns / 1ns

//WORKING WORKING WORKING WITH EVERYTHING!!!

module simon(
    input CLOCK_50,
    input [9:0] SW,
    input [3:0] KEY,
    output [9:0] LEDR,
    output [6:0] HEX0, HEX2
);
//SW[0] is reset high
//SW[1] is go
//KEY[3:0] is for player input
//LEDR[0] is for led sequenceOver and correctInput
//HEX0 is for the 5 to 0 counter
//LEDR[3:2] is for the sequenceDisplay
//HEX1 is for level

wire counterDone, readDone, sequenceOver, yourTurn, gameOver, correct;
wire sizeDone, levelDone, roundDone;
wire [2:0] level;
wire [3:0] round;
wire [3:0] sequenceSize;
wire [19:0] sequenceW;
wire initialEnable, roundEnable, levelEnable, sizeEnable;
wire counterEnable, readMem, displayEnable, detectEnable, ledEnable, turnEnable, roundReset;
wire drawReset;

gameLogicFSM g0(
    .resetn(SW[0]),
    .clock(CLOCK_50),
    .go(SW[1]),
    .counterDone(counterDone),
    .readDone(readDone),
    .sequenceOver(sequenceOver),
    .yourTurn(yourTurn),
    .gameOver(gameOver),
    .correct(correct),
    .sizeDone(sizeDone),
    .levelDone(levelDone),
    .roundDone(roundDone),
    .level(level),
    .round(round),
    .sequenceSize(sequenceSize),

    .initialEnable(initialEnable),
    .roundEnable(roundEnable),
    .levelEnable(levelEnable),
    .sizeEnable(sizeEnable),
    .titleScreen(LEDR[6]),
    .counterEnable(counterEnable),
    .readMem(readMem),
    .displayEnable(displayEnable), // to sequenceDisplay module
    .ledEnable(ledEnable), //to light up LED when correct
    .detectEnable(detectEnable), //checks if input is correct
    .turnEnable(turnEnable),
    .roundReset(roundReset),
    .drawReset(LEDR[7]), // resets the screen to black
    .winScreen(LEDR[8]),
    .loseScreen(LEDR[9]) // for gameover or win screens
);

gameDatapath g1(
    .resetn(SW[0]),
    .clock(CLOCK_50),
    .initialEnable(initialEnable),
    .roundEnable(roundEnable),
    .levelEnable(levelEnable),
    .sizeEnable(sizeEnable),
    .ledEnable(ledEnable),
    .turnEnable(turnEnable),
    .roundReset(roundReset),

    .level(level),
    .round(round),
    .sequenceSize(sequenceSize),
    .sizeDone(sizeDone),
    .levelDone(levelDone),
    .roundDone(roundDone),
    .ledOn(LEDR[0]),
    .yourTurn(yourTurn)
);

writeSequence w0(
    .clock(CLOCK_50),
    .resetn(SW[0]),
	.level(level),
    .writeEnable(readMem),
    .readDone(readDone),
	.sequenceOut(sequenceW)
);

sequenceDisplay s0(
    .clock(CLOCK_50),
    .reset(SW[0]),
    .displayEnable(displayEnable),
    .sequenceSize(sequenceSize),
    .sequenceW(sequenceW),
    .square(LEDR[3:2]),
    .noFlash(LEDR[4]),
    .sequenceOver(sequenceOver)
);

sequenceCheck s1(
    .detectEnable(detectEnable),
    .reset(SW[0]),
    .clock(CLOCK_50),
    .sequenceW(sequenceW),
    .key0(~KEY[0]),
    .key1(~KEY[1]),
    .key2(~KEY[2]),
    .key3(~KEY[3]),
    .round(round),
    .gameOver(gameOver),
    .correct(correct)
);

    //for level display
    hex_decoder h0(.c({1'b0, level}), .HEX0(HEX2));

    wire [3:0] CounterValue;

    //for counter display (5 to 0)
    counter #(.CLOCK_FREQUENCY(50000000)) c0(
        .clock(CLOCK_50),
        .resetn(SW[0]),
        .counterEnable(counterEnable),
        .counterDone(counterDone),
        .CounterValue(CounterValue)
    );

    hex_decoder h1(.c(CounterValue), .HEX0(HEX0));

endmodule

module gameLogicFSM(
    input resetn, // to switch
    input clock,
    input go, // to switch
    input counterDone, readDone, sequenceOver, yourTurn, gameOver, correct,
    input sizeDone, levelDone, roundDone,
    input [2:0] level,
    input [3:0] round,
    input [3:0] sequenceSize,
    output reg initialEnable, roundEnable, levelEnable, sizeEnable,
    output reg titleScreen, // for start? screen
    output reg counterEnable, // 5,4,3,2,1 before starting
    output reg readMem, // to read sequence from memory
    output reg displayEnable, // to sequenceDisplay module
    output reg ledEnable, //to light up LED when correct
    output reg detectEnable, //checks if input is correct
    output reg turnEnable, roundReset,
    output reg drawReset, // resets the screen to black
    output reg winScreen, loseScreen // for gameover or win screens
);
 
wire rateEnable;
rateDivider #(.CLOCK_FREQUENCY(50000000)) r0(.clock(clock), .reset(resetn), .speed(2'b00), .enableDC(rateEnable));

reg [3:0] curr_state, next_state;

localparam  
        START = 4'd0,
        WAIT = 4'd1,
        readSequence = 4'd2,
        displaySequence = 4'd3,
        DONE = 4'd4,
        playerInput = 4'd5,
        UPDATEROUND = 4'd6,
        CORRECT = 4'd7,
        UPDATE = 4'd8,
        OVER = 4'd9,
        GAMEOVER = 4'd10,
        WIN = 4'd11;

always @(*) begin
    case (curr_state)
        START: next_state = (go) ? WAIT : START;
        WAIT: next_state = (counterDone) ? readSequence : WAIT;
        readSequence: next_state = (readDone) ? displaySequence : readSequence;
        displaySequence: next_state = (sequenceOver) ? DONE : displaySequence;
        DONE: next_state = (yourTurn) ? playerInput : DONE;
        playerInput:
            if(gameOver)
                next_state = GAMEOVER;
            else if(correct)
                next_state = UPDATEROUND;
            else
                next_state = playerInput;
        UPDATEROUND: next_state = (roundDone) ? CORRECT : UPDATEROUND;
        CORRECT:
            next_state = (round == sequenceSize) ? UPDATE : playerInput;
        UPDATE: 
            next_state = (sizeDone && levelDone) ? OVER : UPDATE;
        OVER:
            next_state = (sequenceSize == 10) ? WIN : WAIT;
        GAMEOVER:
            next_state = (go) ? START : GAMEOVER;
        WIN:
            next_state = (go) ? START : WIN;
        default: next_state = START;
    endcase
end

always @(*) begin
    drawReset = 1'b0;
    initialEnable = 1'b0;
    titleScreen = 1'b0;
    counterEnable = 1'b0;
    readMem = 1'b0;
    displayEnable = 1'b0;
    sizeEnable = 1'b0;
    levelEnable = 1'b0;
    ledEnable = 1'b0;
    detectEnable = 1'b0;
    roundEnable = 1'b0;
    turnEnable = 1'b0;
    roundReset = 1'b0;
    winScreen = 1'b0;
    loseScreen = 1'b0;
    case(curr_state)
        START: begin
            initialEnable = 1'b1;
            titleScreen = 1'b1;
            roundReset = 1'b1;
        end
        WAIT: begin
            counterEnable = 1'b1;
            drawReset = 1'b1;
        end
        readSequence: begin
            readMem = 1'b1;
            roundReset = 1'b1;
            drawReset = 1'b1;

        end
        displaySequence: begin
            displayEnable = 1'b1;
 
        end
        DONE: begin
            ledEnable = 1'b1;
            turnEnable = 1'b1;
        end
        playerInput: begin
            detectEnable = 1'b1;

        end
        UPDATEROUND: begin
            roundEnable = 1'b1;
        end
        CORRECT: begin
            ledEnable = 1'b1;
        end
        UPDATE: begin
            sizeEnable = 1'b1;
            levelEnable = 1'b1;

        end
        GAMEOVER: begin
            roundReset = 1'b1;
            loseScreen = 1'b1;
        end
        WIN: begin
            roundReset = 1'b1;
            winScreen = 1'b1;
        end
        default: begin
            drawReset = 1'b0;
            initialEnable = 1'b0;
            titleScreen = 1'b0;
            counterEnable = 1'b0;
            readMem = 1'b0;
            displayEnable = 1'b0;
            sizeEnable = 1'b0;
            levelEnable = 1'b0;
            ledEnable = 1'b0;
            detectEnable = 1'b0;
            roundEnable = 1'b0;
            turnEnable = 1'b0;
            roundReset = 1'b0;
            winScreen = 1'b0;
            loseScreen = 1'b0;
        end
    endcase
end

always @(posedge clock) begin
    if(resetn)
        curr_state <= START;
    else
        curr_state <= next_state;
end

endmodule

module gameDatapath(
input resetn,
input clock,
input initialEnable, roundEnable, levelEnable, sizeEnable,
input ledEnable, turnEnable, roundReset,
//input drawReset, // needed?
//input titleScreen, winScreen, loseScreen,
output reg [2:0] level, // level 1 to 8
output reg [3:0] round,
output reg [3:0] sequenceSize,
output reg sizeDone, levelDone, roundDone, ledOn, yourTurn
);

wire rateEnable;
rateDivider #(.CLOCK_FREQUENCY(50000000)) r0(.clock(clock), .reset(resetn), .speed(2'b00), .enableDC(rateEnable));


always@(posedge clock) begin
    if(resetn) begin
        level <= 3'b1;
        round <= 4'b0;
        sequenceSize <= 4'b0;
        ledOn <= 1'b0;
        sizeDone <= 1'b0;
        levelDone <= 1'b0;
        roundDone <= 1'b0;
        yourTurn <= 1'b0;
    end else begin
        if(initialEnable) begin
            level <= 3'b1;
            sequenceSize <= 4'd3;
            round <= 4'b0;
        end if (ledEnable) begin
            ledOn <= 1'b1;
        end if (roundEnable && rateEnable) begin
            round <= round + 1;
            roundDone <= 1'b1;
        end if (sizeEnable && rateEnable) begin
            sequenceSize <= sequenceSize + 1;
            sizeDone <= 1'b1;
        end if (levelEnable && rateEnable) begin
            level <= level + 1;
            levelDone <= 1'b1;
        end if (turnEnable) begin
            yourTurn <= 1'b1;
        end if (roundReset) begin
            round <= 4'b0;
        end if (ledOn && rateEnable) begin
            ledOn <= 1'b0;
        end if (yourTurn && rateEnable) begin
            yourTurn <= 1'b0;
        end if (sizeDone && rateEnable) begin
            sizeDone <= 1'b0;
        end if (levelDone && rateEnable) begin
            levelDone <= 1'b0;
        end if (roundDone && rateEnable) begin
            roundDone <= 1'b0;
        end
    end
end
endmodule

module counter#(parameter CLOCK_FREQUENCY = 50000000)(
    input clock,
    input resetn,
    input counterEnable,
    output reg counterDone,
    output reg [3:0] CounterValue
    );

    wire sec;
    rateDivider #(.CLOCK_FREQUENCY(50000000)) r0(.clock(clock), .reset(resetn), .speed(2'b00), .enableDC(sec));

    always @(posedge clock) begin
        if (resetn) begin
            CounterValue <= 4'd5;
            counterDone <= 1'b0;
        end else if (counterEnable && sec) begin
            if(CounterValue == 4'd0) begin
                CounterValue <= 4'd5;
                counterDone <= 1'b1;
            end else begin
                CounterValue <= CounterValue - 4'd1;
                counterDone <= 1'b0;
            end
        end else if (counterDone && sec) begin
            counterDone <= 1'b0;
        end
    end

endmodule

module rateDivider #(parameter CLOCK_FREQUENCY = 50000000)
//50000000 clock cycles in a second
//50MHz frequency
(input clock,
input reset,
input [1:0] speed,
output enableDC
);

reg [27:0] counter;

always @(posedge clock) begin
    if(reset) begin
        counter <= 0;
    end else if (counter == 0) begin
        case(speed)
            2'b00: counter <= CLOCK_FREQUENCY - 1;
            2'b01: counter <= CLOCK_FREQUENCY * 1.5 - 1;
            2'b10: counter <= CLOCK_FREQUENCY * 2 - 1;
            default: counter <= CLOCK_FREQUENCY - 1;
        endcase
    end else begin
        counter <= counter - 1;
    end
end

assign enableDC = (counter == 0) ? 1'b1 : 1'b0;

endmodule


module hex_decoder(
    input [3:0] c,
    output reg [6:0] HEX0
    );
    always @(*) begin
        case(c)
            4'h0: HEX0 = 7'b1000000;
            4'h1: HEX0 = 7'b1111001;
            4'h2: HEX0 = 7'b0100100;
            4'h3: HEX0 = 7'b0110000;
            4'h4: HEX0 = 7'b0011001;
            4'h5: HEX0 = 7'b0010010;
            4'h6: HEX0 = 7'b0000010;
            4'h7: HEX0 = 7'b1111000;
            4'h8: HEX0 = 7'b0000000;
            4'h9: HEX0 = 7'b0010000;
            4'ha: HEX0 = 7'b0001000;
            4'hb: HEX0 = 7'b0000011;
            4'hc: HEX0 = 7'b1000110;
            4'hd: HEX0 = 7'b0100001;
            4'he: HEX0 = 7'b0000110;
            4'hf: HEX0 = 7'b0001110;
            default: HEX0 = 7'b1111111;
        endcase
    end
endmodule

module sequenceDisplay(
    input clock,
    input reset,
    input displayEnable,
    input [3:0] sequenceSize,
    input [19:0] sequenceW,
    output reg [1:0] square,
    output reg noFlash, // for when to display nothing
    output reg sequenceOver
);
/* square will be either:
00 for top left
01 for top right
10 for bottom left
11 for bottom right
but if noFlash signal is high it overrides and no flash is shown
*/

reg [4:0] curr_state, next_state;

wire sec;
rateDivider #(.CLOCK_FREQUENCY(50000000)) r0(.clock(clock), .reset(reset), .speed(2'b00), .enableDC(sec));

localparam IDLE = 5'd0,
            seq1 = 5'd1,
            stop1 = 5'd2,
            seq2 = 5'd3,
            stop2 = 5'd4,
            seq3 = 5'd5,
            LEVEL1 = 5'd6,
            seq4 = 5'd7,
            LEVEL2 = 5'd8,
            seq5 = 5'd9,
            LEVEL3 = 5'd10,
            seq6 = 5'd11,
            LEVEL4 = 5'd12,
            seq7 = 5'd13,
            LEVEL5 = 5'd14,
            seq8 = 5'd15,
            LEVEL6 = 5'd16,
            seq9 = 5'd17,
            LEVEL7 = 5'd18,
            seq10 = 5'd19,
            LEVEL8 = 5'd20,
            DONE = 5'd21;

always@(*) begin
    case(curr_state)
        IDLE: begin
            next_state = (displayEnable && sec) ? seq1 : IDLE;
        end
        seq1: begin
            next_state = (sec) ? stop1 : seq1;
        end
        stop1: begin
            next_state = (sec) ? seq2 : stop1;
        end
        seq2: begin
            next_state = (sec) ? stop2 : seq2;
        end
        stop2: begin
            next_state = (sec) ? seq3 : stop2;
        end
        seq3: begin
            next_state = (sec) ? LEVEL1 : seq3;
        end
        LEVEL1: begin
            if (sec && sequenceSize == 4'd3) begin
                next_state = DONE;
            end else if (sec) begin
                next_state = seq4;
            end else begin
                next_state = LEVEL1;
            end
        end
        seq4: begin
            next_state = (sec) ? LEVEL2 : seq4;
        end
        LEVEL2: begin
            if (sec && sequenceSize == 4'd4) begin
                next_state = DONE;
            end else if (sec) begin
                next_state = seq5;
            end else begin
                next_state = LEVEL2;
            end
        end
        seq5: begin
            next_state = (sec) ? LEVEL3 : seq5;
        end
        LEVEL3: begin
            if (sec && sequenceSize == 4'd5) begin
                next_state = DONE;
            end else if (sec) begin
                next_state = seq6;
            end else begin
                next_state = LEVEL3;
            end
        end
        seq6: begin
            next_state = (sec) ? LEVEL4 : seq6;
        end
        LEVEL4: begin
            if (sec && sequenceSize == 4'd6) begin
                next_state = DONE;
            end else if (sec) begin
                next_state = seq7;
            end else begin
                next_state = LEVEL4;
            end
        end
        seq7: begin
            next_state = (sec) ? LEVEL5 : seq7;
        end
        LEVEL5: begin
            if (sec && sequenceSize == 4'd7) begin
                next_state = DONE;
            end else if (sec) begin
                next_state = seq8;
            end else begin
                next_state = LEVEL5;
            end
        end
        seq8: begin
            next_state = (sec) ? LEVEL6 : seq8;
        end
        LEVEL6: begin
            if (sec && sequenceSize == 4'd8) begin
                next_state = DONE;
            end else if (sec) begin
                next_state = seq9;
            end else begin
                next_state = LEVEL6;
            end
        end
        seq9: begin
            next_state = (sec) ? LEVEL7 : seq9;
        end
        LEVEL7: begin
            if (sec && sequenceSize == 4'd9) begin
                next_state = DONE;
            end else if (sec) begin
                next_state = seq10;
            end else begin
                next_state = LEVEL7;
            end
        end
        seq10: begin
            next_state = (sec) ? DONE: seq10;
        end
        LEVEL8: begin
            next_state = (sec) ? DONE : LEVEL8;
        end
        DONE: begin
            next_state = (sec) ? IDLE : DONE;
        end
        default: begin
            next_state = IDLE;
        end
    endcase
end
//what to do if sequence chunk is 000!
always @(*) begin
    square <= 2'b0;
    sequenceOver <= 1'b0;
    noFlash <= 1'b1;
    case(curr_state)
    seq1: begin
        square <= sequenceW[1:0];
        noFlash <= 1'b0;
    end
    stop1: begin
        noFlash <= 1'b1;
    end
    seq2: begin
        square <= sequenceW[3:2];
        noFlash <= 1'b0;
    end
    stop2: begin
        noFlash <= 1'b1;
    end  
    seq3: begin
        square <= sequenceW[5:4];
        noFlash <= 1'b0;
    end
    LEVEL1: begin
        noFlash <= 1'b1;
    end
    seq4: begin
        square <= sequenceW[7:6];
        noFlash <= 1'b0;
    end
    LEVEL2: begin
        noFlash <= 1'b1;
    end
    seq5: begin
        square <= sequenceW[9:8];
        noFlash <= 1'b0;
    end
    LEVEL3: begin
        noFlash <= 1'b1;
    end
    seq6: begin
        square <= sequenceW[11:10];
        noFlash <= 1'b0;
    end
    LEVEL4: begin
        noFlash <= 1'b1;
    end
    seq7: begin
        square <= sequenceW[13:12];
        noFlash <= 1'b0;
    end
    LEVEL5: begin
        noFlash <= 1'b1;
    end
    seq8: begin
        square <= sequenceW[15:14];
        noFlash <= 1'b0;
    end
    LEVEL6: begin
        noFlash <= 1'b1;
    end
    seq9: begin
        square <= sequenceW[17:16];
        noFlash <= 1'b0;
    end
    LEVEL7: begin
        noFlash <= 1'b1;
    end
    seq10: begin
        square <= sequenceW[19:18];
        noFlash <= 1'b0;
    end
    LEVEL8: begin
        noFlash <= 1'b1;
    end
    DONE: begin
        sequenceOver <= 1'b1;
        noFlash <= 1'b1;
    end
    default: begin
        square <= 2'b0;
        sequenceOver <= 1'b0;
        noFlash <= 1'b1;
    end
    endcase
end

always @(posedge clock) begin
    if(reset) begin
        curr_state <= IDLE;
    end else begin
        curr_state <= next_state;
    end
end


endmodule

module sequenceCheck(
    input detectEnable,
    input reset,
    input clock, 
    input [19:0] sequenceW, //from random generator
    input key0, // connect to ~KEYS since they are active low
    input key1,
    input key2,
    input key3,
    input [3:0] round,
    output reg gameOver,
    output reg correct
    );

    reg [1:0] userInput;
    reg [1:0] sequenceSquare;
    reg keyPressed;

    always @(*) begin
        case (round)
            4'd0: sequenceSquare = sequenceW[1:0];
            4'd1: sequenceSquare = sequenceW[3:2];
            4'd2: sequenceSquare = sequenceW[5:4];
            4'd3: sequenceSquare = sequenceW[7:6];
            4'd4: sequenceSquare = sequenceW[9:8];
            4'd5: sequenceSquare = sequenceW[11:10];
            4'd6: sequenceSquare = sequenceW[13:12];
            4'd7: sequenceSquare = sequenceW[15:14];
            4'd8: sequenceSquare = sequenceW[17:16];
            4'd9: sequenceSquare = sequenceW[19:18];
            default: sequenceSquare = sequenceW[1:0];
        endcase
    end

    reg [3:0] curr_state, next_state;

    wire sec;
    rateDivider #(.CLOCK_FREQUENCY(50000000)) r0(.clock(clock), .reset(reset), .speed(2'b00), .enableDC(sec));

    localparam 
        START = 3'd0,
        WAIT = 3'd1,
        CHECK = 3'd2,
        CORRECT = 3'd3,
        LOSE = 3'd4,
        DONE = 3'd5;
		  
    always @(*) begin
        case(curr_state)
            START: next_state = (detectEnable) ? WAIT : START;
            WAIT: next_state = (keyPressed) ? CHECK : WAIT;
            CHECK: next_state = (userInput == sequenceSquare) ? CORRECT : LOSE;
            CORRECT: next_state = (sec) ? DONE : CORRECT;
            LOSE: next_state = (sec) ? DONE : LOSE;
            DONE: next_state = (sec) ? START : DONE;
            default: next_state = START;
        endcase
    end

    always @(*) begin
        case(curr_state)
            WAIT: begin
                if(key0 | key1 | key2 | key3) begin
                    keyPressed = 1'b1;
                end else begin
                    keyPressed = 1'b0;
                end
                userInput = 2'b00;
                correct = 1'b0;
                gameOver = 1'b0;
            end
            CHECK: begin
                if(key0) begin
                    userInput = 2'b00;
                end else if (key1) begin
                    userInput = 2'b01;
                end else if (key2) begin
                    userInput = 2'b10;
                end else if (key3) begin
                    userInput = 2'b11;
                end 
                keyPressed = 1'b0;
                correct = 1'b0;
                gameOver = 1'b0;
            end
            CORRECT: begin
                correct = 1'b1;
                userInput = 2'b00;
                keyPressed = 1'b0;
                gameOver = 1'b0;
            end
            LOSE: begin
                gameOver = 1'b1;
                userInput = 2'b00;
                keyPressed = 1'b0;
                correct = 1'b0;
            end
            default: begin
                gameOver = 1'b0;
                correct = 1'b0;
                userInput = 2'b00;
                keyPressed = 1'b0;
            end
        endcase
    end

    always @(posedge clock) begin
        if(reset) begin
            curr_state <= START;
        end else begin
            curr_state <= next_state;
        end
    end
endmodule

module writeSequence(
    input clock,
    input resetn,
	input [2:0] level,
    input writeEnable,
    output reg readDone,
	output wire [19:0] sequenceOut
    );

    wire [19:0] sequenceW;
	wire wren;
	reg wren2;
	assign wren = wren2;
	wire generateDone;

	wire [7:0] memAddress;
    reg [7:0] address;

	always @(*) begin
        case (level)
            3'd0: address = 8'd0;
            3'd1: address = 8'd1;
            3'd2: address = 8'd2;
            3'd3: address = 8'd3;
            3'd4: address = 8'd4;
            3'd5: address = 8'd5;
            3'd6: address = 8'd6;
            3'd7: address = 8'd7;
            3'd8: address = 8'd8;
            default: address = 8'd0; 
        endcase
    end
	assign memAddress = address;

	wire rateEnable;
    rateDivider #(.CLOCK_FREQUENCY(50000000)) r0(.clock(clock), .reset(resetn), .speed(2'b00), .enableDC(rateEnable));

    randomSequence random_inst(.clock(clock), .resetn(resetn), .wren(writeEnable), .generateDone(generateDone), .sequenceW(sequenceW));
    sequenceMemory s0(.clock(clock), .address(memAddress), .data(sequenceW), .wren(wren), .q(sequenceOut));

    always @(posedge clock) begin
        if(resetn) begin
            readDone <= 1'b0;
        end else if (writeEnable && generateDone) begin
			wren2 <= 1'b1;
		end else if(wren2) begin
			wren2 <= 1'b0;
			readDone <= 1'b1;
		end else if (rateEnable && readDone) begin
			readDone <= 1'b0;
		end
    end

endmodule

// megafunction wizard: %RAM: 1-PORT%
// GENERATION: STANDARD
// VERSION: WM1.0
// MODULE: altsyncram 

// ============================================================
// File Name: sequenceMemory.v
// Megafunction Name(s):
// 			altsyncram
//
// Simulation Library Files(s):
// 			altera_mf
// ============================================================
// ************************************************************
// THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
//
// 18.0.0 Build 614 04/24/2018 SJ Standard Edition
// ************************************************************


//Copyright (C) 2018  Intel Corporation. All rights reserved.
//Your use of Intel Corporation's design tools, logic functions 
//and other software and tools, and its AMPP partner logic 
//functions, and any output files from any of the foregoing 
//(including device programming or simulation files), and any 
//associated documentation or information are expressly subject 
//to the terms and conditions of the Intel Program License 
//Subscription Agreement, the Intel Quartus Prime License Agreement,
//the Intel FPGA IP License Agreement, or other applicable license
//agreement, including, without limitation, that your use is for
//the sole purpose of programming logic devices manufactured by
//Intel and sold by Intel or its authorized distributors.  Please
//refer to the applicable agreement for further details.
module randomSequence(
    input clock, resetn, wren,
	output reg generateDone,
    output [19:0] sequenceW
    );

    reg [19:0] lsfr;
    wire feedback;

    //lsfr x^20 + x^17 + 1
    assign feedback = lsfr[20-1] ^ lsfr[17-1];


	wire rateEnable;
    rateDivider #(.CLOCK_FREQUENCY(50000000)) r0(.clock(clock), .reset(resetn), .speed(2'b00), .enableDC(rateEnable));

    always @(posedge clock) begin
        if(resetn) begin
            lsfr <= 20'h1234;
			generateDone <= 1'b0;
		end else if (wren) begin
            lsfr <= {lsfr[18:0], feedback};
			generateDone <= 1'b1;
		end
		if(generateDone && rateEnable) begin
			generateDone <= 1'b0;
		end
    end

    assign sequenceW = lsfr;
endmodule

module sequenceMemory(
	address,
	clock,
	data,
	wren,
	q);

	input	[7:0]  address;
	input	  clock;
	input	[19:0]  data;
	input	  wren;
	output	[19:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri1	  clock;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire [19:0] sub_wire0;
	wire [19:0] q = sub_wire0[19:0];

	altsyncram	altsyncram_component (
				.address_a (address),
				.clock0 (clock),
				.data_a (data),
				.wren_a (wren),
				.q_a (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.address_b (1'b1),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (1'b1),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b (1'b1),
				.eccstatus (),
				.q_b (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 256,
		altsyncram_component.operation_mode = "SINGLE_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.widthad_a = 8,
		altsyncram_component.width_a = 20,
		altsyncram_component.width_byteena_a = 1;

endmodule
// ============================================================
// CNX file retrieval info
// ============================================================
// Retrieval info: PRIVATE: ADDRESSSTALL_A NUMERIC "0"
// Retrieval info: PRIVATE: AclrAddr NUMERIC "0"
// Retrieval info: PRIVATE: AclrByte NUMERIC "0"
// Retrieval info: PRIVATE: AclrData NUMERIC "0"
// Retrieval info: PRIVATE: AclrOutput NUMERIC "0"
// Retrieval info: PRIVATE: BYTE_ENABLE NUMERIC "0"
// Retrieval info: PRIVATE: BYTE_SIZE NUMERIC "8"
// Retrieval info: PRIVATE: BlankMemory NUMERIC "1"
// Retrieval info: PRIVATE: CLOCK_ENABLE_INPUT_A NUMERIC "0"
// Retrieval info: PRIVATE: CLOCK_ENABLE_OUTPUT_A NUMERIC "0"
// Retrieval info: PRIVATE: Clken NUMERIC "0"
// Retrieval info: PRIVATE: DataBusSeparated NUMERIC "1"
// Retrieval info: PRIVATE: IMPLEMENT_IN_LES NUMERIC "0"
// Retrieval info: PRIVATE: INIT_FILE_LAYOUT STRING "PORT_A"
// Retrieval info: PRIVATE: INIT_TO_SIM_X NUMERIC "0"
// Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Cyclone V"
// Retrieval info: PRIVATE: JTAG_ENABLED NUMERIC "0"
// Retrieval info: PRIVATE: JTAG_ID STRING "NONE"
// Retrieval info: PRIVATE: MAXIMUM_DEPTH NUMERIC "0"
// Retrieval info: PRIVATE: MIFfilename STRING ""
// Retrieval info: PRIVATE: NUMWORDS_A NUMERIC "256"
// Retrieval info: PRIVATE: RAM_BLOCK_TYPE NUMERIC "0"
// Retrieval info: PRIVATE: READ_DURING_WRITE_MODE_PORT_A NUMERIC "3"
// Retrieval info: PRIVATE: RegAddr NUMERIC "1"
// Retrieval info: PRIVATE: RegData NUMERIC "1"
// Retrieval info: PRIVATE: RegOutput NUMERIC "0"
// Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
// Retrieval info: PRIVATE: SingleClock NUMERIC "1"
// Retrieval info: PRIVATE: UseDQRAM NUMERIC "1"
// Retrieval info: PRIVATE: WRCONTROL_ACLR_A NUMERIC "0"
// Retrieval info: PRIVATE: WidthAddr NUMERIC "8"
// Retrieval info: PRIVATE: WidthData NUMERIC "20"
// Retrieval info: PRIVATE: rden NUMERIC "1"
// Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
// Retrieval info: CONSTANT: CLOCK_ENABLE_INPUT_A STRING "BYPASS"
// Retrieval info: CONSTANT: CLOCK_ENABLE_OUTPUT_A STRING "BYPASS"
// Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Cyclone V"
// Retrieval info: CONSTANT: LPM_HINT STRING "ENABLE_RUNTIME_MOD=NO"
// Retrieval info: CONSTANT: LPM_TYPE STRING "altsyncram"
// Retrieval info: CONSTANT: NUMWORDS_A NUMERIC "256"
// Retrieval info: CONSTANT: OPERATION_MODE STRING "SINGLE_PORT"
// Retrieval info: CONSTANT: OUTDATA_ACLR_A STRING "NONE"
// Retrieval info: CONSTANT: OUTDATA_REG_A STRING "UNREGISTERED"
// Retrieval info: CONSTANT: POWER_UP_UNINITIALIZED STRING "FALSE"
// Retrieval info: CONSTANT: READ_DURING_WRITE_MODE_PORT_A STRING "NEW_DATA_NO_NBE_READ"
// Retrieval info: CONSTANT: WIDTHAD_A NUMERIC "8"
// Retrieval info: CONSTANT: WIDTH_A NUMERIC "20"
// Retrieval info: CONSTANT: WIDTH_BYTEENA_A NUMERIC "1"
// Retrieval info: USED_PORT: address 0 0 8 0 INPUT NODEFVAL "address[7..0]"
// Retrieval info: USED_PORT: clock 0 0 0 0 INPUT VCC "clock"
// Retrieval info: USED_PORT: data 0 0 20 0 INPUT NODEFVAL "data[19..0]"
// Retrieval info: USED_PORT: q 0 0 20 0 OUTPUT NODEFVAL "q[19..0]"
// Retrieval info: USED_PORT: rden 0 0 0 0 INPUT VCC "rden"
// Retrieval info: USED_PORT: wren 0 0 0 0 INPUT NODEFVAL "wren"
// Retrieval info: CONNECT: @address_a 0 0 8 0 address 0 0 8 0
// Retrieval info: CONNECT: @clock0 0 0 0 0 clock 0 0 0 0
// Retrieval info: CONNECT: @data_a 0 0 20 0 data 0 0 20 0
// Retrieval info: CONNECT: @rden_a 0 0 0 0 rden 0 0 0 0
// Retrieval info: CONNECT: @wren_a 0 0 0 0 wren 0 0 0 0
// Retrieval info: CONNECT: q 0 0 20 0 @q_a 0 0 20 0
// Retrieval info: GEN_FILE: TYPE_NORMAL sequenceMemory.v TRUE
// Retrieval info: GEN_FILE: TYPE_NORMAL sequenceMemory.inc FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL sequenceMemory.cmp FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL sequenceMemory.bsf FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL sequenceMemory_inst.v FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL sequenceMemory_bb.v TRUE
// Retrieval info: LIB_FILE: altera_mf
