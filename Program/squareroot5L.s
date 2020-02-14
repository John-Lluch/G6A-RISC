	.text
	.file	"main.s"

# ---------------------------------------------
# Square Root
# Based on work from William E. Egbert
# (Published on the Hewlett-Packard Journal, June 1977)
# https://documents.epfl.ch/users/f/fr/froulet/www/HP/Algorithms.pdf
# ---------------------------------------------

 	.globl	Squareroot
Squareroot:                // b = sqrt(a)

# Store return address

	mov r6, [&return]

# Load radicand address in r6

	mov [&dsp], r6     // a

# Get radicand (a) into registers

	mov [r6, 0], r0
	mov [r6, 1], r1
	mov [r6, 2], r2

# Check if exponent is an even number

	mov [r6, 3], r6
	and 0x10, r6

# If exponent is even do not shift the radicant

	bt .LSqrtEndShift  // Branch if exponent is even

# Shift the radicand left for odd exponents to keep 11 digit resolution

	sl4 r0, r0
	rl4 r1, r1
	rl4 r2, r2

# Multiply by 5

.LSqrtEndShift:
	dad r0, r0, r3
	dac r1, r1, r4
	dac r2, r2, r5     // Times 2

	dad r3, r3, r3
	dac r4, r4, r4
	dac r5, r5, r5     // Times 4

	dad r3, r0, r3
	dac r4, r1, r4
	dac r5, r2, r5     // Times 5

# Initialize 'One' constant, 'Five' constant, and radicator Rb

	mov 0, r0
	mov 0, r1
	mov 0x0100, r2
	mov r0, [&aux1]
	mov r1, [&aux1+1]
	mov r2, [&aux1+2]   // 0x0100_0000_0000
	mov 0x0050, r2
	mov r0, [&aux0]
	mov r1, [&aux0+1]
	mov r2, [&aux0+2]   // 0x0050_0000_0000

# We will loop 11 times as we want to get 11 decimal digits

	mov 11, r6

# At loop entry we have:
# Radicand accumulator Ra in r3:r4:r5
# Radicator remainder Rb in r0:r1:r2
# Ones constant in aux1
# Fives constant in aux0

# Subtract radicator (Rb) from radicand (Ra)
# (Optimize the first subtraction so we do not need to jump
# or to perform an unnecessary radicator accumulation)

.LSqrtOuter:
.LSqrtInnerOne:
	dsb r3, r0, r3
	dsc r4, r1, r4
	dsc r5, r2, r5       // Subtract Rb from Ra
	bf .LSqrtInnerEnd    // Finish early if done

# Accumulate radicator (Rb) with a temptative digit
# Kepp subtracting radicator (Rb) until radicand (Ra) becomes negative

.LSqrtInnerLoop:
	dad [&aux1], r0
	dac [&aux1+1], r1
	dac [&aux1+2], r2    // Add constant 1 to the digit place we are looking for
	dsb r3, r0, r3
	dsc r4, r1, r4
	dsc r5, r2, r5       // Subtract Rb from Ra
	bt .LSqrtInnerLoop

# Digit found, stop now if we already have all of them

.LSqrtInnerEnd:
	sub 1, r6
	bt .LSqrtMantisaDone

# Ok, so we have more digits to look for
# First restore radicand (Ra)

	dad r3, r0, r3
	dac r4, r1, r4
	dac r5, r2, r5    // Restore Ra from the extra subtraction performed above

# We must shift the 'five' constant in Rb one digit right.
# We do it by subtracting the existing one and adding the shifted one

	dsb [&aux0], r0
	dsc [&aux0+1], r1
	dsc [&aux0+2], r2   // Subtract 'five' constant from radicator
	sr4 [&aux0+2]
	rr4 [&aux0+1]
	rr4 [&aux0]         // Shift 'five' constant right
	dad [&aux0], r0
	dac [&aux0+1], r1
	dac [&aux0+2], r2   // Add back 'fives' constant to radicator

# Finally, we must update the 'ones' constant one digit left, and
# Shift the radicand (Ra) left for the next digit

	sr4 [&aux1+2]
	rr4 [&aux1+1]
	rr4 [&aux1]         // Shift 'one' constant right
	sl4 r3, r3
	rl4 r4, r4
	rl4 r5, r5          // Shift Ra left

# We are ready for the next digit, go for it

	b .LSqrtOuter

# We are done with the mantisa
# Store result in the place of radicand

.LSqrtMantisaDone:
	mov [&dsp], r6     // a
	mov r0, [r6 ,0]
	mov r1, [r6 ,1]
	mov r2, [r6, 2]

# Adjust exponent to be half the original one and clear sign

	mov [r6, 3], r0    // load exponent
	sr4 r0, r0         // shift the exponent value to lower position
	dad r0, r0, r1     // times 2
	dad r1, r1, r1     // times 4
	dad r1, r0, r1     // times 5
	sr4 r1, r1         // shift right once more to divide by 10 and clear sign
	dsb 1, r1          // subtract 1 to compensate for the one digit less on the mantisa result
	sl4 r1, r1         // return back the exponent to its right position
	mov r1, [r6, 3]    // store exponent
	
# return
	mov [&return], pc


# ---------------------------------------------
# main
# ---------------------------------------------

	.globl	main
main:

# Load a inputs to data stack 

	mov [&dsp], r4   // load dsp to r4
	add 4, r4
	
	mov [&a], r0
	mov r0, [r4,0]
	mov [&a+1], r0
	mov r0, [r4,1]
	mov [&a+2], r0
	mov r0, [r4,2]
	mov [&a+3], r0
	mov r0, [r4,3]    // move a to dstack

	mov r4, [&dsp]

# call squareroot

	jl @Squareroot
	
# load result

	mov [&dsp], r4   // load dsp to r4
	mov [r4,0], r0
	mov r0, [&result]
	mov [r4,1], r0
	mov r0, [&result+1]
	mov [r4,2], r0
	mov r0, [&result+2]
	mov [r4,3], r0
	mov r0, [&result+3]    // move pstack to result
	
	hlt




# ---------------------------------------------
# Initialized Data
# ---------------------------------------------

	.data
	.p2align 1
dsp:
	.short dstack-4       // preincrement stores, postdecrement loads
     
sp:
	.short pstack+512    // predecrement stores, postincrement loads
	
	.p2align 3
a:
//	.quad 0x0010003859811800    // +3.859811800e+01
	.quad 0x0000002000000000    // +2.000000000e+00
//.quad 0x0010009999999999    // +2.000000000e+00
//.quad 0x0000001000004400    // +2.000000000e+00

# ---------------------------------------------
# Uninitialized Data
# ---------------------------------------------

	.comm return, 2, 2       // tail call subroutine return address
	.comm cntr, 2, 2         //
	.comm aux0, 8, 8         // reserved for auxiliary variable
	.comm aux1, 8, 8         // reserved for auxiliary variable
	.comm aux2, 8, 8         // reserved for auxiliary variable
	.comm result, 8, 8       // reserved for result
	.comm dstack, 128, 8     // data stack, 128 bytes, 8 byte aligned, grows upward
	.comm pstack, 1024, 64   // program stack, 128 bytes, 64 bytes aligned, grows downward
	
	
	
	
	
	
	
	
