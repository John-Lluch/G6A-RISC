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

# Store multiples of a from a*0 to a*1
	
	mov 0, r4
	
	mov r4, [&X0]      
	mov r4, [&X0+1]   // x0
		
	mov r2, [&X1]      
	mov r3, [&X1+1]   // x1
	
# Store multiples of a from a*2 to a*3	
	
	dad r2, r2, r0
	dac r3, r3, r1 
	mov r0, [&X2]      
	mov r1, [&X2+1]   // x2

	dad r0, r2, r0
	dac r1, r3, r1
	mov r0, [&X3]    
	mov r1, [&X3+1]   // x3

# Store multiples of a from a*4 to a*9

.LXLoop:	
	dad r0, r2, r0
	dac r1, r3, r1
	mov r0, [r4, &X4]    
	mov r1, [r4, &X4+1]    // x4, x7
	
	dad r0, r2, r0
	dac r1, r3, r1     
	mov r0, [r4, &X5]  
	mov r1, [r4, &X5+1]    // x5, x8
	
	dad r0, r2, r0
	dac r1, r3, r1     
	mov r0, [r4, &X6]  
	mov r1, [r4, &X6+1]    // x6, x9
	
	add 6, r4
	cmp 12, r4  // loop two times
	bf .LXLoop
	 
# r0:r1 will become the result
	
	mov 0, r0           // a will become the result
	mov 0, r1           // a will become the result
	
# load b	
	
	mov [&b], r2        
	mov [&b+1], r3
	
# Loop 4 times

	mov 4, r5
	
.LMLoop:
	
	rr4 r0, r1, r0     
	sr4 r1, r1         // Shift result one digit
	
	sl1 r2, r4
	and 0x1f, r4      // Find the index to the x0-x9 multiple
	
	dad [r4, &X0], r0
	dac [r4, &X0+1], r1  // multiply the right-most digit of b
	
	rr4 r2, r3, r2     
	sr4 r3, r3         // Shift b one digit
	
# next digit
	
	rr4 r0, r1, r0     
	sr4 r1, r1         // Shift result one digit
	
	sl1 r2, r4
	and 0x1f, r4       // Find the index to the x0-x9 multiple
	
	dad [r4, &X0], r0
	dac [r4, &X0+1], r1  // multiply the right-most digit of b
	
	rr4 r2, r3, r2     
	sr4 r3, r3         // shift b one digit
	
	sub 1, r5         // decrement counter
	bf .LMLoop        // next digit
	
# store the result

	mov r0, [&result]
	mov r1, [&result+1]
	
	hlt

# ---------------------------------------------
# Global Data
# ---------------------------------------------

	.data
a:	.long 0x05556789
b:	.long 0x12345670
	.comm result,2,2
	.comm X0,4,2
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



