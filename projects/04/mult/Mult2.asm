// Multiplies R0 and R1 and stores the result in R2.
// (R0, R1, R2 refer to RAM[0], RAM[1], and RAM[2], respectively.)

// R1を破壊的に扱って命令数を少し減らしたバージョン

        // initialize
        @R2
        M=0
(LOOP)
        // while R1 > 0
        @R1
        D=M
        @END
        D;JLE
        // R2 = R2 + R0
        @R0
        D=M
        @R2
        M=D+M
        // R1 = R1 - 1
        @R1
        M=M-1
        @LOOP
        0;JMP
(END)
        @END
        0;JMP
