	.text
	.file	"main.s"

# ---------------------------------------------
# main
# ---------------------------------------------

 	.globl	main
main:

# Load a into register r2:r3 (dividend)

	mov [&a], r2 
	mov [&a+1], r3

# Load b into register r4:r5 (divisor)

	mov [&b], r4 
	mov [&b+1], r5	
	
# r0:r1 will become the result
	
	mov 0, r0      
	mov 0, r1           // R0:R1 will become the result
	
# We will loop 4 times

	mov 4, r6
	
# but first compute first digit
	
.LDivFirst:
	dsb r2, r4, r2
	dsc r3, r5, r3     // Subtract divisor
	adt 1, r0          // Only add result digit if no borrow (== carry) is produced
	bt .LDivFirst      // Subtract one more if no borrow

# For the first digit we shift divisor right (instead of dividend left)

	rr4 r4, r5, r4    // lower first
	sr4 r5, r5
	
	b .LDivMore      // branch to the restoring half of the loop
	
.LDLoop:

# Shift result one digit left

	rl4 r1, r0, r1   // higher first
	sl4 r0, r0
	
# Compute non restoring digit by repeatedly subtracting divisor

.LDivMinus:
	dsb r2, r4, r2
	dsc r3, r5, r3     // Subtract divisor
	adt 1, r0          // Only add result digit if no borrow (== carry) is produced
	bt .LDivMinus      // Subtract one more if no borrow

# shift dividend left

	rl4 r3, r2, r3      // higher first
	sl4 r2, r2
	
# Shift result left, initialize last digit with 9

.LDivMore:
	rl4 r1, r0, r1     
	sl4 r0, r0         // Shift result one digit left
	add 9, r0          // Initialize result digit with 9 for restoring
	
# compute the restoring digit by repeatedly adding divisor
	
.LDivPlus:
	dad r2, r4, r2
	dac r3, r5, r3     // Add divisor
	sbf 1, r0          // Only subtract if no carry
	bf .LDivPlus       // Add one more if no carry
	
# shift dividend left

	rl4 r3, r2, r3      // higher first
	sl4 r2, r2
	
# Next digit 

	sub 1, r6
	bf .LDLoop
	
# store the result

	mov r0, [&result]
	mov r1, [&result+1]
	
	hlt


# ---------------------------------------------
# Global Data
# ---------------------------------------------

	.data
a:	.long 0x18465900
b:	.long 0x78900000
	.comm result,4,2       // reserve space in data memory for result

