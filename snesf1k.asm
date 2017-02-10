//SNESF1k by el_seyf
//Brainf*k Interpreter for Super NES/Famicom
arch snes.cpu			//assemble to be a SNES executeable
output	"snesf1k.sfc", create	//specifies output name,
				//will overwrite existing file
//*******************************************************************//
print "--------------------------------------------------\n"
//*******************************************************************//
//DEFINES:
//Define Controller Registers:
define CTRL1($4218)
define CTRL2($421A)
//Controller Button Mask:
define      R_KEY($0010)
define      L_KEY($0020)
define      X_KEY($0040)
define      A_KEY($0080)
define  RIGHT_KEY($0100)
define   LEFT_KEY($0200)
define   DOWN_KEY($0400)
define     UP_KEY($0800)
define  START_KEY($1000)
define SELECT_KEY($2000)
define      Y_KEY($4000)
define      B_KEY($8000)
define    ANY_KEY($FFF0)

//Defines for Data and Program Buffer in RAM (Bank $7E):
define snesf1k_data_page($01)
define snesf1k_pgm_page($80)
//*******************************************************************//
//MACROS:
//pch() Macro used to output an Address in Hex
include "print_hex_macro.asm"
//Addressing and Banking Macro:
macro org(address) {
	variable old_pc(pc())
	origin (({address} & $7F0000) >> 1) | ({address} & $7FFF)
	base {address}
	if (pc() < old_pc) {
		evaluate p(old_pc)
		print "Old PC: $";print_hex({p});print "\n"
		print "New PC: $";print_hex({address});print "\n"
		print "Error: Overwriting assembled Memory: ",(pc()-old_pc),"\n"
		error "Cannot set PC backwards..."
	}
}
//Console Output Macros:
variable amount_of_banks(1)
macro print_free_space(used) {
	if (((65536*amount_of_banks)-{used}) < 0) {
		putchar(9);print "No Free Space in Bank ",amount_of_banks-1
		print " (",((65536*amount_of_banks)-{used})*(-1)," Bytes too much)\n"
		error ""
	}
	print "CODE SIZE:\n"
	putchar(9);print ({used}-$8000);putchar(9);print "Bytes used\n"
	putchar(9);print ($8400-{used});putchar(9);print "Bytes free\n"
	putchar(9);print ($10000*amount_of_banks)-{used};putchar(9);
	print "Bytes remain free in Bank ",amount_of_banks-1,"\n"
	amount_of_banks=amount_of_banks+1
}
macro used_bytes(text,label) {
	putchar(9); print {text}; putchar(9) ;print pc()-{label}; putchar(9); print " Bytes\n"
}
//*******************************************************************//
print "Memory Usage:\n"
//*******************************************************************//
//VARIABLES:
org($0000)
x_counter:;		dw $0000
char_out_buffer_addr:;	dl $000000
_pad:;			dw $0000
_pad_last:;		dw $0000
bf_execute:;		db $00
pgm_size:;		dl $000000
cursor_y:;		dw $0000
snesf1k_data_pointer:;	dl $000000
snesf1k_pgm_pointer:;	dl $000000
snesf1k_pgm_offset:;	dw $0000

zero_word:;		dw $0000
space_word:;		dw $0000
//*******************************************************************//
//CODE:
org($8000)
snesf1k_test:
//	db "-[>.+<]"
INIT:
//Omitting font1_data due to size
//Unpack Font1 Data:
//	pea $03D8//Unpacked Data Destination
//	pea font1_table
//	pea font1_packed
//	jsr snes_rle_unpack
//Set X to $0000:
	ldx #$0000
//Set BG1CHR to $0000:
	stz $210B//BG1CHR Source Address
//Set CGRAM Addr to $00:
	stz $2121
//Set Scroll to $00
	stx $210D//Write X and Y lower 8-Bit
	stx $210D//Write X and Y upper 8-Bit
//Set VRAM Addr to $0000:
	stx $2116
//Set OAM Control to 8x8 Tiles, Base $0000
	stz $2101
//Set OAM Addr to $0000
	stx $2102
//Set DMA Channel 0 CPU Source HIGH Byte to $7F
	lda #$7F
	sta $4304
//Set PPU Increment on write to $2119, by 1 word
	inc//A=$80
	sta $2115
//Set Y to $0000:
	txy
//copy font to PPU and clear RAM $0000-$1FFF and $7F7800-$7F97FF:
	copy_font_clear_ram:
		lda $00,x
		sta $2118//VRAM DATA LOW
		//Clear RAM:
		tya//A=$00
		sta $2119//VRAM DATA HIGH
		//Clear RAM:
		sta $00,x
		//clear BGMAP Buffer:
		sta $7F7800,x
		inx
		cpx #$2000
		bne copy_font_clear_ram
//Set CGRAM Color Palette to all colors from $0000 to $7F7F
//and Clear OAM:
		dex//X=$1FFF
	set_color_clear_oam_loop:
		//Clear OAM:
		stx.w $2104//Writes $FF to $2104 and $1F to $2105
		stx.w $2104//Writes $FF to $2104 and $1F to $2105
		sta $2122
		sta $2122
		inc
		bne set_color_clear_oam_loop
//Use BG Mode 0:
	stz $2105
//Setup DMA Channel 0 to transfer BG1MAP in WRAM to VRAM:
//Set Mode:
	inc//A=$01
	sta $4300
//Set BG1 TileMap Location to $7800:
	ldx #$7800
//and disable Mosaic on any Screen:
	stx $2106//Write $00 to $2106 and $78 to $2107
//Set BG1MAP Buffer to $7800
	stx.b char_out_buffer_addr
//Set PGM and Data Buffer Address Banks to $7E:
	lda #$7E
	sta.b snesf1k_pgm_pointer+2
	sta.b snesf1k_data_pointer+2
//Set Char Buffer Address Bank to $7F:
	inc//A=$7F
	sta.b char_out_buffer_addr+2
//Set x_counter to $20 (32 chars per line):
	lda #$20
	sta.b x_counter
	sta.b space_word
//Enable NMI and auto-read joypad:
	lda #$81
	sta $4200
//Enable BG1 and Sprites:
	lda #$11
	sta $212C
//Set Screen to full Brightness and disable force Blank:
	lda #$0F
	sta $2100
//Set snesf1k_pgm_pointer to snesf1k_pgm:
	lda.b #{snesf1k_pgm_page}
	sta.b snesf1k_pgm_pointer+1
//Set snesf1k_data_pointer to snesf1k_data:
	lda.b #{snesf1k_data_page}
	sta.b snesf1k_data_pointer+1
//set A and X to $0000:
	tya
	tyx
	
used_bytes("INIT Routine",INIT)
//*******************************************************************//
//SNESF1k MAIN:
main:
//Check Programming Mode for pending Input:
	jsr programming_mode
//Run Code if bf_execute is true:
	lda.b bf_execute
	beq main_end
		jsr decode_instruction
//Loop end:
main_end:
	//Store currently and last Button States:
		ldx.b _pad
		stx.b _pad_last
		ldx.w {CTRL1}
		stx.b _pad
	bra main
	
used_bytes("MAIN Routine",main)
//*******************************************************************//
programming_mode:
//Check Input:
php
rep #$20//A 16-Bit
//Buttons: BYsSUDLRAXlr0000
	lda.w #$8000//Start with B
	ldx.b zero_word//Used to determine which action to do
	programming_mode_check_input:
		//Check with last Input:
		bit.b _pad_last
		bne programming_mode_check_input_next
			//Check with current Input:
			bit.b _pad
			bne programming_mode_determine_action
		programming_mode_check_input_next:
			inx
			lsr
			bne programming_mode_check_input
		//If no Button was pressed, return:
			plp
			rts
	//Determine which action is done based on value in X:
	programming_mode_determine_action:
		plp
		lda.w snesf1k_instruction_set,x
		bne programming_mode_check_1
		//If ZERO, toggle execution:
			lda.b bf_execute
			bne snesf1k_tgl_to_pgm_mode
			//Toggle to Execution Mode:
				inc.b bf_execute
				bra snesf1k_tgl_return
			snesf1k_tgl_to_pgm_mode:
			//Toggle to Programming Mode:
				stz.b bf_execute
			//Write Tile Data:
				jsr programming_mode_write_tile_data
			snesf1k_tgl_return:
			//Reset char_out_buffer_addr:
				jsr write_char_to_buffer_reload_addr
			//Reset snesf1k_pgm_offset:
				ldx.b zero_word
				stx.b snesf1k_pgm_offset
			//Clear SNESf1k Data Buffer:
					txa//A=$00
					//Reset Data Pointer:
					ldy.w #({snesf1k_data_page}<<8)
					sty.b snesf1k_data_pointer
					txy//Y=$0000
				clear_snesf1k_data:
					sta [snesf1k_data_pointer],y
					iny
					cpy.w #(({snesf1k_pgm_page}<<8)-$0100)
					bne clear_snesf1k_data
				rts
	//Check if special Buttons were pressed:
	programming_mode_check_1:
		//If bf_execute is set, do not proceed:
			eor bf_execute
			cmp.w snesf1k_instruction_set,x
			bne rts_programming_mode
		ldx.b pgm_size//Needed to determine End of PGM
		ldy.b snesf1k_pgm_offset//Index Writing position
		dec
		bne programming_mode_check_2
		//Move Cursor Left:
		programming_mode_check_move_cursor_left:
			cpy.b zero_word
			beq programming_mode_save_size_offset
				dey
				bra programming_mode_save_size_offset
	programming_mode_check_2:
		dec
		bne programming_mode_check_3
		//Move Cursor Right:
			cpy.b pgm_size
			beq programming_mode_save_size_offset
				iny
				bra programming_mode_save_size_offset
	programming_mode_check_3:
		dec
		bne programming_mode_check_instruction
		//Set End of Program (write $00):
			lda #$FD//will be adjusted to $00 by next instruction
	//Write Instruction to Execution Buffer:
	programming_mode_check_instruction:
		clc;adc #$03
		sta [snesf1k_pgm_pointer],y
		//If snesf1k_pgm_offset is equal to pgm_size, increase size:
		cpy.b pgm_size
		bne programming_mode_offset_not_equal_size
		//Increase Size:
			inx
		programming_mode_offset_not_equal_size:
			iny
		
//Return:
programming_mode_save_size_offset:
	//Save pgm_size and snesf1k_pgm_offset
	stx.b pgm_size
	sty.b snesf1k_pgm_offset
programming_mode_write_tile_data:
	//Reset char_out_buffer_addr:
		jsr write_char_to_buffer_reload_addr
	//Rewrite Tile Data:
		ldy.b zero_word
	programming_mode_write_chars:
		lda [snesf1k_pgm_pointer],y
		jsr putchar
		iny
		//If Y is equal or greater, exit:
		cpy.w #$03C0
		//cpy.b pgm_size
		bcc programming_mode_write_chars
		
rts_programming_mode:
	rts
	
snesf1k_instruction_set:
//Instruction Set in order for pushed Buttons:
//    BYs  S  UD  L R  A  X  lr
  db "+-.",0,"<>",1,2,",",3,"[]"
	
used_bytes("PROG Routine",programming_mode)
//*******************************************************************//
//SNES RLE UNPACK ALGORITHM:
//Unpacks Data in custom format
//
//Bit: 76543210
//     ttttttaa
//     ||||||++-Amount (need to add one)
//     ++++++---TableAddr
//
//Variables:
//Stack:
//	+$03: Packed Data Address
//	+$07: Table Address
//	+$09: Unpacked Data Destination
//RAM:
//	$0800: Store Amount

define rle_store_amount($0800)

snes_rle_unpack:
	//set X and Y to $0000
	ldx.w #$0000
	phx
snes_rle_unpack_loop:
	ply
	lda ($03,s),y
	cmp #$FF
	bne snes_rle_unpack_loop_no_escape
		rts
	snes_rle_unpack_loop_no_escape:
	iny
	phy
	//Temp Save A:
	pha
	//Get Amount:
	and #$03
	inc
	//Set Amount counter:
	sta {rle_store_amount}
	//Restore A:
	pla
	//Get TableAddr:
	lsr #2
	tay
	//Get Byte from Table:
	lda ($07,s),y
	//Store Byte:
	snes_rle_unpack_loop_store:
		txy
		sta ($09,s),y
		inx
		dec {rle_store_amount}
		bne snes_rle_unpack_loop_store
	bra snes_rle_unpack_loop
//DEBUG
used_bytes("RLE Routine: ",snes_rle_unpack)
//*******************************************************************//
font0_packed:
	insert "font0.bin.packed"
font0_packed_end:
	db $FF
font0_table:
	insert "font0.bin.table"
font0_table_end:

//Omitting font1; contains character data for "{|}~"
//font1_packed:
//	insert "font1.bin.packed"
//font1_packed_end:
//	db $FF
//font1_table:
//	insert "font1.bin.table"
//font1_table_end:

used_bytes("FONT DATA: ",font0_packed)
//*******************************************************************//
putchar_start:
	include "putchar.asm"
//DEBUG
used_bytes("PRINT Routine: ",putchar_start)
//*******************************************************************//
decode_instruction:
//Fetch Instruction:
	ldy.b snesf1k_pgm_offset
	lda [snesf1k_pgm_pointer],y
//Decode:
	//If zero, return:
	bne decode_instruction_check_plus
		rts
	decode_instruction_check_plus:
		cmp.b #'+'
		bne decode_instruction_check_minus
		//Increase Value at Data Pointer:
			lda [snesf1k_data_pointer]
			inc
			sta [snesf1k_data_pointer]
			bra decode_instruction_check_end
			
	decode_instruction_check_minus:
		cmp.b #'-'
		bne decode_instruction_check_dp_inc
		//Decrease Value at Data Pointer:
			lda [snesf1k_data_pointer]
			dec
			sta [snesf1k_data_pointer]
			bra decode_instruction_check_end
			
	decode_instruction_check_dp_inc:
		cmp.b #'>'
		bne decode_instruction_check_dp_dec
		//Increase Data Pointer:
			ldx.b snesf1k_data_pointer
			inx
			//If Data Pointer passes into {snesf1k_pgm}, reset to {snesf1k_data}:
			cpx.w #({snesf1k_pgm_page}<<8)
			bcc decode_instruction_check_dp_inc_no_reset
				ldx.w #({snesf1k_data_page}<<8)
			decode_instruction_check_dp_inc_no_reset:
			stx.b snesf1k_data_pointer
			
	decode_instruction_check_dp_dec:
		cmp.b #'<'
		bne decode_instruction_check_branch_zero
		//Decrease Data Pointer:
			ldx.b snesf1k_data_pointer
			dex
			//If Data Pointer passes below ({snesf1k_data}-1), reset to ({snesf1k_pgm}-1):
			cpx.w #(({snesf1k_data_page}<<8)-1)
			bcs decode_instruction_check_dp_dec_no_reset
				ldx.w #(({snesf1k_pgm_page}<<8)-1)
			decode_instruction_check_dp_dec_no_reset:
			stx.b snesf1k_data_pointer
			
	decode_instruction_check_branch_zero:
		cmp.b #'['
		bne decode_instruction_check_branch_not_zero
		//Check Value at Data Pointer:
			lda [snesf1k_data_pointer]
		//If zero, branch to next matching ']':
			bne decode_instruction_check_end
			//Use X as match counter, start at 1:
				ldx #$0001
			decode_instruction_check_branch_zero_do_branch:
			//Advance Program Counter by 1:
				iny
			//Fetch new Instruction:
				lda [snesf1k_pgm_pointer],y
			//If '[', increase match counter:
				cmp.b #'['
				bne decode_instruction_check_branch_zero_do_branch_check_closing
					inx
				decode_instruction_check_branch_zero_do_branch_check_closing:
			//If ']', decrease match counter, exit if zero:
				cmp.b #']'
				bne decode_instruction_check_branch_zero_do_branch
					dex
					bne decode_instruction_check_branch_zero_do_branch
			//!BRA needed, as A holds ']':
				
				bra decode_instruction_check_end
				
	decode_instruction_check_branch_not_zero:
		cmp.b #']'
		bne decode_instruction_check_output
		//Check Value at Data Pointer:
			lda [snesf1k_data_pointer]
		//If not zero, branch to next matching '[':
			beq decode_instruction_check_end
			//Use X as match counter, start at 1:
				ldx #$0001
			decode_instruction_check_branch_not_zero_do_branch:
			//Decrease Program Counter:
				dey
			//Fetch new Instruction:
				lda [snesf1k_pgm_pointer],y
			//If ']', increase match counter:
				cmp.b #']'
				bne decode_instruction_check_branch_not_zero_do_branch_check_opening
					inx
				decode_instruction_check_branch_not_zero_do_branch_check_opening:
			//If '[', decrease match counter, exit if zero:
				cmp.b #'['
				bne decode_instruction_check_branch_not_zero_do_branch
					dex
					bne decode_instruction_check_branch_not_zero_do_branch
			
	decode_instruction_check_output:
		cmp.b #'.'
		bne decode_instruction_check_input
		//Output Value at Data Pointer to Screen:
			lda [snesf1k_data_pointer]
			jsr putchar
			
	decode_instruction_check_input:
		//cmp.b #','
		//bne decode_instruction_check_end
			//Do smth
			
	decode_instruction_check_end:
	//Advance Program Counter:
		iny
		sty.b snesf1k_pgm_offset
decode_instruction_rts:
	rts
	
used_bytes("BFINT Routine: ", decode_instruction)
//*******************************************************************//
update_cursor:
	//Set OAM Addr to $0000:
		stz $2102
	//Set X:
		lda.b snesf1k_pgm_offset
		and #$1F//32 positions on X
		asl #3//multiply with 8
		sta $2104
	//Set Y:
		lda.b cursor_y
		and #$F8
		dec//Height Adjustment
		sta $2104
	//Set Tile to '_'
		lda.b #$2F
		sta $2104
	//Set Attributes to $00:
		stz $2104
rts_update_cursor:
	rts
used_bytes("CURSR Routine: ", update_cursor)
//*******************************************************************//
//Note down PC to later calculate the Used Space:
variable used(pc() + ($8400-NMI))//Add Constant for NMI and RESET to used space
//*******************************************************************//
org($83B1)
//Lower 8 Bits of NMI Address need to be $B1, see RESET
NMI:
pha;phx;php
sep #$20//A 8-Bit
//DMA tile map:
	//CPU Destination
		ldx #$0018
		stx $4301
	//Size of Transfer
		ldx #$0800
		stx $4305
	//Set VRAM Destination:
		ldx #$7800
		stx $2116
	//CPU Source: LOW, MIDDLE
		stx $4302
	//Start Transfer:
		lda #$01
		sta $420B
	//Check bf_execute; ZERO: enable Sprites, ELSE: disable Sprites
		bit.b bf_execute
		bne NMI_no_bf_execute
			lda #$11
		NMI_no_bf_execute:
		sta $212C
	//Update Cursor:
		jsr update_cursor
RTI_NMI:
plp;plx;pla
rti

used_bytes("NMI Routine: ", NMI)
//*******************************************************************//
org($83E0)
//Reset Routine; wrapping around Interrupt Vectors:
RESET:
//Enable Interrupts:
	sei
//Set Native Mode:
	clc
	xce
//Set Register Size:
	sep #$20//A 8-Bit
	rep #$10//XY 16-Bit
//Set the Stack to $00FF:
	ldx #$00FF
//native Mode Vectors:
org($83EA)
//Only NMI is used:
	dw NMI//Will be executed as LDA ($xx),Y
//Transfer X to Stack:
	txs
//Unpack Font0 Data:
	pea $0100//Unpacked Data Destination
	pea font0_table
	pea font0_packed
	jsr snes_rle_unpack
//Jump to Init Routine:
	jmp INIT
//emulation Mode Vectors:
org($83FC)
	dw	RESET
	dw  RESET//IRQ/BRK will Reset
	
used_bytes("RESET Routine: ", RESET)
//*******************************************************************//
//*******************************************************************//
print "--------------------------------------------------\n"
print_free_space(used)
print "--------------------------------------------------\n"
//*******************************************************************//
//*******************************************************************//
org($8400)
