# mp1.S - missile-command version
# Good luck, and have fun!

.data
   
    # Constants for accessing the fields of a struct missile,
    # struct missile is defined in rtc.h and mp1.h

    NEXT      = 0
    X     = 4
    Y     = 8
    VX    = 12
    VY    = 16
    DEST_X    = 20
    DEST_Y    = 24
    EXPLODED  = 28
    C     = 32
   

    # Character to draw for an explosion - '@'

    EXPLOSION = 64
    offset_y = 160 
    offset_x = 2
    shift_highbits = 16
    final_offset = 3840 
    x_bounds = 79
    y_bounds =24


# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

mp1_missile_list:   .long 0x0   # Head of list pointer
base_alive:     .long 0x0   # Array of 3 bytes, plus a padding byte
mp1_score:      .long 0x0   # Player's current score
prev_node:		.long 0x0

# Data private to this  file

base_pic:           .string "/^^^\\"    # Picture of a live base
dead_base_pic:      .string "xxxxx" # Picture of a dead base
crosshairs_x:       .long 0x0   # X-position of the crosshairs
crosshairs_y:       .long 0x0   # Y-position of the crosshairs

.text

# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX

mp1_poke:
        movl    vmem_base_addr(,1),%edx
        movb    %cl,(%edx,%eax,1)
        ret

#   ----------------- Exported functions ---------------------

# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#   (1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#   (2) Redraw the bases - they may have been overwritten with missiles
#   (3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention

.globl mp1_rtc_tasklet
mp1_rtc_tasklet:
    pushl %ebp 
    movl %esp, %ebp
	pushl %edi # pushing all the callee saved registers
	pushl %esi
	pushl %ebx


    pushl %eax
    pushl %ecx# caller registers pushed 
    pushl %edx
    call update_missiles # calling update missiles function 
    popl %edx
    popl %ecx # caller regitsers popped
    popl %eax

    pushl %eax
    pushl %ecx# caller registers pushed 
    pushl %edx
    call redraw_base # calling redraw base function
    popl %edx
    popl %ecx # caller regitsers popped
    popl %eax

    pushl %eax
    pushl %ecx # caller registers pushed 
    pushl %edx
    call redraw_crosshair  # calling redraw corsshair function
    popl %edx
    popl %ecx # caller regitsers popped
    popl %eax

	pushl %ebx
	pushl %esi # popping all the callee saved registers
	pushl %edi
    leave
        ret


# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

.globl mp1_ioctl
mp1_ioctl:
    movl 8(%esp), %esi 
    cmpl $0, %esi 
    jl notvalid # if lower than 0, not valid 
    cmpl $4, %esi 
    jg notvalid
    jmp *jumptable(,%esi, 4) 
        ret
   
	notvalid:
    movl $-1, %eax # returning -1
        ret 

jumptable:
    .long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, mp1_ioctl_getstatus, mp1_ioctl_endgame


# ----------------- Functions private to this file -------------------
update_missiles:
    pushl %ebp 
    movl %esp, %ebp 
    pushl %ebx  # pushing all the caller saved registers
    pushl %esi 
    pushl %edi 

    movl mp1_missile_list, %ebx 
pt1:
    cmpl $0, %ebx 
    je end_ofmissiles # CHECKS IF THE MISSILE LINKED LIST HAS ENDED

    movl X(%ebx), %edi # VARIABLE X
    movl Y(%ebx), %esi # VARIABLE Y
	shrl $shift_highbits, %edi # shifting right 16 bits to access the video mode bits (x)
    shrl $shift_highbits, %esi  # shifting right 16 bits to access the video mode bits (y)

    imul $offset_y, %esi # calcuating offset  
    imul $offset_x, %edi 
    addl %esi, %edi 
    movl %edi, %eax
    movb $0x20, %cl # PUSHING IN A SPACE INSTEAD
    pushl %edx 
    call mp1_poke  
    popl %edx 

    movl EXPLODED(%ebx), %edx
    cmpl $0, %edx
    jne exploding # MISSILE HAS EXPLODED

   
    movl X(%ebx), %edi 
    movl Y(%ebx), %esi 
    addl VX(%ebx), %edi # updating values of X and Y  
    addl VY(%ebx), %esi
    shrl $shift_highbits, %edi   # shifting right 16 bits to access the video mode bits (x)
    shrl $shift_highbits, %esi  # shifting right 16 bits to access the video mode bits (y)

    cmpl $0, %edi # CHECKING IF IN RANGE
    jl remove 
    cmpl $x_bounds, %edi
    jg remove 
    cmpl $0, %esi 
    jl remove # if not calls the remove funstion 
    cmpl $y_bounds, %esi
    jg remove

    movl VX(%ebx), %edi # IF NOT UPDATE X AND Y
    movl VY(%ebx), %edx 
    addl %edi , X(%ebx)
    addl %edx ,Y(%ebx)

    movl X(%ebx), %edx # %edx -> x 
	shrl $shift_highbits, %edx # shifting right 16 bits to access the video mode bits (x)
	movl Y(%ebx), %edi # %edi -> y
	shrl $shift_highbits, %edi # shifting right 16 bits to access the video mode bits (y)
	
	cmpl DEST_X(%ebx), %edx
	jne not_explode
	cmpl DEST_Y(%ebx), %edi # compares teh final destinat of x and y with current 
	jne not_explode

	
	jmp exploding


not_explode:
	movl X(%ebx), %edi 
    movl Y(%ebx), %esi 
	shrl $shift_highbits, %edi  # shifting right 16 bits to access the video mode bits (x)
	shrl $shift_highbits, %esi  # shifting right 16 bits to access the video mode bits (y)

    imul $offset_y, %esi  # REDRAW MISSILE so calculating the offset   
    imul $offset_x, %edi 
    addl %esi, %edi 
    movl %edi, %eax # final result stored in eax 

    xorb %cl, %cl  
    movb C(%ebx), %cl 
    pushl %edx 
    call mp1_poke # calling poke to draw on the screen
    popl %edx

	jmp pt2 # jumps to iteration
# ---------------------------------------------------

exploding:
	# je pt2
    movl X(%ebx), %edi # X VAL
    movl Y(%ebx), %esi # Y VAL
    shrl $shift_highbits, %edi # shifting right 16 bits to access the video mode bits (x)
    shrl $shift_highbits, %esi # shifting right 16 bits to access the video mode bits (y)

    imul $offset_y, %esi # calcualting the offset to redraw (80 * 2) 
    imul $offset_x, %edi # mulitplying 2 to our x value 
    addl %esi, %edi 
    movl %edi, %eax 
    pushl %edx  
    movb $EXPLOSION, %cl # drawing the explosing character on screen
    call mp1_poke # calling poke to draw 
    popl %edx  

    # todo
	pushl %ebx
	pushl %ebx # pushomg twice to save the value 
    call missile_explode # calling missile explode function 
	popl %ebx
	popl %ebx

    cmpl $0, %eax # if return value, we done notify 
    je no_notify 
	pushl %eax
	pushl %edx
	pushl %ecx
    call mp1_notify_user # we notify the user else 
	popl %ecx
	popl %edx
	popl %eax

no_notify:
    movl EXPLODED(%ebx) ,%esi 
	decl %esi # DECREMENTING EXPLOSION CHARACTER
	movl %esi , EXPLODED(%ebx)
    cmpl $0, EXPLODED(%ebx) # checking if the explosion is 0
    je clean_explosion # if so, then go to clean explosion function
    jmp pt2 

clean_explosion:
    movl X(%ebx), %edi # X VALUE SAVED
    movl Y(%ebx), %esi # Y VALUE SAVED 
    shrl $shift_highbits, %edi  # shifting right 16 bits to access the video mode bits (x)
    shrl $shift_highbits, %esi  # shifting right 16 bits to access the video mode bits (y)
    imul $offset_y, %esi # calculating offset -> y *80*2  
    imul $offset_x, %edi # calculating the offset at x ->x*2
    addl %esi, %edi 
    movl %edi, %eax 
	movb $32, %cl # variable stored as C in the global vairable
    pushl %edx  
    call mp1_poke
    popl %edx  

    jmp remove
remove:
	
	movl prev_node, %eax # previous node ain eax 
	cmpl mp1_missile_list, %ebx # ebx refers to the current node we want to free
	je del_head

mid: # in the middle of linked list - deletion
	movl NEXT(%ebx), %edi # next node in edi 
	movl %edi, NEXT(%eax)
	pushl %ebx 
	call mp1_free # free node at ebx 
	popl %ebx
	movl %edi, %ebx  # ebx gets tp the next node now 
	jmp pt1
	
del_head: # else we delete the head
	movl NEXT(%ebx), %edi  # next node in edi
	movl %edi, mp1_missile_list # moving edi at the head of the linked list 
	pushl %ebx 
	call mp1_free # free node at ebx 
	popl %ebx 
	movl %edi, %ebx # ebx goes to the next node now 
	jmp pt1

	 
pt2:
	movl %ebx , prev_node # saves our previous node in every iteration 
    movl NEXT(%ebx), %ebx # iterates thorugh the next node in our link list
    jmp pt1  



end_ofmissiles:
    popl %edi # clearing up our stack 
    popl %esi 
    popl %ebx 
    leave 
    ret


	#-------------------------------------------------------------------------------------------------




redraw_base:
    pushl %ebp 
    movl %esp, %ebp 
    pushl %ebx # pushing all the callee saved registers
    pushl %esi
    pushl %edi

    movl $1, %edx # MAIN COUNTER
    movl base_alive, %ebx 
    # movl base_pic, %esi

	loop_start:
    cmpl $4, %edx # if gone through all the bases, end loo[]
    je l_end 
    cmpb $0, %bl # if 0, then we neeed to draw dead 
    je draw_dead 
    movl %edx, %eax
    imul $20, %eax # calculating offest to find the location (20, 40, 60)
    subl $offset_x, %eax  # subtracting 2, since we start 2 before 20, 40, 60
    imul $offset_x, %eax
    addl $final_offset, %eax  # 3840 is the calculation we add for getting the final location to draw 
    leal base_pic, %esi # saving adress of base_pic in esi  
    shrl $8, %ebx
    movl $0, %edi 
    jmp print 

	draw_dead:
    movl %edx, %eax
    imul $20, %eax # doing the exact same calculation for when we have a dead base to draw
    subl $offset_x, %eax
    imul $offset_x, %eax 
    addl $final_offset, %eax 
    leal dead_base_pic, %esi # saving the dead base address to esi 
    shrl $8, %ebx
    movl $0, %edi
    jmp print 

	print:
    movb (%esi,%edi,1), %cl # now printing the bases 
    pushl %edx  # pushing args 
    call mp1_poke # calling poke to draw 
    popl %edx

    incl %edi 
    addl $2, %eax  
    cmpl $5, %edi 
    jb print 
    addl $1, %edx # adding one to the counter
    jmp loop_start # goes back to the start tp look at the next base  

	l_end:
    popl %edi 
    popl %esi
    popl %ebx 
    leave
    ret

redraw_crosshair:
    pushl %ebp
    movl %esp, %ebp 
    pushl %ebx # pushing all the callee saved registers 
    pushl %esi 
    pushl %edi 

    movl crosshairs_x, %esi
    movl crosshairs_y, %edi 
    imul $offset_y, %edi # calculating the offset for redrawing
    imul $2, %esi 
    addl %esi, %edi 
    movl %edi, %eax # stores offset calcualtion in eax 
    movb $43, %cl # saces ascii value of crosshair in register cl
    pushl %edx 
    call mp1_poke # calling poke to draw
    popl %edx  

    popl %edi 
    popl %esi 
    popl %ebx 
	leave
    ret 

mp1_ioctl_startgame:
    pushl %ebp
    movl %esp, %ebp
    pushl %ebx 
    pushl %esi
    pushl %edi 

    movl $40, crosshairs_x  # intializing crosshair x location to 40
    movl $12, crosshairs_y # initializing crosshair y location to 12
    movl $0, mp1_score # score saved as 0
    movl $0, mp1_missile_list
    movl $0x00FFFFFF, base_alive 

    popl %edi
    popl %esi
    popl %ebx 
   
    leave 
        ret

mp1_ioctl_addmissile:
    pushl %ebp 
    movl %esp, %ebp 
    pushl %ebx 
    pushl %esi
    pushl %edi 

    movl 8(%ebp), %esi # arg saved in esi
    cmpl $0, %esi 
    je neg_number1 # if value 0, jmt to function

    pushl $36 
    call mp1_malloc # CALLING MALLOC TO ALLOCATE MEMORY
    addl $4, %esp 

    cmpl $0, %eax 
    je neg_number1 # MALLOC FAILED AND RETURNED -1
    movl %eax, %edx 

    pushl %edx
    pushl $36 # PUSHING IN THE ARGUEMENTS, 36 is the size 
    pushl %esi  
    pushl %eax  
    call mp1_copy_from_user # COPYING TO KERNEL SPACE
    addl $12, %esp # clearing up arguements 
    popl %edx

    cmpl $0, %eax 
    jne neg_number2 # COPY FAILED

    movl mp1_missile_list, %ecx # INSERTING IN LINKED LIST
    movl %ecx, NEXT(%edx)
    movl %edx, mp1_missile_list
    movl $0, %eax # RETURNING 0 FINALLY
    jmp add_done 

	neg_number1:  
    movl $-1, %eax # returns -1 if failed to add
    jmp add_done 

	neg_number2:
    pushl %edx  
    call mp1_free # freeing up memory 
    addl $4, %esp # clearing up args 
    movl $-1, %eax # returning -1 in eax
    jmp add_done  

	add_done:
    popl %edi 
    popl %esi
    popl %ebx 
    leave
    ret 


mp1_ioctl_movexhairs:

    pushl %ebp 
    movl %esp, %ebp
    pushl %ebx
    pushl %esi
    pushl %edi 

    movl crosshairs_x, %esi # esi has crosshair x
    movl crosshairs_y, %edi # edi has crosshair y 
    imul $offset_y, %edi # calculating offset
    imul $offset_x, %esi 
    addl %esi, %edi 
    movl %edi, %eax

    pushl %edx 
    movb $0x20, %cl # PUSHING SPACE
    call mp1_poke
    popl %edx

    movl 8(%ebp), %ebx # PUTTING THE CHANGED VARIABLES OF X AND Y IN EBX  
    sarl $shift_highbits, %ebx # PUSHING Y
    movl 8(%ebp), %edx
    shll $shift_highbits, %edx # PUSHING X
    sarl $shift_highbits, %edx 
   
    movl crosshairs_x, %esi 
    movl crosshairs_y, %edi 
    addl %edx, %esi   
    addl %ebx, %edi 
   
    cmpl $0, %esi # if x is lesser than 0, sets left bound 
    jl l_bound

	check1:
    cmpl $x_bounds, %esi # if x is greater than 79, sets right bound
    jg r_bound 

	check2:
    cmpl $0, %edi # if y is lesser than 0, sets upper bound
    jl u_bound 

	check3:
    cmpl $y_bounds, %edi # if y is greater than 24, sets lower bound
    jg d_bound 

	redraw_x:
    movl %esi , crosshairs_x # re-initializing the location for x and y
    movl %edi  , crosshairs_y

    imul $offset_y, %edi # calcualting offset for the crosshairs
    imul $offset_x, %esi 
    addl %edi, %esi 
    movl %esi, %eax 

    pushl %edx 
    movb $0x2B, %cl # redraws the crosshair  
    call mp1_poke # calling poke for redrawing 
    popl %edx 
	jmp finish_crosshair # finally finishing 

	l_bound:  
    movl $0, %esi # sets value to 0 for left bound
    jmp check1 

	r_bound:
    movl $x_bounds, %esi # sets value to 79 for right bound
    jmp check2

	u_bound:
    movl $0, %edi # sets value to 0 for upper bound
     jmp check3

	d_bound:
    movl $y_bounds, %edi  # sets value to 24 for down bound
    jmp redraw_x  
   
   finish_crosshair:
    popl %edi
	popl %esi 
	popl %ebx
    leave  
    ret 
	

   
mp1_ioctl_getstatus:
 
	pushl %ebp
	movl %esp,%ebp
	pushl %ebx
	pushl %esi
	pushl %edi

	movl 8(%ebp), %edx # pushing in the arguenemt in edx 
	
	
	cmpl $0 , %edx # if 0, then failed 
	je fail
	
	pushl $4 # pushing args for malloc - the size 
	call mp1_malloc
	addl $4, %esp
	
	cmpl $0, %eax # if return value of malloc 0, them failed
	je fail
	movl base_alive, %ecx  # base alive array saved in edx 
	movl %eax, %edi 

	movl $0 , %edx # clears value 
	cmpb $0, %cl   
	je check_2 
	addl $1, %edx # updating status of city 1 if alive 

    check_2:
	cmpb $0, %ch  
	je check_3 
	addl $2, %edx # updating status of city 2 if alive 

    check_3:
	shrl $8, %ecx # shifting right 8 bits in our ecx 
	cmpb $0, %ch  
	je last
	addl $4, %edx # updating status of city 3 if alive 


    last:	

	shll $shift_highbits, %edx
	movw mp1_score, %dx # updates the score value in our space 

	pushl %edx
	movl %esp , %edx

	pushl $4 # pushing in all args for the function 
	pushl %edx
	pushl 8(%ebp)
	call mp1_copy_to_user 
	add $12, %esp # clearing up stack after function call 

	cmpl $0, %eax
	jne fail # if copy to user returns 0, it fails 

	movl $0, %eax
	jmp clear


    fail: 
	movl $-1, %eax # returns -1 if not able to allocate any memory

    clear:
	popl %edi 
	popl %esi 
	popl %ebx 
	leave 
	ret
	

		


mp1_ioctl_endgame:
	pushl %ebp
    movl %esp, %ebp
    pushl %ebx
    pushl %esi
    pushl %edi
 
    movl mp1_missile_list, %esi # esi contains the head of the linked list 
    
	enter_endloop:
    cmpl $0, %esi # if points to null, iteration over                                
    je done_game
    pushl NEXT(%esi) # if not, goes to the next node                          		
    pushl %esi
    call mp1_free # calls free on all nodes 

	addl $4, %esp # clearing up stack 
    popl %esi
    jmp enter_endloop
    
	done_game:
    movl $0, %eax # return value is 0, showing game ended                                
    popl %edi
    popl %esi
    popl %ebx# clearing up stack 
    leave
	ret
