import os
from python import Python
from python import PythonObject
from math import sqrt
from time import now
import pathlib as path
import sys

struct Array1D(CollectionElement):
    var data: Pointer[UInt8]
    var size: Int

    fn __init__(inout self, size: Int, val: UInt8):
        self.size = size
        self.data = Pointer[UInt8].alloc(self.size)
        for i in range(self.size):
            self.data.store(i, val)

    fn __getitem__(self, i: Int) -> UInt8:
        return self.data.load(i)

    fn __setitem__(inout self, i: Int, val: UInt8):
        self.data.store(i, val)

    fn __copyinit__(inout self, existing: Self):
        self.size = existing.size
        self.data = Pointer[UInt8].alloc(self.size)
        for i in range(self.size):
            self.data.store(i, existing.data.load(i))

    fn __moveinit__(inout self, owned existing: Self):
        self.size = existing.size
        self.data = existing.data
        existing.data = Pointer[UInt8].alloc(0)  # Hollow out the existing value

    fn __del__(owned self):
        self.data.free()

struct Array1Dnew(CollectionElement):
    var data: Pointer[Int16]
    var size: Int

    fn __init__(inout self, size: Int, val: Int16):
        self.size = size
        self.data = Pointer[Int16].alloc(self.size)
        for i in range(self.size):
            self.data.store(i, val)

    fn __getitem__(self, i: Int) -> Int16:
        return self.data.load(i)

    fn __setitem__(inout self, i: Int, val: Int16):
        self.data.store(i, val)

    fn __copyinit__(inout self, existing: Self):
        self.size = existing.size
        self.data = Pointer[Int16].alloc(self.size)
        for i in range(self.size):
            self.data.store(i, existing.data.load(i))

    fn __moveinit__(inout self, owned existing: Self):
        self.size = existing.size
        self.data = existing.data
        existing.data = Pointer[Int16].alloc(0)

    fn __del__(owned self):
        self.data.free()

struct Array2D(CollectionElement):
    var data: Pointer[Float32]
    var dim0: Int
    var dim1: Int

    fn __init__(inout self, dim0: Int, dim1: Int):
        self.dim0 = dim0
        self.dim1 = dim1
        self.data = Pointer[Float32].alloc(dim0 * dim1)
    
    fn __copyinit__(inout self, other: Array2D):
        self.dim0 = other.dim0
        self.dim1 = other.dim1
        self.data = Pointer[Float32].alloc(self.dim0 * self.dim1)
        for i in range(self.dim0 * self.dim1):
            self.data.store(i, other.data.load(i))
    
    fn __moveinit__(inout self, owned existing: Array2D):
        self.dim0 = existing.dim0
        self.dim1 = existing.dim1
        self.data = existing.data

    fn __getitem__(borrowed self, i: Int, j: Int) -> Float32:
        return self.data.load(i * self.dim1 + j)

    fn __setitem__(inout self, i: Int, j: Int, value: Float32):
        self.data.store(i * self.dim1 + j, value)

    fn __del__(owned self):
        self.data.free()
    
    fn print_array(borrowed self):
        for i in range(self.dim0):
            for j in range(1):
                print(self.__getitem__(i, j), ' ', self.__getitem__(i, j+1), ' ', self.__getitem__(i, j+2), ' ', self.__getitem__(i, j+3), ' ',
                      self.__getitem__(i, j+4), ' ', self.__getitem__(i, j+5), ' ', self.__getitem__(i, j+6), ' ', self.__getitem__(i, j+7))

struct Array2Dnew(CollectionElement):
    var data: Pointer[SIMD[DType.float32, 8]]
    var dim: Int

    fn __init__(inout self, dim: Int):
        self.dim = dim
        self.data = Pointer[SIMD[DType.float32, 8]].alloc(dim)
    
    fn __copyinit__(inout self, other: Array2Dnew):
        self.dim = other.dim
        self.data = Pointer[SIMD[DType.float32, 8]].alloc(self.dim)
        for i in range(self.dim):
            self.data.store(i, other.data.load(i))
    
    fn __moveinit__(inout self, owned existing: Array2Dnew):
        self.dim = existing.dim
        self.data = existing.data

    fn __getitem__(borrowed self, i: Int) -> SIMD[DType.float32, 8]:
        return self.data.load(i)

    fn __setitem__(inout self, i: Int, value: SIMD[DType.float32, 8]):
        self.data.store(i, value)
    
    fn __setitem2__(inout self, i: Int, j: Int, value: Float32):
        var simd_vector = self.data.load(i)
        simd_vector[j] = value
        self.data.store(i, simd_vector)

    fn __del__(owned self):
        self.data.free()
    
    fn print_array(borrowed self):
        for i in range(self.dim):
            print(self.__getitem__(i))

struct Array3D(CollectionElement):
    var data: Pointer[UInt8]
    var dim0: Int
    var dim1: Int
    var dim2: Int

    fn __init__(inout self, dim0: Int, dim1: Int, dim2: Int):
        self.dim0 = dim0
        self.dim1 = dim1
        self.dim2 = dim2
        self.data = Pointer[UInt8].alloc(dim0 * dim1 * dim2)
    
    fn __copyinit__(inout self, other: Array3D):
        self.dim0 = other.dim0
        self.dim1 = other.dim1
        self.dim2 = other.dim2
        self.data = Pointer[UInt8].alloc(self.dim0 * self.dim1 * self.dim2)
        for i in range(self.dim0 * self.dim1 * self.dim2):
            self.data.store(i, other.data.load(i))
    
    fn __moveinit__(inout self, owned existing: Array3D):
        self.dim0 = existing.dim0
        self.dim1 = existing.dim1
        self.dim2 = existing.dim2
        self.data = existing.data

    fn __getitem__(borrowed self, i: Int, j: Int, k: Int) -> UInt8:
        return self.data.load(i * self.dim1 * self.dim2 + j * self.dim2 + k)

    fn __setitem__(inout self, i: SIMD[DType.uint8, 1], j: Int, k: Int, value: SIMD[DType.uint8, 1]):
        self.data.store(i * self.dim1 * self.dim2 + j * self.dim2 + k, value)

    fn __del__(owned self):
        self.data.free()


struct ComponentsData(CollectionElement):
    var H: SIMD[DType.uint32, 1]
    var V: SIMD[DType.uint32, 1]
    var Tq: SIMD[DType.uint32, 1]
    var xi: SIMD[DType.uint32, 1]
    var yi: SIMD[DType.uint32, 1]
    var Td: Int #quant table for DC
    var Ta: Int #quant table for AC

    fn __init__(inout self, H: Int, V: Int, Tq: Int, xi: Int, yi: Int, Td: Int, Ta: Int):
        self.H = H
        self.V = V
        self.Tq = Tq
        self.xi = xi
        self.yi = yi
        self.Td = Td
        self.Ta = Ta

    fn __copyinit__(inout self, existing: Self):
        self.H = existing.H
        self.V = existing.V
        self.Tq = existing.Tq
        self.xi = existing.xi
        self.yi = existing.yi
        self.Td = existing.Td
        self.Ta = existing.Ta

    fn __moveinit__(inout self, owned existing: Self):
        self.H = existing.H
        self.V = existing.V
        self.Tq = existing.Tq
        self.xi = existing.xi
        self.yi = existing.yi
        self.Td = existing.Td
        self.Ta = existing.Ta

@register_passable
struct HuffmanEntry(CollectionElement):
    var sz: Int
    var codeword: Int
    var decoded: Int

    fn __init__(sz: Int, codeword: Int, decoded: Int) -> Self:
        return Self{sz: sz, codeword: codeword, decoded: decoded}
    
    fn __copyinit__(existing) -> Self:
        return Self{sz: existing.sz, codeword:existing.codeword, decoded: existing.decoded}

@register_passable
struct HuffmanEntryArray(CollectionElement):
    var data: Pointer[HuffmanEntry]
    var size: Int

    fn __init__(size: Int) -> Self:
        return Self{size : size, data:Pointer[HuffmanEntry].alloc(size)}

    fn __copyinit__(existing: Self) -> Self:
        let newData = Pointer[HuffmanEntry].alloc(existing.size)
        for i in range(existing.size):
            newData.store(i, existing.data.load(i))
        return Self{size: existing.size, data: newData}

@register_passable
struct HuffmanTable(CollectionElement):
    var nb_entries: Int
    var entries: HuffmanEntryArray

    fn __init__(nb_entries: Int, entries: HuffmanEntryArray) -> Self:
        return Self{nb_entries: nb_entries, entries: entries}
    
    fn __copyinit__(existing) -> Self:
        return Self{nb_entries: existing.nb_entries, entries: existing.entries}

@register_passable
struct HuffmanTableArray:
    var data: Pointer[HuffmanTable]
    var size: Int
    fn __init__(size: Int) -> Self:
        return Self{size : size, data:Pointer[HuffmanTable].alloc(size)}

    fn __copyinit__(existing: Self) -> Self:
        let newData = Pointer[HuffmanTable].alloc(existing.size)
        for i in range(existing.size):
            newData.store(i, existing.data.load(i))
        return Self{size: existing.size, data: newData}


struct PixelYCbCr(CollectionElement):
    var Y: Float32
    var Cb: Float32
    var Cr: Float32

    fn __init__(inout self, Y: Float32, Cb: Float32, Cr: Float32):
        self.Y = Y
        self.Cb = Cb
        self.Cr = Cr

    fn __copyinit__(inout self, existing: Self):
        self.Y = existing.Y
        self.Cb = existing.Cb
        self.Cr = existing.Cr

    fn __moveinit__(inout self, owned existing: Self):
        self.Y = existing.Y
        self.Cb = existing.Cb
        self.Cr = existing.Cr

struct picture_t:
    var data: DynamicVector[UInt8]
    var helpdata: DynamicVector[UInt16]
    var stringdata: String
    var filesize: Int
    var pos_in_file: Int
    var size_X: SIMD[DType.uint32, 1]
    var size_Y: SIMD[DType.uint32, 1]
    var Hmax: SIMD[DType.uint32, 1]
    var Vmax: SIMD[DType.uint32, 1]
    var nb_MCU_total: SIMD[DType.uint32, 1]
    var compressed_pixeldata: DynamicVector[Int]
    var sz_compressed_pixeldata: Int
    var pos_compressed_pixeldata: Int
    var bitpos_in_compressed_pixeldata: Int
    var nb_components: SIMD[DType.uint32, 1]
    var components_data: DynamicVector[ComponentsData]
    var huff_tables1: HuffmanTableArray
    var huff_tables2: HuffmanTableArray
    var quant_table: Array3D
    var pixel_Y: Array2D
    var pixel_Cb: Array2D
    var pixel_Cr: Array2D

    fn __init__(inout self, data: DynamicVector[UInt8], helpdata: DynamicVector[UInt16], stringdata: String, filesize: Int, pos_in_file: Int, size_X: Int, size_Y: Int, Hmax: Int, Vmax: Int, nb_MCU_total: Int, compressed_pixeldata: DynamicVector[Int], sz_compressed_pixeldata: Int, pos_compressed_pixeldata: Int, bitpos_in_compressed_pixeldata: Int, nb_components: Int, components_data: DynamicVector[ComponentsData], huff_tables1: HuffmanTableArray, huff_tables2: HuffmanTableArray, quant_table: Array3D, pixel_Y: Array2D, pixel_Cb: Array2D, pixel_Cr: Array2D):
        self.data = data
        self.helpdata = helpdata
        self.stringdata = stringdata
        self.filesize = filesize
        self.pos_in_file = pos_in_file
        self.size_X = size_X
        self.size_Y = size_Y
        self.Hmax = Hmax
        self.Vmax = Vmax
        self.nb_MCU_total = nb_MCU_total
        self.compressed_pixeldata = compressed_pixeldata
        self.sz_compressed_pixeldata = sz_compressed_pixeldata
        self.pos_compressed_pixeldata = pos_compressed_pixeldata
        self.bitpos_in_compressed_pixeldata = bitpos_in_compressed_pixeldata
        self.nb_components = nb_components
        self.components_data = components_data
        self.huff_tables1 = huff_tables1
        self.huff_tables2 = huff_tables2
        self.quant_table = quant_table
        self.pixel_Y = pixel_Y
        self.pixel_Cb = pixel_Cb
        self.pixel_Cr = pixel_Cr


fn open_new_picture(name: String, inout picture: picture_t) raises:
    let _os = Python.import_module("os")

    picture.filesize = _os.path.getsize(name).__index__()

    var f = open(name, "rb")
    let data = f.read()
    f.close()
    picture.stringdata = data
    for i in range(len(data)):
        let x: UInt8
        x = UInt8(ord(data[i]))

        let y: UInt16
        y = UInt16(ord(data[i]))
        picture.data.push_back(x)
        picture.helpdata.push_back(y)

    picture.pos_in_file = 0
    picture.nb_components = 0

    for i in range(2):
        let huffmanEntryArray1 = HuffmanEntryArray(256)
        let huffmanEntryArray2 = HuffmanEntryArray(256)
        for j in range(256):
            huffmanEntryArray1.data.store(j, HuffmanEntry(0, 0, 0))
            huffmanEntryArray2.data.store(j, HuffmanEntry(0, 0, 0))
        let huffmanTable1 = HuffmanTable(0, huffmanEntryArray1)
        let huffmanTable2 = HuffmanTable(0, huffmanEntryArray2)
        picture.huff_tables1.data.store(i, huffmanTable1)
        picture.huff_tables2.data.store(i, huffmanTable2)
    print(picture.filesize, " bytes read from ", name + "\n")



fn get_marker(data: DynamicVector[UInt16], pos: Int) -> UInt16:
    return (data[pos] << 8) | data[pos + 1]


fn get1i(data: DynamicVector[UInt8],inout pos: Int) -> UInt16:
    let val:UInt16 = data[pos].cast[DType.uint16]()
    pos += 1
    return val

fn get2i(data: DynamicVector[UInt8],inout pos: Int) -> UInt16:
    let val:UInt16 = (data[pos].cast[DType.uint16]() << 8 | data[pos+1].cast[DType.uint16]()).cast[DType.uint16]()
    pos += 2
    return val

fn skip_EXIF(inout picture: picture_t) raises:
    let len_val:UInt16 = get2i(picture.data, picture.pos_in_file)
    print("APP1 (probably EXIF) found (length", len_val, "bytes), skipping")
    picture.pos_in_file += int(len_val) -2

fn parse_APP0(inout picture: picture_t) raises:
    let len_val:UInt16 = get2i(picture.data, picture.pos_in_file)
    print("APP0 found (length" ,len_val, "bytes)")
    if len_val < 16:
        raise Error("APP0: too short")
    let identifier:String = picture.stringdata[picture.pos_in_file: picture.pos_in_file + 5]

    picture.pos_in_file += 5

    let version_major:UInt16 = get1i(picture.data, picture.pos_in_file)
    let version_minor:UInt16 = get1i(picture.data, picture.pos_in_file)
    let units:UInt16 = get1i(picture.data, picture.pos_in_file)
    let Xdensity:UInt16 = get2i(picture.data, picture.pos_in_file)
    let Ydensity:UInt16 = get2i(picture.data, picture.pos_in_file)
    let Xthumbnail:UInt16 = get1i(picture.data, picture.pos_in_file)
    let Ythumbnail:UInt16 = get1i(picture.data, picture.pos_in_file)

    if identifier != "JFIF\x00":
        print("Invalid identifier: ", identifier)
        raise Error("APP0: invalid identifier")
    
    print("version",  version_major, ".", version_minor)
    print("units" ,units)
    print("density X", Xdensity, "Y", Ydensity)
    
    let bytes_thumbnail = 3 * Xthumbnail * Ythumbnail
    print("bytes_thumbnail:", bytes_thumbnail)
    
    if bytes_thumbnail !=0:
        print("thumbnail" ,bytes_thumbnail, "bytes, skipping")
        picture.pos_in_file += int(bytes_thumbnail)
    else:
        print("no thumbnail")

fn parse_DQT(inout picture: picture_t) raises:
    let Lq:UInt16 = get2i(picture.data, picture.pos_in_file)
    print("DQT found (length", Lq, "bytes)")

    let PqTq:UInt8 = get1i(picture.data, picture.pos_in_file).cast[DType.uint8]()

    let Pq:UInt8 = (PqTq >> 4) & 0x0f
    let Tq:UInt8 = PqTq & 0x0f
    if Pq == 0:
        print("Pq (element precision)", Pq, "->" ,"8 bits")
    else:
        print("Pq (element precision)", Pq, "->" ,"8 bits")
    print("Tq (table destination identifier)", Tq)
    if Pq != 0:
        raise Error("DQT: only 8 bit precision supported")
    
    let nb_data_bytes:UInt16 = Lq - 2 - 1
    
    if nb_data_bytes != 64:
        raise Error("DQT: nb_data_bytes != 64")
    
    for u in range(8):
        for v in range(8):
            let Q:UInt8 = get1i(picture.data, picture.pos_in_file).cast[DType.uint8]()
            picture.quant_table.__setitem__(Tq,u,v,Q)


fn ceil_to_multiple_of(val: SIMD[DType.uint32, 1], multiple: SIMD[DType.uint32, 1]) -> SIMD[DType.uint32, 1]:
    let result = multiple * ((val + multiple - 1) // multiple)
    return result

fn parse_SOF0(inout picture: picture_t, comp_names: DynamicVector[String]) raises:
    let len_val:UInt16 = get2i(picture.data, picture.pos_in_file)
    print("SOF0 found (length", len_val, "bytes)")
    let P:UInt32 = get1i(picture.data, picture.pos_in_file).cast[DType.uint32]()
    let Y:UInt32 = get2i(picture.data, picture.pos_in_file).cast[DType.uint32]()
    let X:UInt32 = get2i(picture.data, picture.pos_in_file).cast[DType.uint32]()
    let Nf:UInt32 = get1i(picture.data, picture.pos_in_file).cast[DType.uint32]()

    if P != 8:
        raise Error("SOF0: P != 8 unsupported")

    if Y == 0:
        raise Error("SOF0: Y == 0 unsupported")

    print("P", P, "(must be 8)")
    print("imagesize X" ,X, "Y", Y)
    print("Nf (number of components)", Nf)

    if Nf != 3:
        raise Error("picture does not have 3 components, this code will not work")
    
    picture.size_X = X
    picture.size_Y = Y

    for i in range(Nf):
        let C:UInt32 = get1i(picture.data, picture.pos_in_file).cast[DType.uint32]()
        let HV:UInt32 = get1i(picture.data, picture.pos_in_file).cast[DType.uint32]()
        let H:UInt32 = (HV >> 4) & 0x0F
        let V:UInt32 = HV & 0x0F
        let Tq:UInt32 = get1i(picture.data, picture.pos_in_file).cast[DType.uint32]()
        
        let h = ComponentsData(0,0,0,0,0,0,0)
        picture.components_data.push_back(h)
        picture.components_data[i].H = H
        picture.components_data[i].V = V
        picture.components_data[i].Tq = Tq

        print("component", i, comp_names[i], "C", C, "H", H, "V", V, "Tq", Tq)

    picture.nb_components = Nf

    var Hmax:UInt32 = 0
    var Vmax:UInt32 = 0

    for i in range(picture.nb_components):
        if picture.components_data[i].H > Hmax:
            Hmax = picture.components_data[i].H
        if picture.components_data[i].V > Vmax:
            Vmax = picture.components_data[i].V

    picture.Hmax = Hmax
    picture.Vmax = Vmax

    let temp_Hmax: UInt32 = Hmax.cast[DType.uint32]()
    let temp_Vmax: UInt32 = Vmax.cast[DType.uint32]()

    picture.nb_MCU_total = (ceil_to_multiple_of(picture.size_X, 8 * temp_Hmax) // (8 * temp_Hmax)) * \
                       (ceil_to_multiple_of(picture.size_Y, 8 * temp_Hmax) // (8 * temp_Vmax))
    

    print("Hmax", Hmax, "Vmax", Vmax)
    print("MCU_total", picture.nb_MCU_total)

    for i in range(picture.nb_components):
        let xi =((picture.size_X * (picture.components_data[i].H)) / Hmax + 0.5)
        let yi = (picture.size_Y * picture.components_data[i].V) / Vmax + 0.5

        picture.components_data[i].xi = xi
        picture.components_data[i].yi = yi

        print("component", i, comp_names[i], "xi", xi, "yi", yi)
    
    print("allocating memory for pixels")
    picture.pixel_Y = Array2D(X.to_int(), Y.to_int())
    picture.pixel_Cb = Array2D(X.to_int(), Y.to_int())
    picture.pixel_Cr = Array2D(X.to_int(), Y.to_int())
    for x in range(picture.size_X):
        for y in range(picture.size_Y):
            picture.pixel_Y.__setitem__(x,y,0.0)
            picture.pixel_Cb.__setitem__(x,y,0.0)
            picture.pixel_Cr.__setitem__(x,y,0.0)
    print("memory allocated")

fn parse_DHT(inout picture: picture_t) raises:

    let len:UInt16 = get2i(picture.data, picture.pos_in_file)
    print("DHT found (length", len, "bytes)")

    let TcTh:UInt8 = get1i(picture.data, picture.pos_in_file).cast[DType.uint8]()
    let Tc:UInt8 = (TcTh >> 4) & 0x0f
    let Th:UInt8 = TcTh & 0x0f

    if Tc == 0:
        print("Tc", Tc, "DC Table")
    else:
        print("Tc", Tc, "AC Table")
    print("Th (table destination identifier)" ,Th)

    var L = Array1D(16,0)
    var mt:UInt8 = 0
    for i in range(16):
        let a:UInt8 = get1i(picture.data, picture.pos_in_file).cast[DType.uint8]()
        L.__setitem__(i,a)
        mt += L.__getitem__(i)

    print("total" ,mt, "codes")

    var codeword: UInt16 = 0


    for i in range(16):
        for j in range(L.__getitem__(i)):
            let V:UInt8 = get1i(picture.data, picture.pos_in_file).cast[DType.uint8]()
            if Tc == 0:
                var huffmanTable1 = picture.huff_tables1.data.load(Th.to_int())

                var huffmanEntry1 = huffmanTable1.entries.data.load(huffmanTable1.nb_entries)
                huffmanEntry1.sz = i+1
                huffmanEntry1.codeword = codeword.to_int()
                huffmanEntry1.decoded = V.to_int()
                huffmanTable1.entries.data.store(huffmanTable1.nb_entries, huffmanEntry1)

                huffmanTable1.nb_entries +=1
                picture.huff_tables1.data.store(Th.to_int(), huffmanTable1)


            elif Tc == 1:

                var huffmanTable2 = picture.huff_tables2.data.load(Th.to_int())
                var huffmanEntry2 = huffmanTable2.entries.data.load(huffmanTable2.nb_entries)
                huffmanEntry2.sz = i+1
                huffmanEntry2.codeword = codeword.to_int()
                huffmanEntry2.decoded = V.to_int()
                huffmanTable2.entries.data.store(huffmanTable2.nb_entries, huffmanEntry2)

                huffmanTable2.nb_entries +=1
                picture.huff_tables2.data.store(Th.to_int(), huffmanTable2)

            codeword += 1
        codeword <<= 1

fn parse_SOS(inout picture: picture_t, comp_names: DynamicVector[String]) raises:
    let len:UInt16 = get2i(picture.data, picture.pos_in_file)
    print("SOS found (length", len, "bytes)")

    let Ns:UInt8 = get1i(picture.data, picture.pos_in_file).cast[DType.uint8]()
    print("Ns", Ns)

    for j in range(Ns):
        let Cs:UInt8 = get1i(picture.data, picture.pos_in_file).cast[DType.uint8]()
        let TdTa:UInt8 = get1i(picture.data, picture.pos_in_file).cast[DType.uint8]()
        let Td:UInt8 = (TdTa >> 4) & 0x0f
        let Ta:UInt8 = TdTa & 0x0f

        print("component", j, comp_names[j], "Cs", Cs, "Td", Td, "Ta", Ta)
        picture.components_data[j].Td = Td.to_int()  # DC
        picture.components_data[j].Ta = Ta.to_int()  # AC

    let Ss:UInt8 = get1i(picture.data, picture.pos_in_file).cast[DType.uint8]()
    let Se:UInt8 = get1i(picture.data, picture.pos_in_file).cast[DType.uint8]()
    let AhAl:UInt8 = get1i(picture.data, picture.pos_in_file).cast[DType.uint8]()
    let Ah:UInt8 = (AhAl >> 4) & 0x0f
    let Al:UInt8 = AhAl & 0x0f

    print("Ss", Ss, "Se", Se, "Ah", Ah, "Al", Al)

    picture.pos_compressed_pixeldata = picture.pos_in_file

    print("compressed pixeldata starts at pos", picture.pos_compressed_pixeldata)


fn copy_bitmap_data_remove_stuffing(inout picture: picture_t) raises:
    print("removing stuffing...")
    var pos:Int = picture.pos_compressed_pixeldata
    var size:Int = 0
    var byte:UInt8 = 0
    var combined:UInt16 = 0
    while combined != 0xFFD9:
        if pos >= picture.filesize:
            raise Error("marker EOI (0xFFD9) missing")
        
        byte = picture.data[pos]
        pos += 1

        if byte == 0xFF:
            let byte2:UInt8 = picture.data[pos]
            pos += 1

            if byte2 != 0x00:
                combined = (byte.cast[DType.uint16]() << 8) | byte2.cast[DType.uint16]()
            else:
                size += 1
        else:
            size += 1

    let size_stuffed:Int = pos - picture.pos_compressed_pixeldata - 2

    for i in range(size):
        picture.compressed_pixeldata.push_back(0)
    
    print(size_stuffed, "bytes with stuffing")

    var i:Int = picture.pos_compressed_pixeldata
    pos = 0
    var size_without_stuffing:Int = 0

    while i < picture.pos_compressed_pixeldata + size_stuffed:
        if picture.data[i] != 0xFF:
            picture.compressed_pixeldata[pos] = picture.data[i].to_int()
            pos += 1
            size_without_stuffing += 1
            i += 1
        elif picture.data[i] == 0xFF and picture.data[i + 1] == 0x00:
            picture.compressed_pixeldata[pos] = 0xFF
            pos += 1
            size_without_stuffing += 1
            i += 2
        else:
            raise Error("unexpected marker found in bitstream")

    picture.bitpos_in_compressed_pixeldata = 0
    picture.sz_compressed_pixeldata = size_without_stuffing
    picture.pos_in_file = picture.pos_compressed_pixeldata + size_stuffed

    print(size_without_stuffing, "data bytes without stuffing\n")


fn convert_to_neg(bits: UInt16, sz: UInt8) -> Int16:
    let ret: Int16 = -((bits.cast[DType.int16]() ^ 0xFFFF) & ((1 << sz.cast[DType.int16]()) - 1))
    return ret

fn bitstream_get_bits(inout picture: picture_t, nb_bits: UInt32) raises -> UInt16:
    if nb_bits > 16:
        raise Error("bitstream_get_bits: >16 bits requested")

    var index:Int = picture.bitpos_in_compressed_pixeldata // 8
    var pos_in_byte:Int = 7 - picture.bitpos_in_compressed_pixeldata % 8
    var ret:UInt16 = 0
    var bits_copied:UInt32 = 0

    while pos_in_byte >= 0 and bits_copied < nb_bits:
        ret <<= 1
        let temp = picture.compressed_pixeldata[index] & (1 << pos_in_byte)
        if temp > 0:
            ret |= 1
        else:
            ret |= 0

        bits_copied += 1
        pos_in_byte -= 1
        if pos_in_byte < 0:
            pos_in_byte = 7
            index += 1

    return ret

fn bitstream_remove_bits(inout picture: picture_t, nb_bits: UInt32) raises:
    picture.bitpos_in_compressed_pixeldata += nb_bits.to_int()

fn huff_decode(inout picture: picture_t, Tc: UInt8, Th: UInt8, sz: UInt8, bitstream: UInt16, inout decoded: UInt8)  raises ->Bool:
    if Tc == 0:
        for i in range(picture.huff_tables1.data.load(Th.to_int()).nb_entries):
            if (picture.huff_tables1.data.load(Th.to_int()).entries.data.load(i).sz == sz.to_int() and
                picture.huff_tables1.data.load(Th.to_int()).entries.data.load(i).codeword == bitstream.to_int()):

                decoded = picture.huff_tables1.data.load(Th.to_int()).entries.data.load(i).decoded
                return True
    elif Tc == 1:
        for i in range(picture.huff_tables2.data.load(Th.to_int()).nb_entries):
            if (picture.huff_tables2.data.load(Th.to_int()).entries.data.load(i).sz == sz.to_int() and
                picture.huff_tables2.data.load(Th.to_int()).entries.data.load(i).codeword == bitstream.to_int()):

                decoded = picture.huff_tables2.data.load(Th.to_int()).entries.data.load(i).decoded
                return True

    return False

fn bitstream_get_next_decoded_element(inout picture: picture_t, Tc: UInt8, Th: UInt8,inout decoded: UInt8, inout nb_bits: UInt32)  raises ->Bool:
    var huff_candidate: UInt16 = 0
    var found:Bool = False
    while picture.bitpos_in_compressed_pixeldata < 8 * picture.sz_compressed_pixeldata:
        found = False
        for num_bits in range(1, 17):
            nb_bits = num_bits
            if picture.bitpos_in_compressed_pixeldata + nb_bits > 8 * picture.sz_compressed_pixeldata:
                raise Error("end of stream, requested too many bits")
            
            huff_candidate = bitstream_get_bits(picture, nb_bits)
            let boo:Bool = huff_decode(picture, Tc, Th, nb_bits.cast[DType.uint8](), huff_candidate, decoded)

            if boo:
                found = True
                bitstream_remove_bits(picture, nb_bits)
                return True
        if not found:
            var is_all_one:Bool = True
            for i in range(nb_bits - 1):
                if (huff_candidate & (1 << i)) == 0:
                    is_all_one = False
                    break
            
            if is_all_one:
                bitstream_remove_bits(picture, nb_bits)
            else:
                raise Error("unknown code in bitstream bitpos")
    return False

fn reverse_ZZ_and_dequant(inout picture: picture_t, quant_table: UInt8, inp: Array2D, inout outp: Array2D):
    var reverse_ZZ_u = Array2D(8, 8)
    let vector = SIMD[DType.float32, 64] (0, 0, 1, 2, 1, 0, 0, 1, 2, 3, 4, 3, 2, 1, 0, 0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1, 0, 0, 1, 2, 3, 
                                          4, 5, 6, 7, 7, 6, 5, 4, 3, 2, 1, 2, 3, 4, 5, 6, 7, 7, 6, 5, 4, 3, 4, 5, 6, 7, 7, 6, 5, 6, 7, 7)
    var counter:Int = 0

    for i in range(8):
        for j in range(8):
            reverse_ZZ_u.__setitem__(i,j,vector[counter])
            counter+=1

    var reverse_ZZ_v = Array2D(8, 8)
    let vector1 = SIMD[DType.float32, 64] (0, 1, 0, 0, 1, 2, 3, 2, 1, 0, 0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 0, 0, 1, 2, 3, 4, 5, 6, 7, 6, 5, 4,
                                           3, 2, 1, 0, 1, 2, 3, 4, 5, 6, 7, 7, 6, 5, 4, 3, 2, 3, 4, 5, 6, 7, 7, 6, 5, 4, 5, 6, 7, 7, 6, 7)
    counter = 0

    for i in range(8):
        for j in range(8):
            reverse_ZZ_v.__setitem__(i,j,vector1[counter])
            counter+=1
    
    for u in range(8):
        for v in range(8):
            let a = inp.__getitem__(u,v) * (picture.quant_table.__getitem__(quant_table.to_int(),u,v).cast[DType.float32] ())
            outp.__setitem__(reverse_ZZ_u.__getitem__(u,v).to_int(),reverse_ZZ_v.__getitem__(u,v).to_int(), a)


fn data_unit_do_idct(inp: Array2D, inout outp: Array2D, mat: Array2Dnew):
    var rxy: Float32 = 0
    for y in range(8):
        for x in range(8):
            rxy = 0
            for u in range(8):
                for v in range(8):
                    let Svu: Float32 = inp.__getitem__(v,u)
                    rxy += Svu * mat.__getitem__(x)[u] * mat.__getitem__(y)[v]

            rxy *= 0.25
            rxy += 128
            outp.__setitem__(x,y,rxy)

fn store_data_unit_YCbCr(inout picture: picture_t, MCU: UInt32, component: UInt32, data_unit: UInt32, data: Array2D) raises:
    let zoomX = picture.Hmax // picture.components_data[component.to_int()].H
    let zoomY = picture.Vmax // picture.components_data[component.to_int()].V

    let scaleX = 8 * picture.components_data[component.to_int()].H
    let scaleY = 8 * picture.components_data[component.to_int()].V

    let startX = MCU % (ceil_to_multiple_of(picture.size_X, 8 * picture.Hmax) // (scaleX * zoomX))
    let startY = MCU // (ceil_to_multiple_of(picture.size_X, 8 * picture.Hmax) // (scaleY * zoomY))

    let startHiX = data_unit % picture.components_data[component.to_int()].H
    let startHiY = data_unit // picture.components_data[component.to_int()].H

    for x in range(8):
        for y in range(8):
            for zx in range(zoomX):
                for zy in range(zoomY):
                    let posX = (scaleX * startX + 8 * startHiX + x) * zoomX + zx
                    let posY = (scaleY * startY + 8 * startHiY + y) * zoomY + zy

                    if posX < picture.size_X and posY < picture.size_Y:
                        if component == 0:
                            picture.pixel_Y.__setitem__(posX.to_int(), posY.to_int(), data.__getitem__(x,y))
                        elif component == 1:
                            picture.pixel_Cb.__setitem__(posX.to_int(), posY.to_int(), data.__getitem__(x,y))
                        elif component == 2:
                            picture.pixel_Cr.__setitem__(posX.to_int(), posY.to_int(), data.__getitem__(x,y))
                        else:
                            raise Error("unknown component")

fn parse_bitmap_data(inout picture: picture_t , mat: Array2Dnew) raises:
    print("parsing bitstream...")

    var nb_bits:UInt32 = 0
    var component:UInt32 = 0
    var data_unit:UInt32 = 0
    let ac_count:UInt32 = 0

    var precedent_DC = Array1Dnew(4,0)

    precedent_DC.__setitem__(0,0)
    precedent_DC.__setitem__(1,0)
    precedent_DC.__setitem__(2,0)
    precedent_DC.__setitem__(3,0)

    var nb_MCU:UInt32 = 0

    var matrix = Array2D(8,8)

    for i in range(8):
        for j in range(8):
            matrix.__setitem__(i,j,0)
    while nb_MCU < picture.nb_MCU_total:
        component = 0
        while component < picture.nb_components:
            data_unit = 0
            while data_unit < (picture.components_data[component.to_int()].V * picture.components_data[component.to_int()].H):
                for u in range(8):
                    for v in range(8):
                        matrix.__setitem__(u,v,0)
                
                var SSSS:UInt8 = 0
                var DC:Int16 = 0
                let boo: Bool = bitstream_get_next_decoded_element(picture, 0, picture.components_data[component.to_int()].Td, SSSS, nb_bits)

                if not boo:
                     raise Error("no DC data")
                if SSSS != 0:
                    let bits_DC: UInt16 = bitstream_get_bits(picture, SSSS.cast[DType.uint32]())
                    bitstream_remove_bits(picture, SSSS.cast[DType.uint32]())
                    let msb_DC:UInt32 = (bits_DC.cast[DType.uint32]() & (1 << (SSSS.cast[DType.uint32]() - 1)).cast[DType.uint32]())
                    
                    if msb_DC > 0:
                        DC = precedent_DC.__getitem__(component.to_int()) + bits_DC.cast[DType.int16]()

                    else:
                        DC = (precedent_DC.__getitem__(component.to_int()) + convert_to_neg(bits_DC, SSSS))
                        
                else:
                    DC = (precedent_DC.__getitem__(component.to_int()) + 0)
                
                matrix.__setitem__(0,0,DC.cast[DType.float32] ())
                precedent_DC.__setitem__(component.to_int(),DC)

                var AC: Int16 = 0
                var ac_count: Int16 = 0
                while ac_count < 63:
                    var RRRRSSSS: UInt8 = 0
                    let boo: Bool = bitstream_get_next_decoded_element(picture, 1, picture.components_data[component.to_int()].Ta, RRRRSSSS, nb_bits)
                    if not boo:
                        raise Error("no DC data")
                    let RRRR: UInt8 = RRRRSSSS >> 4
                    SSSS = RRRRSSSS & 0x0f
                    if RRRR == 0 and SSSS == 0:
                        break
                    elif RRRR == 0x0F and SSSS == 0:
                        ac_count += 16
                    else:
                        ac_count += RRRR.cast[DType.int16]()

                        let bits_AC: UInt16 = bitstream_get_bits(picture, SSSS.cast[DType.uint32]())
                        bitstream_remove_bits(picture, SSSS.cast[DType.uint32]())

                        let msb_AC = (bits_AC & (1 << (SSSS - 1)).cast[DType.uint16]())
                        if msb_AC > 0:
                            AC = bits_AC.cast[DType.int16]()
                        else:
                            AC = convert_to_neg(bits_AC, SSSS)

                        let u = (ac_count + 1) // 8
                        let v = (ac_count + 1) % 8

                        matrix.__setitem__(u.to_int(),v.to_int(),AC.cast[DType.float32] ())
                        ac_count += 1

                var matrix_dequant = Array2D(8,8)
                for i in range(8):
                    for j in range(8):
                        matrix_dequant.__setitem__(i,j,0)
                
                reverse_ZZ_and_dequant(picture, picture.components_data[component.to_int()].Tq.cast[DType.uint8] (), matrix, matrix_dequant)

                var matrix_decoded = Array2D(8,8)
                for i in range(8):
                    for j in range(8):
                        matrix_decoded.__setitem__(i,j,0)
                
                data_unit_do_idct(matrix_dequant, matrix_decoded, mat)
                store_data_unit_YCbCr(picture, nb_MCU, component, data_unit, matrix_decoded)

                data_unit += 1
            component += 1
        nb_MCU += 1

    print("parsed MCU", nb_MCU)

fn parse_picture(inout picture: picture_t, comp_names: DynamicVector[String], mat: Array2Dnew) raises:
    while picture.pos_in_file <= picture.filesize - 1:
        let marker: UInt16
        marker = get_marker(picture.helpdata, picture.pos_in_file)
        picture.pos_in_file+=2
        print("marker:",marker)
        if marker == 0xFFD8:
            print("SOI found")
        elif marker == 0xFFE1:
            skip_EXIF(picture)
        elif marker == 0xFFE0:
            parse_APP0(picture)
        elif marker == 0xFFDB:
            parse_DQT(picture)
        elif marker == 0xFFC0:
            parse_SOF0(picture, comp_names)
        elif marker == 0xFFC4:
            parse_DHT(picture)
        elif marker == 0xFFDA:
            parse_SOS(picture, comp_names)
            copy_bitmap_data_remove_stuffing(picture)
            parse_bitmap_data(picture, mat)

        else:
            break

fn clamp(v: Float32) ->UInt8:
    if v < 0:
        return 0
    if v > 255:
        return 255
    return v.cast[DType.uint8] ()

fn write_ppm(inout picture: picture_t, filename:String) raises:
    print("writing file", filename)
    with open(filename, "w") as out:
        out.write("P3\n" + str(picture.size_X) + " " + str(picture.size_Y) + "\n255\n")
        for y in range(picture.size_Y):
            for x in range(picture.size_X):
                let Y = picture.pixel_Y.__getitem__(x,y)
                let Cb = picture.pixel_Cb.__getitem__(x,y)
                let Cr = picture.pixel_Cr.__getitem__(x,y)
                let r = Y + 1.402 * (Cr - 128)
                let g = Y - (0.114 * 1.772 * (Cb - 128) + 0.299 * 1.402 * (Cr - 128)) / 0.587
                let b = Y + 1.772 * (Cb - 128)
                out.write(str(clamp(math.round(r))) + " " + str(clamp(math.round(g))) + " " + str(clamp(math.round(b))) + " ")
            out.write("\n")
    
    print("output file written\n")

fn main() raises:

    let start_time = now()
    var comp_names =  DynamicVector[String] ()
    comp_names.push_back("Y")
    comp_names.push_back("Cb")
    comp_names.push_back("Cr")
    let data = DynamicVector[UInt8] ()
    let helpdata = DynamicVector[UInt16] ()
    let stringdata = ""
    let filesize = 0
    let pos_in_file = 0
    let size_X = 0
    let size_Y = 0
    let Hmax = 0
    let Vmax = 0
    let nb_MCU_total = 0
    let compressed_pixeldata = DynamicVector[Int] ()
    let sz_compressed_pixeldata = 0
    let pos_compressed_pixeldata = 0
    let bitpos_in_compressed_pixeldata = 0
    let nb_components = 0
    let components_data = DynamicVector[ComponentsData] ()
    let quant_table = Array3D(4,8,8)
    let pixel_Y = Array2D(1000,1000)
    let pixel_Cb = Array2D(1000,1000)
    let pixel_Cr = Array2D(1000,1000)
    let huff_tables1 = HuffmanTableArray(2)
    let huff_tables2 = HuffmanTableArray(2)

    let a_c : Float32 = 0.9807
    let b_c : Float32 = 0.8314
    let c_c : Float32 = 0.5555
    let d_c : Float32 = 0.1950
    let e_c : Float32 = 0.9238
    let f_c : Float32 = 0.3826
    let g_c : Float32 = 0.7071
    var mat = Array2Dnew(8)
    mat.__setitem__(0,SIMD[DType.float32, 8] (0.7071, a_c,  e_c,  b_c,  g_c,  c_c,  f_c,  d_c))
    mat.__setitem__(1,SIMD[DType.float32, 8] (0.7071, b_c,  f_c, -d_c, -g_c, -a_c, -e_c, -c_c))
    mat.__setitem__(2,SIMD[DType.float32, 8] (0.7071, c_c, -f_c, -a_c, -g_c,  d_c,  e_c,  b_c))
    mat.__setitem__(3,SIMD[DType.float32, 8] (0.7071, d_c, -e_c, -c_c,  g_c,  b_c, -f_c, -a_c))
    mat.__setitem__(4,SIMD[DType.float32, 8] (0.7071, -d_c, -e_c,  c_c,  g_c, -b_c, -f_c,  a_c))
    mat.__setitem__(5,SIMD[DType.float32, 8] (0.7071, -c_c, -f_c,  a_c, -g_c, -d_c,  e_c, -b_c))
    mat.__setitem__(6,SIMD[DType.float32, 8] (0.7071, -b_c,  f_c,  d_c, -g_c,  a_c, -e_c,  c_c))
    mat.__setitem__(7,SIMD[DType.float32, 8] (0.7071, -a_c,  e_c, -b_c,  g_c, -c_c,  f_c, -d_c))


    var pic = picture_t(data, helpdata, stringdata,filesize, pos_in_file, size_X, size_Y, Hmax, Vmax, nb_MCU_total, compressed_pixeldata, sz_compressed_pixeldata, pos_compressed_pixeldata, bitpos_in_compressed_pixeldata, nb_components, components_data, huff_tables1, huff_tables2, quant_table, pixel_Y, pixel_Cb, pixel_Cr)

    open_new_picture("../Example_images/test1.jpg", pic)
    parse_picture(pic, comp_names, mat)
    let end_time = now()
    let current_directory = path.cwd()
    write_ppm(pic, str(current_directory) + "/decodedimage.ppm")

    let write_time = now()

    let execution_time_algo : Float32 = end_time - start_time
    let execution_time_write : Float32 = write_time - end_time
    
    let execution_time_seconds_algo :  Float32 = execution_time_algo / 1000000000
    let execution_time_seconds_write :  Float32 = execution_time_write / 1000000000
    
    print("Time taken by the Jpeg decoder algorithm:", execution_time_seconds_algo, "seconds")
    print("Time taken for writing the image:", execution_time_seconds_write, "seconds")
