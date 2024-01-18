import os
import math
import time
import sys

comp_names = ["Y", "Cb", "Cr"]

class ComponentsData:
    def __init__(self):
        self.H = 0
        self.V = 0
        self.Tq = 0
        self.xi = 0
        self.yi = 0
        self.Td = 0  # quant table for DC
        self.Ta = 0  # quant table for AC

class HuffmanEntry:
    def __init__(self):
        self.sz = 0
        self.codeword = 0
        self.decoded = 0

class HuffmanTable:
    def __init__(self):
        self.nb_entries = 0
        self.entries = [HuffmanEntry() for _ in range(256)]

class PixelYCbCr:
    def __init__(self):
        self.Y = 0
        self.Cb = 0
        self.Cr = 0
        
class Picture:
    def __init__(self):
        self.data = bytearray()
        self.filesize = 0
        self.pos_in_file = 0
        self.size_X = 0
        self.size_Y = 0
        self.Hmax = 0
        self.Vmax = 0
        self.nb_MCU_total = 0
        self.compressed_pixeldata = bytearray()
        self.sz_compressed_pixeldata = 0
        self.pos_compressed_pixeldata = 0
        self.bitpos_in_compressed_pixeldata = 0
        self.nb_components = 0
        self.components_data = [ComponentsData() for _ in range(4)]
        self.huff_tables = [[HuffmanTable() for _ in range(2)] for _ in range(2)]
        self.quant_tables = [[[0 for _ in range(8)] for _ in range(8)] for _ in range(4)]
        self.pixels_YCbCr = [[PixelYCbCr() for _ in range(self.size_Y)] for _ in range(self.size_X)]

matrix8x8_t = [[0.0 for _ in range(8)] for _ in range(8)]

def get1i(data, pos):
    val = data[pos]
    pos += 1
    return val, pos

def get2i(data, pos):
    val = (data[pos] << 8) | data[pos + 1]
    pos += 2
    return val, pos

def get4i(data, pos):
    val = (data[pos[0]] << 24) | (data[pos[0] + 1] << 16) | (data[pos[0] + 2] << 8) | data[pos[0] + 3]
    pos[0] += 4
    return val


def get_marker(data, pos):
    return (data[pos] << 8) | data[pos + 1]

def to_bin(word, sz):
    str_val = ''
    for i in range(sz):
        str_val += '0' + str(int(bool(word & (1 << (sz - i - 1)))))
    return str_val

def ceil_to_multiple_of(val, multiple):
    return multiple * ((val + multiple - 1) // multiple)

def skip_EXIF(pic):
    len_val, pic.pos_in_file = get2i(pic.data, pic.pos_in_file)
    print(f"APP1 (probably EXIF) found (length {len_val} bytes), skipping")
    pic.pos_in_file += len_val - 2


def parse_APP0(pic):
    len_val, pic.pos_in_file = get2i(pic.data, pic.pos_in_file)
    print(f"APP0 found (length {len_val} bytes)")
    if len_val < 16:
        raise ValueError("APP0: too short")
    
    identifier = pic.data[pic.pos_in_file: pic.pos_in_file + 5].decode('utf-8')

    pic.pos_in_file += 5
    
    version_major, pic.pos_in_file  = get1i(pic.data, pic.pos_in_file)
    version_minor, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
    units, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
    Xdensity, pic.pos_in_file = get2i(pic.data, pic.pos_in_file)
    Ydensity, pic.pos_in_file = get2i(pic.data, pic.pos_in_file)
    Xthumbnail, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
    Ythumbnail, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
    
    if identifier != "JFIF\x00":
        print(f"Invalid identifier: {identifier}")
        raise ValueError("APP0: invalid identifier")
    
    print(f"version {version_major}.{version_minor}")
    print(f"units {units}")
    print(f"density X {Xdensity} Y {Ydensity}")
    
    bytes_thumbnail = 3 * Xthumbnail * Ythumbnail
    
    if bytes_thumbnail:
        print(f"thumbnail {bytes_thumbnail} bytes, skipping")
        pic.pos_in_file += bytes_thumbnail
    else:
        print("no thumbnail")

def parse_DQT(pic):
    Lq, pic.pos_in_file = get2i(pic.data, pic.pos_in_file)
    print(f"DQT found (length {Lq} bytes)")
    
    PqTq, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
    Pq = (PqTq >> 4) & 0x0f
    Tq = PqTq & 0x0f
    print(f"Pq (element precision) {Pq} -> {8 if Pq == 0 else 16} bits")
    print(f"Tq (table destination identifier) {Tq}")
    
    if Pq != 0:
        raise ValueError("DQT: only 8 bit precision supported")
    
    nb_data_bytes = Lq - 2 - 1
    
    if nb_data_bytes != 64:
        raise ValueError("DQT: nb_data_bytes != 64")
    
    for u in range(8):
        for v in range(8):
            Q, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
            pic.quant_tables[Tq][u][v] = Q

def parse_SOF0(pic):
    len_val, pic.pos_in_file = get2i(pic.data, pic.pos_in_file)
    print(f"SOF0 found (length {len_val} bytes)")

    P, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
    Y, pic.pos_in_file = get2i(pic.data, pic.pos_in_file)
    X, pic.pos_in_file = get2i(pic.data, pic.pos_in_file)
    Nf, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)

    if P != 8:
        raise ValueError("SOF0: P != 8 unsupported")

    if Y == 0:
        raise ValueError("SOF0: Y == 0 unsupported")

    print(f"P {P} (must be 8)")
    print(f"imagesize X {X} Y {Y}")
    print(f"Nf (number of components) {Nf}")

    if Nf != 3:
        raise ValueError("picture does not have 3 components, this code will not work")

    pic.size_X = X
    pic.size_Y = Y

    for i in range(Nf):
        C, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
        HV, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
        H = (HV >> 4) & 0x0F
        V = HV & 0x0F
        Tq, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)

        pic.components_data[i].H = H
        pic.components_data[i].V = V
        pic.components_data[i].Tq = Tq

        print(f"component {i} ({comp_names[i]}) C {C}, H {H}, V {V}, Tq {Tq}")

    pic.nb_components = Nf

    Hmax = Vmax = 0

    for i in range(pic.nb_components):
        if pic.components_data[i].H > Hmax:
            Hmax = pic.components_data[i].H
        if pic.components_data[i].V > Vmax:
            Vmax = pic.components_data[i].V

    pic.Hmax = Hmax
    pic.Vmax = Vmax

    pic.nb_MCU_total = (ceil_to_multiple_of(pic.size_X, 8 * Hmax) // (8 * Hmax)) * \
                       (ceil_to_multiple_of(pic.size_Y, 8 * Hmax) // (8 * Vmax))

    print(f"Hmax {Hmax} Vmax {Vmax}")
    print(f"MCU_total {pic.nb_MCU_total}")

    for i in range(pic.nb_components):
        xi = int((pic.size_X * pic.components_data[i].H) / Hmax + 0.5)
        yi = int((pic.size_Y * pic.components_data[i].V) / Vmax + 0.5)

        pic.components_data[i].xi = xi
        pic.components_data[i].yi = yi

        print(f"component {i} ({comp_names[i]}) xi {xi} yi {yi}")

    print("allocating memory for pixels")

    pic.pixels_YCbCr = [
            [PixelYCbCr() for _ in range(pic.size_Y)]
            for _ in range(pic.size_X)
        ]

    print("memory allocated")


def parse_DHT(pic):
    len_val, pic.pos_in_file = get2i(pic.data, pic.pos_in_file)
    print(f"DHT found (length {len_val} bytes)")

    TcTh, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
    Tc = (TcTh >> 4) & 0x0f
    Th = TcTh & 0x0f

    print(f"Tc {Tc} ({'DC' if Tc == 0 else 'AC'} table)")
    print(f"Th (table destination identifier) {Th}")

    L = []
    mt = 0
    for i in range(16):
        a , pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
        L.append(a)
        mt += L[i]

    print(f"total {mt} codes")

    codeword = 0
    for i in range(16):
        for j in range(L[i]):
            V, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
            pic.huff_tables[Tc][Th].entries[pic.huff_tables[Tc][Th].nb_entries].sz = i + 1
            pic.huff_tables[Tc][Th].entries[pic.huff_tables[Tc][Th].nb_entries].codeword = codeword
            pic.huff_tables[Tc][Th].entries[pic.huff_tables[Tc][Th].nb_entries].decoded = V
            pic.huff_tables[Tc][Th].nb_entries += 1
            codeword += 1
        codeword <<= 1


def parse_SOS(pic):
    len_val, pic.pos_in_file = get2i(pic.data, pic.pos_in_file)
    print(f"SOS found (length {len_val} bytes)")

    Ns, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
    print(f"Ns {Ns}")

    for j in range(Ns):
        Cs, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
        TdTa, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
        Td = (TdTa >> 4) & 0x0f
        Ta = TdTa & 0x0f

        print(f"component {j} ({comp_names[j]}) Cs {Cs} Td {Td} Ta {Ta}")
        pic.components_data[j].Td = Td  # DC
        pic.components_data[j].Ta = Ta  # AC

    Ss, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
    Se, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
    AhAl, pic.pos_in_file = get1i(pic.data, pic.pos_in_file)
    Ah = (AhAl >> 4) & 0x0f
    Al = AhAl & 0x0f

    print(f"Ss {Ss} Se {Se} Ah {Ah} Al {Al}")

    pic.pos_compressed_pixeldata = pic.pos_in_file

    print(f"compressed pixeldata starts at pos {pic.pos_compressed_pixeldata}\n")

def copy_bitmap_data_remove_stuffing(pic):
    print("removing stuffing...")

    # Get length of bitstream without stuffing
    pos = pic.pos_compressed_pixeldata
    size = 0
    combined = 0

    while combined != 0xFFD9:
        if pos >= pic.filesize:
            raise ValueError("marker EOI (0xFFD9) missing")

        byte = pic.data[pos]
        pos += 1

        if byte == 0xFF:
            byte2 = pic.data[pos]
            pos += 1

            if byte2 != 0x00:
                combined = (byte << 8) | byte2
            else:
                size += 1
        else:
            size += 1

    size_stuffed = pos - pic.pos_compressed_pixeldata - 2

    # Remove stuffing
    pic.compressed_pixeldata = [0] * size

    print(f"{size_stuffed} bytes with stuffing")

    i = pic.pos_compressed_pixeldata
    pos = 0
    size_without_stuffing = 0

    while i < pic.pos_compressed_pixeldata + size_stuffed:
        if pic.data[i] != 0xFF:
            pic.compressed_pixeldata[pos] = pic.data[i]
            pos += 1
            size_without_stuffing += 1
            i += 1
        elif pic.data[i] == 0xFF and pic.data[i + 1] == 0x00:
            pic.compressed_pixeldata[pos] = 0xFF
            pos += 1
            size_without_stuffing += 1
            i += 2
        else:
            raise ValueError(f"unexpected marker 0x{pic.data[i]:02x}{pic.data[i + 1]:02x} found in bitstream")

    pic.bitpos_in_compressed_pixeldata = 0
    pic.sz_compressed_pixeldata = size_without_stuffing
    pic.pos_in_file = pic.pos_compressed_pixeldata + size_stuffed

    print(f"{size_without_stuffing} data bytes without stuffing\n")


def convert_to_neg(bits, sz):
    ret = -((bits ^ 0xFFFF) & ((1 << sz) - 1))
    return ret

def bitstream_get_bits(pic, nb_bits):
    if nb_bits > 16:
        raise ValueError("bitstream_get_bits: >16 bits requested")

    index = pic.bitpos_in_compressed_pixeldata // 8
    pos_in_byte = 7 - pic.bitpos_in_compressed_pixeldata % 8
    ret = 0
    bits_copied = 0

    while pos_in_byte >= 0 and bits_copied < nb_bits:
        ret <<= 1
        ret |= int(bool(pic.compressed_pixeldata[index] & (1 << pos_in_byte)))
        bits_copied += 1
        pos_in_byte -= 1
        if pos_in_byte < 0:
            pos_in_byte = 7
            index += 1

    return ret

def bitstream_remove_bits(pic, nb_bits):
    pic.bitpos_in_compressed_pixeldata += nb_bits

def huff_decode(pic, Tc, Th, sz, bitstream, decoded):

    for i in range(pic.huff_tables[Tc][Th].nb_entries):
        if (pic.huff_tables[Tc][Th].entries[i].sz == sz and
                pic.huff_tables[Tc][Th].entries[i].codeword == bitstream):
            decoded = pic.huff_tables[Tc][Th].entries[i].decoded
            return True, decoded

    return False,decoded

def bitstream_get_next_decoded_element(pic, Tc, Th, decoded, nb_bits):
    huff_candidate = 0
    found = False
    
    while pic.bitpos_in_compressed_pixeldata < 8 * pic.sz_compressed_pixeldata:
        found = False
        for num_bits in range(1, 17):
            nb_bits = num_bits

            if pic.bitpos_in_compressed_pixeldata + nb_bits > 8 * pic.sz_compressed_pixeldata:
                raise ValueError("end of stream, requested too many bits")
            
            huff_candidate = bitstream_get_bits(pic, nb_bits)

            boo, decoded = huff_decode(pic, Tc, Th, nb_bits, huff_candidate, decoded)
            
            if boo:
                found = True
                bitstream_remove_bits(pic, nb_bits)
                return True, decoded, nb_bits
        
        if not found:
            is_all_one = True
            for i in range(nb_bits - 1):
                if (huff_candidate & (1 << i)) == 0:
                    is_all_one = False
                    break
            
            if is_all_one:
                bitstream_remove_bits(pic, nb_bits)
            else:
                raise ValueError(
                    f"unknown code in bitstream bitpos {pic.bitpos_in_compressed_pixeldata} byte 0x{pic.compressed_pixeldata[pic.bitpos_in_compressed_pixeldata // 8]:x} [prev 0x{pic.compressed_pixeldata[(pic.bitpos_in_compressed_pixeldata // 8) - 1]:x}, next 0x{pic.compressed_pixeldata[(pic.bitpos_in_compressed_pixeldata // 8) + 1]:x}]")
    return False, decoded, nb_bits


def store_data_unit_YCbCr(pic, MCU, component, data_unit, data):
    zoomX = pic.Hmax // pic.components_data[component].H
    zoomY = pic.Vmax // pic.components_data[component].V

    scaleX = 8 * pic.components_data[component].H
    scaleY = 8 * pic.components_data[component].V

    startX = MCU % (ceil_to_multiple_of(pic.size_X, 8 * pic.Hmax) // (scaleX * zoomX))
    startY = MCU // (ceil_to_multiple_of(pic.size_X, 8 * pic.Hmax) // (scaleY * zoomY))

    startHiX = data_unit % pic.components_data[component].H
    startHiY = data_unit // pic.components_data[component].H

    for x in range(8):
        for y in range(8):
            for zx in range(zoomX):
                for zy in range(zoomY):
                    posX = (scaleX * startX + 8 * startHiX + x) * zoomX + zx
                    posY = (scaleY * startY + 8 * startHiY + y) * zoomY + zy

                    if posX < pic.size_X and posY < pic.size_Y:
                        if component == 0:
                            pic.pixels_YCbCr[posX][posY].Y = data[x][y]
                        elif component == 1:
                            pic.pixels_YCbCr[posX][posY].Cb = data[x][y]
                        elif component == 2:
                            pic.pixels_YCbCr[posX][posY].Cr = data[x][y]
                        else:
                            raise ValueError("unknown component")


def reverse_ZZ_and_dequant(pic, quant_table, inp, outp):
    reverse_ZZ_u = [
        [0, 0, 1, 2, 1, 0, 0, 1],
        [2, 3, 4, 3, 2, 1, 0, 0],
        [1, 2, 3, 4, 5, 6, 5, 4],
        [3, 2, 1, 0, 0, 1, 2, 3],
        [4, 5, 6, 7, 7, 6, 5, 4],
        [3, 2, 1, 2, 3, 4, 5, 6],
        [7, 7, 6, 5, 4, 3, 4, 5],
        [6, 7, 7, 6, 5, 6, 7, 7]
    ]
    reverse_ZZ_v = [
        [0, 1, 0, 0, 1, 2, 3, 2],
        [1, 0, 0, 1, 2, 3, 4, 5],
        [4, 3, 2, 1, 0, 0, 1, 2],
        [3, 4, 5, 6, 7, 6, 5, 4],
        [3, 2, 1, 0, 1, 2, 3, 4],
        [5, 6, 7, 7, 6, 5, 4, 3],
        [2, 3, 4, 5, 6, 7, 7, 6],
        [5, 4, 5, 6, 7, 7, 6, 7]
    ]
    
    for u in range(8):
        for v in range(8):
            outp[reverse_ZZ_u[u][v]][reverse_ZZ_v[u][v]] = inp[u][v] * pic.quant_tables[quant_table][u][v]

a_c = 0.9807
b_c = 0.8314
c_c = 0.5555
d_c = 0.1950
e_c = 0.9238
f_c = 0.3826
g_c = 0.7071

tab_coefs = [
    [0.7071,  a_c,  e_c,  b_c,  g_c,  c_c,  f_c,  d_c],
    [0.7071,  b_c,  f_c, -d_c, -g_c, -a_c, -e_c, -c_c],
    [0.7071,  c_c, -f_c, -a_c, -g_c,  d_c,  e_c,  b_c],
    [0.7071,  d_c, -e_c, -c_c,  g_c,  b_c, -f_c, -a_c],
    [0.7071, -d_c, -e_c,  c_c,  g_c, -b_c, -f_c,  a_c],
    [0.7071, -c_c, -f_c,  a_c, -g_c, -d_c,  e_c, -b_c],
    [0.7071, -b_c,  f_c,  d_c, -g_c,  a_c, -e_c,  c_c],
    [0.7071, -a_c,  e_c, -b_c,  g_c, -c_c,  f_c, -d_c]
]


def data_unit_do_idct(inp, outp):
    for y in range(8):
        for x in range(8):
            sxy = 0
            for u in range(8):
                for v in range(8):
                    Svu = inp[v][u]
                    sxy += Svu * tab_coefs[x][u] * tab_coefs[y][v]
            
            sxy *= 0.25
            sxy += 128
            outp[x][y] = sxy

def print_matrix(m):
    for u in range(8):
        for v in range(8):
            print(f"{m[u][v]:5f}", end=" ")
        print()
    print()

def parse_bitmap_data(pic):
    print("parsing bitstream...")
    
    nb_bits = 0
    component = 0
    data_unit = 0
    ac_count = 0
    
    precedent_DC = [0, 0, 0, 0]
    
    nb_MCU = 0
    matrix = [[0 for _ in range(8)] for _ in range(8)]
    
    while nb_MCU < pic.nb_MCU_total:
        component = 0
        while component < pic.nb_components:
            data_unit = 0
            while data_unit < (pic.components_data[component].V * pic.components_data[component].H):
                for u in range(8):
                    for v in range(8):
                        matrix[u][v] = 0
                
                SSSS = 0
                DC = 0
                boo, SSSS, nb_bits = bitstream_get_next_decoded_element(pic, 0, pic.components_data[component].Td, SSSS, nb_bits)
                
                if not boo:
                    errx(1, "no DC data")
                if SSSS:
                    bits_DC = bitstream_get_bits(pic, SSSS)      
                    bitstream_remove_bits(pic, SSSS)
                    msb_DC = bool(bits_DC & (1 << (SSSS - 1)))
                      
                    if msb_DC:
                        DC = precedent_DC[component] + bits_DC
                    else:
                        DC = precedent_DC[component] + convert_to_neg(bits_DC, SSSS)
                else:
                    DC = precedent_DC[component] + 0
               
                matrix[0][0] = DC
                precedent_DC[component] = DC
                
                AC = 0
                ac_count = 0
                while ac_count < 63:
                    RRRRSSSS = 0
                    boo, RRRRSSSS, nb_bits = bitstream_get_next_decoded_element(pic, 1, pic.components_data[component].Ta, RRRRSSSS, nb_bits)
                    if not boo:
                        errx(1, "no AC data")

                    RRRR = RRRRSSSS >> 4
                    SSSS = RRRRSSSS & 0x0f
                    
                    if RRRR == 0 and SSSS == 0:
                        break
                    elif RRRR == 0x0F and SSSS == 0:
                        ac_count += 16
                    else:
                        ac_count += RRRR
                        
                        bits_AC = bitstream_get_bits(pic, SSSS)
                        bitstream_remove_bits(pic, SSSS)
                        
                        msb_AC = bool(bits_AC & (1 << (SSSS - 1)))
                        
                        if msb_AC:
                            AC = bits_AC
                        else:
                            AC = convert_to_neg(bits_AC, SSSS)
                        
                        u = (ac_count + 1) // 8
                        v = (ac_count + 1) % 8
                        matrix[u][v] = AC
                        ac_count += 1


                matrix_dequant = [[0 for _ in range(8)] for _ in range(8)]

                reverse_ZZ_and_dequant(pic, pic.components_data[component].Tq, matrix, matrix_dequant)
                
                matrix_decoded = [[0 for _ in range(8)] for _ in range(8)]
                data_unit_do_idct(matrix_dequant, matrix_decoded)

                store_data_unit_YCbCr(pic, nb_MCU, component, data_unit, matrix_decoded)

                data_unit += 1
            component += 1
        nb_MCU += 1
    
    print("parsed %lu MCU" % nb_MCU)

def open_new_picture(name, picture):
    with open(name, "rb") as f:
        picture.filesize = os.path.getsize(name)
        picture.data = bytearray(f.read())
    
    print(f"{picture.filesize} bytes read from {name}\n")

    picture.pos_in_file = 0
    picture.nb_components = 0
    for i in range(2):
        for j in range(2):
            picture.huff_tables[i][j].nb_entries = 0

def parse_picture(picture):
    while picture.pos_in_file < picture.filesize - 1:
        marker = get_marker(picture.data, picture.pos_in_file)
        picture.pos_in_file += 2
        
        print("marker: ", marker)

        if marker == 0xFFD8:
            print("SOI found")
        elif marker == 0xFFE1:
            skip_EXIF(picture)
        elif marker == 0xFFE0:
            parse_APP0(picture)
        elif marker == 0xFFDB:
            parse_DQT(picture)
        elif marker == 0xFFC0:
            parse_SOF0(picture)
        elif marker == 0xFFC4:
            parse_DHT(picture)
        elif marker == 0xFFDA:
            parse_SOS(picture)
            copy_bitmap_data_remove_stuffing(picture)
            parse_bitmap_data(picture)
        elif marker == 0xFFD9:
            print("EOI found")
        else:
            print(f"unknown marker 0x{marker:04x} pos {picture.pos_in_file}")
            break

        print()

def clamp(v):
    if v < 0:
        return 0
    if v > 255:
        return 255
    return int(v)


def write_ppm(pic, filename):
    print(f"writing file {filename}")
    with open(filename, "w") as out:
        out.write(f"P3\n{pic.size_X} {pic.size_Y}\n255\n")
        
        for y in range(pic.size_Y):
            for x in range(pic.size_X):
                Y = pic.pixels_YCbCr[x][y].Y
                Cb = pic.pixels_YCbCr[x][y].Cb
                Cr = pic.pixels_YCbCr[x][y].Cr
                
                r = Y + 1.402 * (Cr - 128)
                g = Y - (0.114 * 1.772 * (Cb - 128) + 0.299 * 1.402 * (Cr - 128)) / 0.587
                b = Y + 1.772 * (Cb - 128)
                out.write(f"{clamp(round(r))} {clamp(round(g))} {clamp(round(b))} ")
            out.write("\n")
    print("output file written\n")

def main():
    if len(sys.argv) != 2:
        print("Usage: python script.py <filename.jpg>")
        sys.exit(1)
    start_time = time.time()
    pic = Picture()
    open_new_picture(sys.argv[1], pic)
    parse_picture(pic)
    end_time = time.time()
    write_ppm(pic, "decodedimage.ppm")
    write_time = time.time()
    elapsed_time_algo = end_time - start_time
    elapsed_time_write = write_time - end_time
    
    print(f"Time taken by the Jpeg decoder algorithm: {elapsed_time_algo} seconds")
    print(f"Time taken for writing the image: {elapsed_time_write} seconds")

if __name__ == "__main__":
    main()
