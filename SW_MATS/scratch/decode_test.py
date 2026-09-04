# Verilog style bit-packing parser test
# Byte 0: {cx[1:0], type[0], eof[0], 4'b1111}
# Byte 1: {cy[0], cx[8:2]}
# Byte 2: {w[0], cy[7:1]}
# Byte 3: {w[8:1]}
# Byte 4: {h[7:0]}
# Byte 5: 8'hFF

# Target values to encode and decode
# eof = 1, type = 0
# cx = 320 (9'b101000000 -> cx[8:2] = 7'b1010000 = 0x50, cx[1:0] = 2'b00 = 0)
# cy = 240 (8'b11110000 -> cy[7:1] = 7'b1111000 = 0x78, cy[0] = 1'b0 = 0)
# w = 100 (9'b001100100 -> w[8:1] = 8'b00110010 = 50, w[0] = 1'b0 = 0)
# h = 80 (8'b01010000 = 80)

cx = 320
cy = 240
w = 100
h = 80
type_val = 0
eof = 1

cx_1_0 = cx & 0x03
cx_8_2 = (cx >> 2) & 0x7F

cy_0 = cy & 0x01
cy_7_1 = (cy >> 1) & 0x7F

w_0 = w & 0x01
w_8_1 = (w >> 1) & 0xFF

h_val = h & 0xFF

b0 = (cx_1_0 << 6) | (type_val << 5) | (eof << 4) | 0x0F
b1 = (cy_0 << 7) | cx_8_2
b2 = (w_0 << 7) | cy_7_1
b3 = w_8_1
b4 = h_val
b5 = 0xFF

raw_bytes = bytes([b0, b1, b2, b3, b4, b5])
print(f"Packed Bytes: {[hex(x) for x in raw_bytes]}")

# Decode
dec_b0 = raw_bytes[0]
dec_b1 = raw_bytes[1]
dec_b2 = raw_bytes[2]
dec_b3 = raw_bytes[3]
dec_b4 = raw_bytes[4]
dec_b5 = raw_bytes[5]

# Validation checks
if (dec_b0 & 0x0F) != 0x0F or dec_b5 != 0xFF:
    print("Invalid Header/Tail")
else:
    dec_cx_1_0 = (dec_b0 >> 6) & 0x03
    dec_type = (dec_b0 >> 5) & 0x01
    dec_eof = (dec_b0 >> 4) & 0x01
    
    dec_cy_0 = (dec_b1 >> 7) & 0x01
    dec_cx_8_2 = dec_b1 & 0x7F
    
    dec_w_0 = (dec_b2 >> 7) & 0x01
    dec_cy_7_1 = dec_b2 & 0x7F
    
    dec_w_8_1 = dec_b3
    
    # Reconstruct
    dec_cx = (dec_cx_8_2 << 2) | dec_cx_1_0
    dec_cy = (dec_cy_7_1 << 1) | dec_cy_0
    dec_w = (dec_w_8_1 << 1) | dec_w_0
    dec_h = dec_b4
    
    print(f"Decoded:")
    print(f"  eof : {dec_eof} (expected {eof})")
    print(f"  type: {dec_type} (expected {type_val})")
    print(f"  cx  : {dec_cx} (expected {cx})")
    print(f"  cy  : {dec_cy} (expected {cy})")
    print(f"  w   : {dec_w} (expected {w})")
    print(f"  h   : {dec_h} (expected {h})")
