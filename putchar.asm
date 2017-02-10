putchar:
//X is x_counter:
	ldx.b x_counter
//If "Null Terminator", Z Flag is set
	bne no_null_terminator
	//return if NULL terminator was read:
		rts
	no_null_terminator:
	//Check if lowercase letter:
		cmp #$61//lower 'a'
		bcc no_lowercase
			cmp #$7B//greater 'z'
			bcs no_lowercase
			//Get Uppercase by substracting $20:
				sec;sbc #$20
	no_lowercase:
	//check if Newline:
		cmp #$0A
		bne no_newline
		//Newline: goto next Line
			dex
			beq printf_goto_next_line
			ld_text_from_base_newline_loop:
				//Put space char for rest of line
					lda.b #$20//White-Space Character
				//Write Char to Buffer:
					jsr write_char_to_buffer
					dex
					bne ld_text_from_base_newline_loop
				//Reload Counter:
					bra printf_goto_next_line
	no_newline:
	//Write Char to Buffer:
		jsr write_char_to_buffer
	//Decrease x_counter, if zero, reset x_counter:
		dex
		bne rts_putchar
		printf_goto_next_line:
		//Reload Counter:
			ldx.b space_word
rts_putchar:
	//Save x_counter
	stx.b x_counter
	rts
//-------------------------------------------//

write_char_to_buffer:
//Write Char to Buffer:
rep #$20//A 16-Bit
	and #$00FF
	sta [char_out_buffer_addr]
	inc.b char_out_buffer_addr
	inc.b char_out_buffer_addr
	//Check if $03C0 chars were written
	lda.b char_out_buffer_addr
	and #$07FF
	cmp #$0780
	//When greater or equal, carry is set:
	bcc write_char_to_buffer_no_reload_addr
	write_char_to_buffer_reload_addr:
		ldx.w #$7800
		stx.b char_out_buffer_addr
		ldx.b space_word
	write_char_to_buffer_no_reload_addr:
	//As there is no other place to do it, calculate Cursor Y position here:
		lda.b snesf1k_pgm_offset
		lsr #2
		sta.b cursor_y
sep #$20//A 8-Bit
rts
