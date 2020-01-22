	.text
	.file	"main.s"

# ---------------------------------------------
# main
# ---------------------------------------------

 	.globl	main
main:

# Load a into register r2:r3

	mov [&a], r2 
	mov [&a+1], r3

# Store multiples of a from a*0 to a*9
	
	mov 0, r0
	mov 0, r1
	
	mov &X0, r4
	
	mov r0, [r4, 0]      
	mov r1, [r4, 1]   // x0
		
	r0a r2, [r4, 2]
	r1a r3, [r4, 3]   // x1
		
	r0a r2, [r4, 4]
	r1a r3, [r4, 5]   // x2

	r0a r2, [r4, 6]    
	r1a r3, [r4, 7]   // x3
		
	r0a r2, [r4, 8]    
	r1a r3, [r4, 9]   // x4

	r0a r2, [r4, 10]    
	r1a r3, [r4, 11]   // x5

	r0a r2, [r4, 12]    
	r1a r3, [r4, 13]   // x6

	r0a r2, [r4, 14]    
	r1a r3, [r4, 15]   // x7

	r0a r2, [r4, 16]    
	r1a r3, [r4, 17]   // x8

	r0a r2, [r4, 18]    
	r1a r3, [r4, 19]   // x9
	 
# r0:r1 will become the result
	
	mov 0, r0           // a will become the result
	mov 0, r1           // a will become the result
	
# load b	
	
	mov [&b], r2        
	mov [&b+1], r3
	
# Loop 4 times

	mov 4, r6
	mov r4, r5
	
.LMLoop:
	
	sl1 r2, r4
	and 0x1f, r4      // Find the index to the x0-x9 multiple
	add r5, r4, r4
	
	rr4 r0, r1, r0     
	sr4 r1, r1         // Shift result one digit
	dad [r4, 0], r0
	dac [r4, 1], r1  // multiply the right-most digit of b
	
	rr4 r2, r3, r2     
	sr4 r3, r3         // Shift b one digit
	
# next digit

	sl1 r2, r4
	and 0x1f, r4       // Find the index to the x0-x9 multiple
	add r5, r4, r4
	
	rr4 r0, r1, r0    
	sr4 r1, r1         // Shift result one digit 
	
	dad [r4, 0], r0
	dac [r4, 1], r1  // multiply the right-most digit of b
	
	rr4 r2, r3, r2     
	sr4 r3, r3         // shift b one digit
	
	sub 1, r6         // decrement counter
	bf .LMLoop        // next digit
	
# store the result

	mov r0, [&result]
	mov r1, [&result+1]
	
	hlt


# AddSubroutine:
# 	sub 32, r5               // reserve frame space
# 	mov r6, [r5, 31]          // store return address, [r5,0] to [r5,30] are available for local vars
# 	add r0, r1, r0           // perform addition
# 	add 32, r5               // restore the caller stack frame
# 	mov [r5, 1], PC          // return to caller
# 
# ProgramEntry:
# 	mov [&stackADDR+1024], r5  // set r5 to the top of the stack, r5 becomes the stack pointer
# 	mov 100, r0                // set r0 to 100
# 	mov 3, r1                  // set r1 to 2
# 	jl @AddSubroutine           // call AddSubroutine to perform addition
# 	mov r0, [&result]          // store the result in memory
# 	hlt                        // stop execution
# 
# 	.data
# stackADDR:
# 	.short stack           // initialise stackADDR with the address of the reserved stack area

#	.comm result,2,2        // reserve space in data memory for result
#	.comm stack, 1024, 64   // reserve 1024 bytes of 64-byte aligned data space for the stack 




# ---------------------------------------------
# Global Data
# ---------------------------------------------

	.data
a:	.long 0x05556789
b:	.long 0x12345670
	.comm result,4,2
	.comm X0,4,64          // table of multiples needs 40 bytes, aligned to 64 bytes
	.comm X1,4,2
	.comm X2,4,2
	.comm X3,4,2
	.comm X4,4,2
	.comm X5,4,2
	.comm X6,4,2
	.comm X7,4,2
	.comm X8,4,2
	.comm X9,4,2
	


# 	mov [&a], r1      // get multiplier
# 	mov [&b], r2      // get multiplicand 	
# 	mov 100, a0            // set result address
# 	mov 0, r0
# 	mov r0, [a0, 0]      // set initial result to zero
# .LMulHi:
# 	cmp 0, r2         // compare multiplicand with zero
# 	bt .LMulDone        // branch if zero 
# 	sr1 r2, r2           // shift right the multiplicand
# 	set r1, r3
# 	dad r3, [&result]      // conditionally accumulate the result
# 	dad r1, r1, r1           // shift multiplier left
# 	b .LMulHi           // next iteration
# .LMulDone:
# 	mov [&result], r0
# 	
# 	hlt












# 	mov 100, a0          // assume 100 is the top of the stack address
# 	mov [a0, 0], r1      // get multiplier
# 	mov [a0, 1], r2      // get multiplicand 	
# 	add 1, a0            // increment stack address
# 	mov 0, r0
# 	mov r0, [a0, 0]      // set initial result to zero
# 	mov 16, r0           // initialise counter
# .LMulHi:
# 	sr1 r2, r2           // shift right the multiplicand
# 	adt r1, [a0, 0]      // conditionally accumulate the result
# 	sl1 r1, r1           // shift multiplier left
# 	sub 1, r0            // decrement counter
# 	bt .LMulHi           // next iteration
# .LMulDone:
# 	// done, the stack pointer is already incremented 
# 	// and the result in the right memory location
# 	
# 	
# 	
# # ---------------------------------------------
# # myprintstr
# # ---------------------------------------------
# 	.globl	myprintstr
# myprintstr:
# .LBB0_1:
# 	mov [a0, 0], r1
# 	cmp 0, r1
# 	bt .LBB0_3
# 	mov r1, [-1]
# 	add 1, r0
# 	b .LBB0_1
# .LBB0_3:
# 	mov lr, pc
# 	
# 	
# # ---------------------------------------------
# # printnum
# # ---------------------------------------------
# 	.globl	printnum
# printnum:
# 	mov	0, r1
# .LBB1_1:
# 	cmp	5, r1
# 	bt	.LBB1_6
# 	mov	48, r2
# 	add	r1, r1, a0
# 	mov	[a0, &.L__const.printnum.factors], a0
# .LBB1_3:
# 	cmp.ult	r0, a0
# 	bt	.LBB1_5
# 	sub	r0, a0, r0
# 	add	1, r2
# 	b	.LBB1_3
# .LBB1_5:
# 	mov	r2, [-1L]
# 	add	1, r1
# 	b	.LBB1_1
# .LBB1_6:
# 	mov lr, pc

# ---------------------------------------------
# Global Data
# ---------------------------------------------
#	.section	.rodata,"a",@progbits
#	.p2align	1
# .L__const.printnum.factors:
# 	.short	10000
# 	.short	1000
# 	.short	100
# 	.short	10
# 	.short	1



