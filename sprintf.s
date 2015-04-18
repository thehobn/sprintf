#sprintf!
#$a0 has the pointer to the buffer to be printed to
#$a1 has the pointer to the format string
#$a2 and $a3 have (possibly) the first two substitutions for the format string
#the rest are on the stack
#return the number of characters (ommitting the trailing '\0') put in the buffer
        .text

# To{do,fix}, time permitting:
#	Reduce string parsing redundancy (getting number of %'s, parsing those %'s, finding outbuf.length)
#	Simpler label names

sprintf:	#(*outbuf, *format, . . .) outbuf.length
	#Prologue
		subi $sp, $sp, stackSize	#INSERT: stack size
		sw $ra, 0($sp)
		sw $a0, 4($sp)
		sw $a1, 8($sp)
		sw $a2, 12($sp)
	#Get number of additional arguments (dirty hack)
		move formatCharPtr, $a1
		li formatArgc, 0
		findFormatArgumentCountLoop:
			lb formatChar, (formatCharPtr)	# Load character from *format
			addi formatCharPtr, formatCharPtr, 1 # Increment to the next character
			beq formatChar, '%', incrementFormatArgumentCount # Increment count on '%'
			returnForIncrementFormatArgumentCount: # Name is very self-descriptive
			bne formatChar, 0, findFormatArgumentCountLoop	# Loop
			j findPercentageSigns	# Jumps to the next stage on finding null terminator
		incrementFormatArgumentCount:
			addi formatArgc, formatArgc, 1	#Increment
			j returnForIncrementFormatArgumentCount # Return to the loop
	#Find '%'s and call format to format them
	li formatArgIndex, 0 # Initialize the counter to keep track of which additional argument we are on
	findPercentageSigns:
		lb char, (formatCharPtr)	#Load current character being parsed
		la $ra, back	#Load return address
		# Set arguments for format
			move $a0, outbufCharPtr	#Remember to restore $a0
			move $a1, formatCharPtr	#Remember to restore $a1
			# Load the right additional argument into $a2 (arguments on stack!)
			#INSERT: Increment formatArgIndex (maybe in format?)
				beq formatArgIndex, 1, moveArg3ToArg2 #
				# Only executes if arg needs to be pulled from stack
					add addr, $sp, |stacksize|
					sll formatArgcSize, formatArgc, 2
					sll formatArgIndexSize, formatArgIndex, 2
					add addr, addr, formatArgcSize
					add addr, addr, formatArgIndexSize
					lw $a2, -4(addr)	# -4 needed?
				moveArg3ToArg2:
					move $a2, $a3
				
		beq char, '%', format
		#Put char into outbuf	#Only runs if not '%'
			lb tmpChar, (formatCharPtr)	#Load char from format
			sb tmpChar, (outbufCharPtr)	#Put char into outbuf
			addi outbufCharPtr, outbufCharPtr, 1	#Increment outbufCharPtr
		back:	#Where format returns to
			lw $a0, 4($sp)	#Restore $a0
			lw $a1, 8($sp)	#Restore $a1
			lw $a2, 12($sp) #Restore $a2
			#INSERT: Set formatCharPtr to the right address (handle in format?)
			bne char, 0, findPercentageSigns	#Loop
			j fin	#Only runs if current char is null terminator

	format:	#(*outbuf, *format, *formatSub)
		addi formatArgIndex, formatArgIndex, 1
		lb argtype, 1(formatCharPtr)
		la $ra, back
		#Load arguments here:
		beq argtype, 'u', udec
		beq argtype, 'x', uhex
		beq argtype, 'o', uoct
		#INSERT: str and dec

	fin:
		#Count buffer length (make sure $a0 is still its original value)
		li $v0, 0 #Redundant?
		findBufferLengthLoop:
			lb outbufChar, ($a0)
			addi $a0, $a0, 1 #Make sure to restore $a0 if needed later
			addi $v0, $v0, 1 #Increment the return value: outbuf.length
			bne outbufChar, 0, findBufferLengthLoop
			subi $v0, $v0, 1 #Should compensate the value of outbuf.length correctly
		#Null terminate outbuf (outbufCharPtr should point to the last character)
			addi outbufCharPtr, outbufCharPtr, 1
			sb 0, (outputCharPtr)
		#Epilogue
			lw $ra, 0($sp)
			addi $sp, $sp, stackSize	#INSERT: stack size
			jr $ra		#this sprintf implementation rocks!

udec:	
	addi	$sp,$sp,-8	# get 2 words of stack
	sw	$ra,0($sp)	# store return address
	remu	$t0,$a0,10	# $t0 <- $a0 % 10
	addi	$t0,$t0,'0'	# $t0 += '0' ($t0 is now a digit character)
	divu	$a0,$a0,10	# $a0 /= 10
	beqz	$a0,onedig	# if( $a0 != 0 ) { 
	sw	$t0,4($sp)	#   save $t0 on our stack
	jal	putint		#   putint() (putint will deliberately use and modify $a0)
	lw	$t0,4($sp)	#   restore $t0
	jr $ra                  # } 

		
uhex:
	addi	$sp,$sp,-8	# get 2 words of stack
	sw	$ra,0($sp)	# store return address
	remu	$t0,$a0,16	# $t0 <- $a0 % 10
	addi	$t0,$t0,'0'	# $t0 += '0' ($t0 is now a digit character)
	divu	$a0,$a0,16	# $a0 /= 10
	beqz	$a0,onedig	# if( $a0 != 0 ) { 
	sw	$t0,4($sp)	#   save $t0 on our stack
	jal	putint		#   putint() (putint will deliberately use and modify $a0)
	lw	$t0,4($sp)	#   restore $t0
	jr $ra                  # } 
	
uoct:
	addi	$sp,$sp,-8	# get 2 words of stack
	sw	$ra,0($sp)	# store return address
	remu	$t0,$a0,8	# $t0 <- $a0 % 10
	addi	$t0,$t0,'0'	# $t0 += '0' ($t0 is now a digit character)
	divu	$a0,$a0,8	# $a0 /= 10
	beqz	$a0,onedig	# if( $a0 != 0 ) { 
	sw	$t0,4($sp)	#   save $t0 on our stack
	jal	putint		#   putint() (putint will deliberately use and modify $a0)
	lw	$t0,4($sp)	#   restore $t0
	jr $ra                  # } 

onedig:	
	sw $t0, ($a0)		# $a0 is outbufCharPtr; Save to outbuf
	addi $a0, $a0, 1 	# $a0 is outbufCharPtr; Increment outbuf pointer
	lw	$ra,0($sp)	# restore return address
	addi	$sp,$sp, 8	# restore stack
	jr	$ra		# return

str: #$a0 min $a1 max
	jr $ra
	
dec: #$a0 min $a1 max $a2 flag
	jr $ra
