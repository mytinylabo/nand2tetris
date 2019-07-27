// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input.
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel;
// the screen should remain fully black as long as the key is pressed.
// When no key is pressed, the program clears the screen, i.e. writes
// "white" in every pixel;
// the screen should remain fully clear as long as no key is pressed.

(CHECKKEY)
        @KBD
        D=M
        @FILL_BLACK
        D;JGT

// Here's two sets of the same sequence of instructions
// except for the value to be written(0 for white or -1 for black).
// This is a way to keep each loop step simple
// within constraint of lack of registers.

(FILL_WHITE)
        @8192 // (512/16)*256
        D=A
(WHITE_STEP)
        D=D-1
        // M[SCREEN+D] = 0b0000000000000000
        @SCREEN
        A=A+D
        M=0
        @WHITE_STEP
        D;JGT
        @CHECKKEY
        0;JMP
(FILL_BLACK)
        @8192 // (512/16)*256
        D=A
(BLACK_STEP)
        D=D-1
        // M[SCREEN+D] = 0b1111111111111111
        @SCREEN
        A=A+D
        M=-1
        @BLACK_STEP
        D;JGT
        @CHECKKEY
        0;JMP
