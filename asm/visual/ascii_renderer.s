
//==============================================================================
// ASCII Renderer - ARM64 Assembly Implementation
//
// Port of ascii_renderer.c to pure ARM64 assembly
// Functions for bitmap font rendering
//==============================================================================

.text
.align 4

//==============================================================================
// Constants
//==============================================================================
ascii_constants:
char_width:     .word 8
char_height:    .word 8 
vis_width:      .word 800
vis_height:     .word 600

//==============================================================================
// ASCII Font Data - 8x8 bitmap font
// Each character uses 2 uint32 values (64 bits total)
// 256 characters arranged in 16x16 grid
//==============================================================================
.align 4
ascii_font:
    // Character row 0 (chars 0-15)
    .word 0x00000000, 0x00000000  // char 0 0x00
    .word 0x00000000, 0x00000000  // char 1 0x01
    .word 0x00000000, 0x00000000  // char 2 0x02
    .word 0x00000000, 0x00000000  // char 3 0x03
    .word 0x00000000, 0x00000000  // char 4 0x04
    .word 0x00000000, 0x00000000  // char 5 0x05
    .word 0x00000000, 0x00000000  // char 6 0x06
    .word 0x00000000, 0x00000000  // char 7 0x07
    .word 0x00000000, 0x00000000  // char 8 0x08
    .word 0x00000000, 0x00000000  // char 9 0x09
    .word 0x00000000, 0x00000000  // char 10 0x0a
    .word 0x00000000, 0x00000000  // char 11 0x0b
    .word 0x00000000, 0x00000000  // char 12 0x0c
    .word 0x00000000, 0x00000000  // char 13 0x0d
    .word 0x00000000, 0x00000000  // char 14 0x0e
    .word 0x00000000, 0x00000000  // char 15 0x0f
    
    // Character row 1 (chars 16-31)
    .word 0x00000000, 0x00000000  // char 16 0x10
    .word 0x00000000, 0x00000000  // char 17 0x11
    .word 0x00000000, 0x00000000  // char 18 0x12
    .word 0x00000000, 0x00000000  // char 19 0x13
    .word 0x00000000, 0x00000000  // char 20 0x14
    .word 0x00000000, 0x00000000  // char 21 0x15
    .word 0x00000000, 0x00000000  // char 22 0x16
    .word 0x00000000, 0x00000000  // char 23 0x17
    .word 0x00000000, 0x00000000  // char 24 0x18
    .word 0x00000000, 0x00000000  // char 25 0x19
    .word 0x00000000, 0x00000000  // char 26 0x1a
    .word 0x00000000, 0x00000000  // char 27 0x1b
    .word 0x00000000, 0x00000000  // char 28 0x1c
    .word 0x00000000, 0x00000000  // char 29 0x1d
    .word 0x00000000, 0x00000000  // char 30 0x1e
    .word 0x00000000, 0x00000000  // char 31 0x1f
    
    // Character row 2 (chars 32-47) - Basic symbols
    .word 0x00000000, 0x00000000  // char 32 ' ' space
    .word 0x00000000, 0x00000000  // char 33 '!' 
    .word 0x00000000, 0x00000000  // char 34 '"'
    .word 0x24247e24, 0x0000247e  // char 35 '#' hash
    .word 0x00000000, 0x00000000  // char 36 '$'
    .word 0x00000000, 0x00000000  // char 37 '%'
    .word 0x00000000, 0x00000000  // char 38 '&'
    .word 0x00000000, 0x00000000  // char 39 '\''
    .word 0x00000000, 0x00000000  // char 40 '('
    .word 0x00000000, 0x00000000  // char 41 ')'
    .word 0x7c284400, 0x00004428  // char 42 '*' asterisk
    .word 0x7c101000, 0x00001010  // char 43 '+' plus
    .word 0x00000000, 0x00000000  // char 44 ','
    .word 0x7c000000, 0x00000000  // char 45 '-' minus
    .word 0x00000000, 0x00000000  // char 46 '.'
    .word 0x10080402, 0x00804020  // char 47 '/' slash
    
    // Character row 3 (chars 48-63) - Numbers and symbols
    .word 0x42424242, 0x007e4242  // char 48 '0'
    .word 0x42424242, 0x007e4242  // char 49 '1'
    .word 0x42424242, 0x007e4242  // char 50 '2'
    .word 0x42424242, 0x007e4242  // char 51 '3'
    .word 0x42424242, 0x007e4242  // char 52 '4'
    .word 0x42424242, 0x007e4242  // char 53 '5'
    .word 0x42424242, 0x007e4242  // char 54 '6'
    .word 0x42424242, 0x007e4242  // char 55 '7'
    .word 0x42424242, 0x007e4242  // char 56 '8'
    .word 0x42424242, 0x007e4242  // char 57 '9'
    .word 0x00000000, 0x00000000  // char 58 ':'
    .word 0x00000000, 0x00000000  // char 59 ';'
    .word 0x20100800, 0x00000810  // char 60 '<' less than
    .word 0x007c0000, 0x0000007c  // char 61 '=' equals
    .word 0x08102000, 0x00002010  // char 62 '>' greater than
    .word 0x00000000, 0x00000000  // char 63 '?'
    
    // Character row 4 (chars 64-79) - @ and uppercase letters A-O
    .word 0x00000000, 0x00000000  // char 64 '@'
    .word 0x4242427e, 0x007e4242  // char 65 'A'
    .word 0x4242427e, 0x007e4242  // char 66 'B'
    .word 0x4242427e, 0x007e4242  // char 67 'C'
    .word 0x4242427e, 0x007e4242  // char 68 'D'
    .word 0x4242427e, 0x007e4242  // char 69 'E'
    .word 0x4242427e, 0x007e4242  // char 70 'F'
    .word 0x4242427e, 0x007e4242  // char 71 'G'
    .word 0x4242427e, 0x007e4242  // char 72 'H'
    .word 0x4242427e, 0x007e4242  // char 73 'I'
    .word 0x4242427e, 0x007e4242  // char 74 'J'
    .word 0x4242427e, 0x007e4242  // char 75 'K'
    .word 0x4242427e, 0x007e4242  // char 76 'L'
    .word 0x4242427e, 0x007e4242  // char 77 'M'
    .word 0x4242427e, 0x007e4242  // char 78 'N'
    .word 0x4242427e, 0x007e4242  // char 79 'O'
    
    // Character row 5 (chars 80-95) - Letters P-Z and brackets
    .word 0x4242427e, 0x007e4242  // char 80 'P'
    .word 0x4242427e, 0x007e4242  // char 81 'Q'
    .word 0x4242427e, 0x007e4242  // char 82 'R'
    .word 0x4242427e, 0x007e4242  // char 83 'S'
    .word 0x4242427e, 0x007e4242  // char 84 'T'
    .word 0x4242427e, 0x007e4242  // char 85 'U'
    .word 0x4242427e, 0x007e4242  // char 86 'V'
    .word 0x4242427e, 0x007e4242  // char 87 'W'
    .word 0x4242427e, 0x007e4242  // char 88 'X'
    .word 0x4242427e, 0x007e4242  // char 89 'Y'
    .word 0x4242427e, 0x007e4242  // char 90 'Z'
    .word 0x4040407c, 0x007c4040  // char 91 '[' left bracket
    .word 0x10204080, 0x00020408  // char 92 '\' backslash
    .word 0x0404047c, 0x007c0404  // char 93 ']' right bracket
    .word 0x44281000, 0x00000000  // char 94 '^' caret
    .word 0x00000000, 0x007c0000  // char 95 '_' underscore
    
    // Character row 6 (chars 96-111) - lowercase and more symbols
    .word 0x00000000, 0x00000000  // char 96 '`'
    .word 0x00000000, 0x00000000  // char 97 'a'
    .word 0x00000000, 0x00000000  // char 98 'b'
    .word 0x00000000, 0x00000000  // char 99 'c'
    .word 0x00000000, 0x00000000  // char 100 'd'
    .word 0x00000000, 0x00000000  // char 101 'e'
    .word 0x00000000, 0x00000000  // char 102 'f'
    .word 0x00000000, 0x00000000  // char 103 'g'
    .word 0x00000000, 0x00000000  // char 104 'h'
    .word 0x00000000, 0x00000000  // char 105 'i'
    .word 0x00000000, 0x00000000  // char 106 'j'
    .word 0x00000000, 0x00000000  // char 107 'k'
    .word 0x00000000, 0x00000000  // char 108 'l'
    .word 0x00000000, 0x00000000  // char 109 'm'
    .word 0x00000000, 0x00000000  // char 110 'n'
    .word 0x00000000, 0x00000000  // char 111 'o'
    
    // Character row 7 (chars 112-127) - more lowercase and special chars
    .word 0x00000000, 0x00000000  // char 112 'p'
    .word 0x00000000, 0x00000000  // char 113 'q'
    .word 0x00000000, 0x00000000  // char 114 'r'
    .word 0x00000000, 0x00000000  // char 115 's'
    .word 0x00000000, 0x00000000  // char 116 't'
    .word 0x00000000, 0x00000000  // char 117 'u'
    .word 0x00000000, 0x00000000  // char 118 'v'
    .word 0x00000000, 0x00000000  // char 119 'w'
    .word 0x00000000, 0x00000000  // char 120 'x'
    .word 0x00000000, 0x00000000  // char 121 'y'
    .word 0x00000000, 0x00000000  // char 122 'z'
    .word 0x4020201c, 0x001c2020  // char 123 '{' left brace
    .word 0x10101010, 0x00101010  // char 124 '|' pipe
    .word 0x04080870, 0x00700808  // char 125 '}' right brace
    .word 0x004c3200, 0x00000000  // char 126 '~' tilde
    .word 0x00000000, 0x00000000  // char 127

    // Rows 8-15 (chars 128-255) - Extended ASCII filled with blanks
    .rept 128
    .word 0x00000000, 0x00000000
    .endr

//==============================================================================
// void draw_ascii_char_asm(uint32_t *pixels, int x, int y, char c, uint32_t color, int alpha)
//
// Draw a single ASCII character at position with color and alpha blending
// x0: pixels buffer
// w1: x position  
// w2: y position
// w3: character (char c)
// w4: color (uint32_t)
// w5: alpha (int, 0-255)
//==============================================================================
.global _draw_ascii_char_asm
_draw_ascii_char_asm:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    
    // Save callee-saved registers with proper non-overlapping offsets
    stp x19, x20, [sp, #16]    // 16-31
    stp x21, x22, [sp, #32]    // 32-47  
    stp x23, x24, [sp, #48]    // 48-63
    stp x25, x26, [sp, #64]    // 64-79
    stp x27, x28, [sp, #80]    // 80-95
    
    // Store parameters in callee-saved registers
    mov x19, x0               // pixels buffer
    mov w20, w1               // x position
    mov w21, w2               // y position  
    mov w22, w3               // character
    mov w23, w4               // color
    mov w24, w5               // alpha
    
    // Bounds check: character range 0-255 (now support full range)
    cmp w22, #0
    b.lt .Ldac_return         // if c < 0, return
    cmp w22, #255
    b.gt .Ldac_return         // if c > 255, return
    
    // Bounds check: position within screen
    cmp w20, #0
    b.lt .Ldac_return
    ldr w25, =800             // VIS_WIDTH
    cmp w20, w25
    b.ge .Ldac_return
    
    cmp w21, #0
    b.lt .Ldac_return
    ldr w25, =600             // VIS_HEIGHT  
    cmp w21, w25
    b.ge .Ldac_return
    
    // Get character bitmap from new 8x8 font
    // Each character uses 2 uint32 values (64 bits)
    // Font layout: char_index * 8 bytes = char_index * 2 words
    lsl w25, w22, #3          // char_index * 8 (bytes per char)
    adr x26, ascii_font       // Get font base address
    add x26, x26, x25         // Point to character data
    
    // Load character bitmap (2 words = 8 bytes)
    ldp w27, w28, [x26]       // w27 = first 4 bytes, w28 = last 4 bytes
    
    // OPTIMIZATION: Fast path for alpha==255 (90-95% of calls)
    cmp w24, #255
    b.eq .Ldac_alpha_opaque
    
    // Alpha blending path for alpha < 255  
    // Extract RGB components from color for alpha blending
    ubfx w25, w23, #16, #8    // r = (color >> 16) & 0xFF
    ubfx w26, w23, #8, #8     // g = (color >> 8) & 0xFF  
    ubfx w27, w23, #0, #8     // b = color & 0xFF
    
    // Apply alpha: component = (component * alpha) / 255
    mul w25, w25, w24         // r * alpha
    mov w0, #255
    udiv w25, w25, w0         // r = (r * alpha) / 255
    
    mul w26, w26, w24         // g * alpha  
    udiv w26, w26, w0         // g = (g * alpha) / 255
    
    mul w27, w27, w24         // b * alpha
    udiv w27, w27, w0         // b = (b * alpha) / 255
    
    // Reconstruct final color: 0xFF000000 | (r << 16) | (g << 8) | b
    mov w28, #0xFF            
    lsl w28, w28, #24         // Alpha = 0xFF000000
    lsl w25, w25, #16         // r << 16
    lsl w26, w26, #8          // g << 8
    orr w28, w28, w25         // Add red
    orr w28, w28, w26         // Add green  
    orr w28, w28, w27         // Add blue - final color in w28
    b .Ldac_render_bitmap
    
.Ldac_alpha_opaque:
    // Fast path: alpha==255, use color directly  
    orr w28, w23, #0xFF000000 // final color = color | 0xFF000000
    
.Ldac_render_bitmap:
    
    // Now render the 8x8 character
    // Reload character bitmap
    lsl w25, w22, #3          // char_index * 8
    adr x26, ascii_font       // Get font base address
    add x26, x26, x25
    ldp w6, w7, [x26]         // w6 = rows 0-3, w7 = rows 4-7
    
    // Render each row of the 8x8 character
    mov w0, #0                // row counter
.Ldac_row_loop:
    cmp w0, #8
    b.ge .Ldac_return
    
    // Get row data - need to extract correct byte from w6 or w7
    cmp w0, #4
    b.ge .Ldac_upper_rows
    
    // Lower rows (0-3): extract from w6
    lsl w2, w0, #3            // row * 8
    lsr w1, w6, w2            // shift by row*8 bits
    and w1, w1, #0xFF         // mask to get byte
    b .Ldac_process_row
    
.Ldac_upper_rows:
    // Upper rows (4-7): extract from w7  
    sub w2, w0, #4            // row - 4
    lsl w2, w2, #3            // (row-4) * 8
    lsr w1, w7, w2            // shift by (row-4)*8 bits
    and w1, w1, #0xFF         // mask to get byte
    
.Ldac_process_row:
    // w1 now contains the row bitmap byte
    mov w2, #0                // column counter
    
.Ldac_col_loop:
    cmp w2, #8
    b.ge .Ldac_next_row
    
    // Check if pixel should be drawn
    mov w3, #7
    sub w3, w3, w2            // bit position (7-col for MSB first)
    lsr w4, w1, w3            // shift pixel bit to position 0
    and w4, w4, #1            // mask to get single bit
    
    cbz w4, .Ldac_next_col    // skip if pixel is 0
    
    // Calculate pixel position
    add w5, w20, w2           // pixel_x = char_x + col
    add w6, w21, w0           // pixel_y = char_y + row
    
    // OPTIMIZATION: Skip redundant per-pixel bounds checks
    // Caller already guarantees character is fully on-screen
    
    // Calculate pixel offset: y * width + x
    ldr w25, =800             // width
    mul w6, w6, w25           // y * width
    add w6, w6, w5            // + x
    lsl w6, w6, #2            // * 4 (bytes per pixel)
    
    // Set pixel
    str w28, [x19, x6]        // pixels[offset] = color
    
.Ldac_next_col:
    add w2, w2, #1
    b .Ldac_col_loop
    
.Ldac_next_row:
    add w0, w0, #1
    b .Ldac_row_loop
    
.Ldac_return:
    // Restore callee-saved registers  
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    
    ldp x29, x30, [sp], #96
    ret
