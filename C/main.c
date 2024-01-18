#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <math.h>
#include <err.h>
#include <time.h>


const char * comp_names[3]={"Y","Cb","Cr"};

typedef struct
{
	uint_fast8_t H;
	uint_fast8_t V;
	uint_fast8_t Tq;
	uint_fast16_t xi;
	uint_fast16_t yi;
	uint_fast8_t Td; //quant table for DC
	uint_fast8_t Ta; //quant table for AC
} components_data_t;

typedef struct
{
	uint_fast8_t sz;
	uint_fast16_t codeword;
	uint_fast8_t decoded;
} huffman_entry_t;

typedef struct
{
	uint_fast8_t nb_entries;
	huffman_entry_t entries[256];
} huffman_table_t;

typedef uint_fast8_t quantization_table_t[8][8];

typedef struct
{
	double Y;
	double Cb;
	double Cr;
} pixel_YCbCr_t;

typedef struct
{
	uint8_t * data;
	
	uint_fast32_t filesize;
	
	uint_fast32_t pos_in_file;	
	
	uint_fast16_t size_X;
	uint_fast16_t size_Y;
	
	uint_fast8_t Hmax;
	uint_fast8_t Vmax;
	
	uint_fast32_t nb_MCU_total;
	
	uint8_t * compressed_pixeldata;
	
	uint_fast32_t sz_compressed_pixeldata;
	
	uint_fast32_t pos_compressed_pixeldata;
	
	uint_fast32_t bitpos_in_compressed_pixeldata;

	uint_fast8_t nb_components;
	
	components_data_t components_data[4];
	
	huffman_table_t huff_tables[2][2]; //Tc (type=AC/DC), Th (destination identifier)
	
	quantization_table_t quant_tables[4];
	
	pixel_YCbCr_t ** pixels_YCbCr;
	
} picture_t;

typedef double matrix8x8_t[8][8];

uint8_t get1i(uint8_t const * const data, uint_fast32_t * const pos)
{
	uint8_t val=data[*pos];
	(*pos)++;
	return val;
}

uint16_t get2i(uint8_t const * const data, uint_fast32_t * const pos)
{
	uint16_t val=(data[*pos]<<8)|data[(*pos)+1];
	(*pos)+=2;
	return val;
}

uint32_t get4i(uint8_t const * const data, uint_fast32_t * const pos)
{
	uint32_t val=(data[*pos]<<24)|(data[(*pos)+1]<<16)|(data[(*pos)+2]<<8)|(data[(*pos)+3]);
	(*pos)+=4;
	return val;
}

uint16_t get_marker(uint8_t const * const data, uint_fast32_t * const pos)
{
	return get2i(data, pos);
}


char *to_bin(const uint16_t word, const uint8_t sz)
{
	static char str[17];
	memset(str, '\0', 17);
	
	uint8_t i;
	for(i=0; i<sz; i++)
		str[i]='0'+!!(word&(1<<(sz-i-1)));
	
	return str;
}


uint_fast32_t ceil_to_multiple_of(const uint_fast32_t val, const uint_fast32_t multiple)
{
	return (uint_fast32_t)(multiple*ceil((double)val/multiple));
}

void skip_EXIF(picture_t * const pic)
{
	uint16_t len=get2i(pic->data, &(pic->pos_in_file));
	printf("APP1 (probably EXIF) found (length %u bytes), skipping\n", len);
	pic->pos_in_file+=len-2;
}

void parse_APP0(picture_t * const pic)
{
    uint16_t len = get2i(pic->data, &(pic->pos_in_file));
    printf("APP0 found (length %u bytes)\n", len);
    if (len < 16)
        errx(1, "APP0: too short");
    
    uint8_t identifier[5];
    memcpy(identifier, &pic->data[pic->pos_in_file], 5);
    pic->pos_in_file += 5;

    uint_fast8_t version_major = get1i(pic->data, &(pic->pos_in_file));
    uint_fast8_t version_minor = get1i(pic->data, &(pic->pos_in_file));
    uint_fast8_t units = get1i(pic->data, &(pic->pos_in_file));
    uint_fast16_t Xdensity = get2i(pic->data, &(pic->pos_in_file));
    uint_fast16_t Ydensity = get2i(pic->data, &(pic->pos_in_file));
    uint_fast16_t Xthumbnail = get1i(pic->data, &(pic->pos_in_file));
    uint_fast16_t Ythumbnail = get1i(pic->data, &(pic->pos_in_file));
        
    if (memcmp(identifier, "JFIF\x00", 5))
        errx(1, "APP0: invalid identifier");
    
    printf("version %u.%u\n", version_major, version_minor);
    printf("units %u\n", units);
    printf("density X %lu Y %lu\n", Xdensity, Ydensity);
        
    uint_fast32_t bytes_thumbnail = 3 * Xthumbnail * Ythumbnail;
    
    if (bytes_thumbnail)
    {
        printf("thumbnail %lu bytes, skipping\n", bytes_thumbnail);
        pic->pos_in_file += bytes_thumbnail;
    }
    else
        printf("no thumbnail\n");
	printf("parse_APP0 at end get2i pic->pos_in_file: %lu\n", (unsigned long)pic->pos_in_file);
}

void parse_DQT(picture_t * const pic)
{
	uint16_t Lq=get2i(pic->data, &(pic->pos_in_file));
	printf("DQT found (length %u bytes)\n", Lq);
	
	uint8_t PqTq=get1i(pic->data, &(pic->pos_in_file));
	uint8_t Pq=(PqTq>>4)&0x0f;
	uint8_t Tq=PqTq&0x0f;
	printf("Pq (element precision) %u -> %u bits\n", Pq, (Pq==0)?8:16);
	printf("Tq (table destination identifier) %u\n", Tq);
	
	if(Pq!=0)
		errx(1, "DQT: only 8 bit precision supported");
	
	uint16_t nb_data_bytes=Lq-2-1;
	
	if(nb_data_bytes!=64)
		errx(1, "DQT: nb_data_bytes!=64");

	uint8_t u,v;
	for(u=0; u<8; u++)
	{
		for(v=0; v<8; v++)
		{
			uint8_t Q=get1i(pic->data, &(pic->pos_in_file));
			pic->quant_tables[Tq][u][v]=Q;
		}
	}
	printf("\n");
}

void parse_SOF0(picture_t * const pic)
{
	uint16_t len=get2i(pic->data, &(pic->pos_in_file));
	printf("SOF0 found (length %u bytes)\n", len);
	
	uint_fast8_t P=get1i(pic->data, &(pic->pos_in_file));
	uint_fast16_t Y=get2i(pic->data, &(pic->pos_in_file));
	uint_fast16_t X=get2i(pic->data, &(pic->pos_in_file));
	uint_fast8_t Nf=get1i(pic->data, &(pic->pos_in_file));
	
	if(P!=8)
		errx(1, "SOF0: P!=8 unsupported");
	
	if(Y==0)
		errx(1, "SOF0: Y==0 unsupported");
	
	printf("P %u (must be 8)\n", P);
	printf("imagesize X %lu Y %lu\n", X, Y);
	printf("Nf (number of components) %u\n", Nf);
	
	if(Nf!=3)
		errx(1, "picture does not have 3 components, this code will not work");
	
	pic->size_X=X;
	pic->size_Y=Y;
	
	uint_fast8_t i;
	for(i=0; i<Nf; i++)
	{
		uint8_t C=get1i(pic->data, &(pic->pos_in_file));
		uint8_t HV=get1i(pic->data, &(pic->pos_in_file));
		uint8_t H=(HV>>4)&0x0f;
		uint8_t V=HV&0x0f;
		uint8_t Tq=get1i(pic->data, &(pic->pos_in_file));
		
		pic->components_data[i].H=H;
		pic->components_data[i].V=V;
		pic->components_data[i].Tq=Tq;
		
		printf("component %u (%s) C %u, H %u, V %u, Tq %u\n", i, comp_names[i], C, H, V, Tq);
	}
	
	pic->nb_components=Nf;
	
	uint_fast8_t Hmax=0,Vmax=0;

	for(i=0; i<pic->nb_components; i++)
	{
		if(pic->components_data[i].H>Hmax)
			Hmax=pic->components_data[i].H;
		if(pic->components_data[i].V>Vmax)
			Vmax=pic->components_data[i].V;
	}
	
	pic->Hmax=Hmax;
	pic->Vmax=Vmax;
	
	pic->nb_MCU_total=(ceil_to_multiple_of(pic->size_X, 8*Hmax)/(8*Hmax))*(ceil_to_multiple_of(pic->size_Y, 8*Hmax)/(8*Vmax));
	
	printf("Hmax %u Vmax %u\n", Hmax, Vmax);
	printf("MCU_total %lu\n", pic->nb_MCU_total);
	
	uint16_t xi,yi;
	for(i=0; i<pic->nb_components; i++)
	{
		xi=(uint16_t)ceil((double)pic->size_X*pic->components_data[i].H/Hmax);
		yi=(uint16_t)ceil((double)pic->size_Y*pic->components_data[i].V/Vmax);
		
		pic->components_data[i].xi=xi;
		pic->components_data[i].yi=yi;
		
		printf("component %u (%s) xi %u yi %u\n", i, comp_names[i], xi, yi);
	}
	
	printf("allocating memory for pixels\n");
	
	uint_fast16_t x,y;
	pic->pixels_YCbCr=malloc(pic->size_X*sizeof(pixel_YCbCr_t*));
	for(x=0; x<pic->size_X; x++)
		pic->pixels_YCbCr[x]=malloc(pic->size_Y*sizeof(pixel_YCbCr_t));
	
	for(x=0; x<pic->size_X; x++)
	{
		for(y=0; y<pic->size_Y; y++)
		{
			pic->pixels_YCbCr[x][y].Y=0;
			pic->pixels_YCbCr[x][y].Cb=0;
			pic->pixels_YCbCr[x][y].Cr=0;
		}
	}
	printf("memory allocated\n");
}

void parse_DHT(picture_t * const pic)
{
	uint16_t len=get2i(pic->data, &(pic->pos_in_file));
	printf("DHT found (length %u bytes)\n", len);
	
	uint8_t TcTh=get1i(pic->data, &(pic->pos_in_file));
	uint8_t Tc=(TcTh>>4)&0x0f;
	uint8_t Th=TcTh&0x0f;
	
	printf("Tc %u (%s table)\n", Tc, (Tc==0)?"DC":"AC");
	printf("Th (table destination identifier) %u\n", Th);
	
	uint8_t L[16];
	uint8_t mt=0;
	uint8_t i;
	for(i=0; i<16; i++)
	{
		L[i]=get1i(pic->data, &(pic->pos_in_file));
		mt+=L[i];
	}
	
	printf("total %u codes\n", mt);

	uint16_t codeword=0;
	
	for(i=0; i<16; i++)
	{
		uint8_t j;
		for(j=0; j<L[i]; j++)
		{
			uint8_t V=get1i(pic->data, &(pic->pos_in_file));

			pic->huff_tables[Tc][Th].entries[pic->huff_tables[Tc][Th].nb_entries].sz=i+1;
			pic->huff_tables[Tc][Th].entries[pic->huff_tables[Tc][Th].nb_entries].codeword=codeword;
			pic->huff_tables[Tc][Th].entries[pic->huff_tables[Tc][Th].nb_entries].decoded=V;
			pic->huff_tables[Tc][Th].nb_entries++;
			
			codeword++;
		}
		codeword<<=1;
	}
}

void parse_SOS(picture_t * const pic)
{
	uint16_t len=get2i(pic->data, &(pic->pos_in_file)); //without actual bitmap data
	printf("SOS found (length %u bytes)\n", len);
	
	uint8_t Ns=get1i(pic->data, &(pic->pos_in_file));
	printf("Ns %u\n", Ns);
	
	uint8_t j;
	for(j=0; j<Ns; j++)
	{
		uint8_t Cs=get1i(pic->data, &(pic->pos_in_file));
		uint8_t TdTa=get1i(pic->data, &(pic->pos_in_file));
		uint8_t Td=(TdTa>>4)&0x0f;
		uint8_t Ta=TdTa&0x0f;
		
		printf("component %u (%s) Cs %u Td %u Ta %u\n", j, comp_names[j], Cs, Td, Ta);
		pic->components_data[j].Td=Td; //DC
		pic->components_data[j].Ta=Ta; //AC
	}
	
	uint8_t Ss=get1i(pic->data, &(pic->pos_in_file));
	uint8_t Se=get1i(pic->data, &(pic->pos_in_file));
	uint8_t AhAl=get1i(pic->data, &(pic->pos_in_file));
	uint8_t Ah=(AhAl>>4)&0x0f;
	uint8_t Al=AhAl&0x0f;
	
	printf("Ss %u Se %u Ah %u Al %u\n", Ss, Se, Ah, Al);
	
	pic->pos_compressed_pixeldata=pic->pos_in_file;
	
	printf("compressed pixeldata starts at pos %lu\n\n", pic->pos_compressed_pixeldata);
}

void copy_bitmap_data_remove_stuffing(picture_t * const pic)
{
	printf("removing stuffing...\n");
	
	//get length of bitstream without stuffing
	
	uint_fast32_t pos=pic->pos_compressed_pixeldata;
	uint_fast32_t size=0;
	uint8_t byte;
	uint16_t combined=0;
	
	do
	{
		if(pos>=pic->filesize)
			errx(1, "marker EOI (0xFFD9) missing");
		
		byte=pic->data[pos++];
		if(byte==0xFF)
		{
			uint8_t byte2=pic->data[pos++];
			if(byte2!=0x00)
				combined=(byte<<8)|byte2;
			else
				size++;
		}
		else
			size++;
	} while(combined!=0xFFD9);
	
	uint_fast32_t size_stuffed=pos-pic->pos_compressed_pixeldata-2;
	
	//remove stuffing
	
	pic->compressed_pixeldata=malloc(size*sizeof(uint8_t));
	if(!pic->compressed_pixeldata)
		err(1, "malloc");
	
	printf("%lu bytes with stuffing\n", size_stuffed);
	
	uint_fast32_t i;
	uint_fast32_t size_without_stuffing;
	
	for(i=pic->pos_compressed_pixeldata, pos=0, size_without_stuffing=0; i<(pic->pos_compressed_pixeldata+size_stuffed); )
	{
		if(pic->data[i]!=0xFF)
		{
			pic->compressed_pixeldata[pos++]=pic->data[i++];
			size_without_stuffing++;
		}
		else if(pic->data[i]==0xFF && pic->data[i+1]==0x00)
		{
			pic->compressed_pixeldata[pos++]=0xFF;
			size_without_stuffing++;
			i+=2;
		}
		else
			errx(1, "unexpected marker 0x%02x%02x found in bitstream", pic->data[i], pic->data[i+1]);
	}
	
	pic->bitpos_in_compressed_pixeldata=0;
	pic->sz_compressed_pixeldata=size_without_stuffing;
	pic->pos_in_file=pic->pos_compressed_pixeldata+size_stuffed;
	
	printf("%lu data bytes without stuffing\n\n", size_without_stuffing);
}

int16_t convert_to_neg(uint16_t bits, const uint8_t sz)
{
	int16_t ret=-((bits^0xFFFF)&((1<<sz)-1));
	return ret;
}


uint16_t bitstream_get_bits(picture_t * const pic, const uint_fast8_t nb_bits)
{
	if(nb_bits>16)
		errx(1, "bitstream_get_bits: >16 bits requested");
	
	uint_fast32_t index=pic->bitpos_in_compressed_pixeldata/8;
	int_fast8_t pos_in_byte=(7-pic->bitpos_in_compressed_pixeldata%8);
	uint16_t ret=0;
	uint_fast8_t bits_copied=0;
	
	while(pos_in_byte>=0 && bits_copied<nb_bits)
	{
		ret<<=1;
		ret|=!!(pic->compressed_pixeldata[index]&(1<<pos_in_byte));
		bits_copied++;
		pos_in_byte--;
		if(pos_in_byte<0)
		{
			pos_in_byte=7;
			index++;
		}
	}
	
	return ret;	
}

void bitstream_remove_bits(picture_t * const pic, const uint_fast8_t nb_bits)
{
	pic->bitpos_in_compressed_pixeldata+=nb_bits;
}


bool huff_decode(picture_t * const pic, const uint8_t Tc, const uint8_t Th, const uint8_t sz, const uint16_t bitstream, uint8_t * const decoded)
{
	uint32_t i;
	for(i=0; i<pic->huff_tables[Tc][Th].nb_entries; i++)
	{
		if(pic->huff_tables[Tc][Th].entries[i].sz==sz && pic->huff_tables[Tc][Th].entries[i].codeword==bitstream)
		{
			(*decoded)=pic->huff_tables[Tc][Th].entries[i].decoded;
			return true;
		}
	}
	
	return false;
}


bool bitstream_get_next_decoded_element(picture_t * const pic, const uint8_t Tc, const uint8_t Th, uint8_t * const decoded, uint_fast8_t * const nb_bits)
{
	uint16_t huff_candidate;
	bool found;
	
	while(pic->bitpos_in_compressed_pixeldata<8*pic->sz_compressed_pixeldata)
	{
		found=false;
		for(*nb_bits=1; *nb_bits<=16; (*nb_bits)++)
		{
			if((pic->bitpos_in_compressed_pixeldata+*nb_bits)>8*pic->sz_compressed_pixeldata)
				errx(1, "end of stream, requested to many bits");
			
			huff_candidate=bitstream_get_bits(pic, *nb_bits);
			if(huff_decode(pic, Tc, Th, *nb_bits, huff_candidate, decoded))
			{
				found=true;
				bitstream_remove_bits(pic, *nb_bits);

				return true;
			}
		}
		if(!found)
		{
			//check if it's padding, else error
			bool is_all_one=true;
			uint_fast8_t i;
			for(i=0; i<(*nb_bits)-1; i++)
			{
				if((huff_candidate&(1<<i))==0)
				{
					is_all_one=false;
					break;
				}
			}
			
			if(is_all_one) //padding
				bitstream_remove_bits(pic, *nb_bits);
			else
				errx(1, "unknown code in bitstream bitpos %lu byte 0x%x [prev 0x%x, next 0x%x]", pic->bitpos_in_compressed_pixeldata, pic->compressed_pixeldata[pic->bitpos_in_compressed_pixeldata/8], pic->compressed_pixeldata[(pic->bitpos_in_compressed_pixeldata/8)-1], pic->compressed_pixeldata[(pic->bitpos_in_compressed_pixeldata/8)+1]);
		}
	}

	return false;
}


void store_data_unit_YCbCr(picture_t * const pic, const uint_fast32_t MCU, const uint_fast8_t component, const uint_fast8_t data_unit, const matrix8x8_t data)
{
	uint_fast8_t zoomX, zoomY;
	
	zoomX=pic->Hmax/pic->components_data[component].H;
	zoomY=pic->Vmax/pic->components_data[component].V;
	
	uint_fast8_t scaleX, scaleY;
	
	scaleX=8*pic->components_data[component].H;
	scaleY=8*pic->components_data[component].V;
	
	uint_fast16_t startX, startY;
	
	startX=MCU%(ceil_to_multiple_of(pic->size_X, 8*pic->Hmax)/(scaleX*zoomX));
	startY=MCU/(ceil_to_multiple_of(pic->size_X, 8*pic->Hmax)/(scaleY*zoomY)); //yes, size_X and H!
	
	uint_fast16_t startHiX=data_unit%pic->components_data[component].H;
	uint_fast16_t startHiY=data_unit/pic->components_data[component].H; //yes, H!
	
	uint_fast8_t x,y;
	uint_fast8_t zx,zy;
	
	uint_fast32_t posX, posY;
	
	for(x=0; x<8; x++)
	{
		for(y=0; y<8; y++)
		{
			for(zx=0; zx<zoomX; zx++)
			{
				for(zy=0; zy<zoomY; zy++)
				{
					posX=(scaleX*startX+8*startHiX+x)*zoomX+zx;
					posY=(scaleY*startY+8*startHiY+y)*zoomY+zy;
					
					if(posX<pic->size_X && posY<pic->size_Y)
					{			
						switch(component)
						{
							case 0: pic->pixels_YCbCr[posX][posY].Y=data[x][y]; break;
							case 1: pic->pixels_YCbCr[posX][posY].Cb=data[x][y]; break;
							case 2: pic->pixels_YCbCr[posX][posY].Cr=data[x][y]; break;
							default: errx(1, "unknown component"); break;
						}
					}
				}
			}
		}
	}
}


void reverse_ZZ_and_dequant(picture_t const * const pic, const uint8_t quant_table, const matrix8x8_t inp, matrix8x8_t outp)
{
	const uint_fast8_t reverse_ZZ_u[8][8]={	{0, 0, 1, 2, 1, 0, 0, 1 },
											{2, 3, 4, 3, 2, 1, 0, 0 },
											{1, 2, 3, 4, 5, 6, 5, 4 },
											{3, 2, 1, 0, 0, 1, 2, 3 },
											{4, 5, 6, 7, 7, 6, 5, 4 },
											{3, 2, 1, 2, 3, 4, 5, 6 },
											{7, 7, 6, 5, 4, 3, 4, 5 },
											{6, 7, 7, 6, 5, 6, 7, 7 }	};
										
	const uint_fast8_t reverse_ZZ_v[8][8]={	{0, 1, 0, 0, 1, 2, 3, 2 },
											{1, 0, 0, 1, 2, 3, 4, 5 },
											{4, 3, 2, 1, 0, 0, 1, 2 },
											{3, 4, 5, 6, 7, 6, 5, 4 },
											{3, 2, 1, 0, 1, 2, 3, 4 },
											{5, 6, 7, 7, 6, 5, 4, 3 },
											{2, 3, 4, 5, 6, 7, 7, 6 },
											{5, 4, 5, 6, 7, 7, 6, 7 }	};
	
	uint_fast8_t u,v;
	
	for(u=0; u<8; u++)
		for(v=0; v<8; v++)
			outp[reverse_ZZ_u[u][v]][reverse_ZZ_v[u][v]]=inp[u][v]*pic->quant_tables[quant_table][u][v];
}

#define a_c 0.9807
#define b_c 0.8314
#define c_c 0.5555
#define d_c 0.1950
#define e_c 0.9238
#define f_c 0.3826
#define g_c 0.7071


static float tab_coefs[8][8] = {{0.7071,  a_c,  e_c,  b_c,  g_c,  c_c,  f_c,  d_c},
                                {0.7071,  b_c,  f_c, -d_c, -g_c, -a_c, -e_c, -c_c},
                                {0.7071,  c_c, -f_c, -a_c, -g_c,  d_c,  e_c,  b_c},
                                {0.7071,  d_c, -e_c, -c_c,  g_c,  b_c, -f_c, -a_c},
                                {0.7071, -d_c, -e_c,  c_c,  g_c, -b_c, -f_c,  a_c},
                                {0.7071, -c_c, -f_c,  a_c, -g_c, -d_c,  e_c, -b_c},
                                {0.7071, -b_c,  f_c,  d_c, -g_c,  a_c, -e_c,  c_c},
                                {0.7071, -a_c,  e_c, -b_c,  g_c, -c_c,  f_c, -d_c}};


void data_unit_do_idct(const matrix8x8_t inp, matrix8x8_t outp)
{
    double rxy=0;
  
    uint_fast8_t x, y;
    uint_fast8_t u, v;
        
    for(y=0; y<8; y++)
    {
        for(x=0; x<8; x++)
        {
        rxy=0;

        for(u=0; u<=7; u++)
        {
            for(v=0; v<=7; v++)
            {
            double Svu=inp[v][u];

            rxy+= Svu*tab_coefs[x][u]*tab_coefs[y][v];
            }
        }
                
        rxy*=0.25;
        rxy+=128;

        outp[x][y]=rxy;
        }
    }
}

void print_matrix(matrix8x8_t m)
{
	for(int u = 0; u < 8; u++) {
		for(int v = 0; v < 8; v++) {
			printf("%5f ", m[u][v]);
		}
		printf("\n");
	}
	printf("\n");
}

void parse_bitmap_data(picture_t * const pic)
{
	printf("parsing bitstream...\n");
	
	uint_fast8_t nb_bits;
	uint_fast8_t component=0; //Cs
	uint_fast8_t data_unit;
	uint_fast8_t u,v;
	uint_fast8_t ac_count;
	
	int16_t precedent_DC[4]={0,0,0,0};
	
	uint_fast32_t nb_MCU=0;

	matrix8x8_t matrix;
	
	for(nb_MCU=0; nb_MCU<pic->nb_MCU_total; nb_MCU++)
	{
		for(component=0; component<pic->nb_components; component++)
		{
			for(data_unit=0; data_unit<(pic->components_data[component].V*pic->components_data[component].H); data_unit++)
			{

				for(u=0; u<8; u++)
					for(v=0; v<8; v++)
						matrix[u][v]=0;
				
				uint8_t SSSS;
				int16_t DC;
				if(!bitstream_get_next_decoded_element(pic, 0, pic->components_data[component].Td, &SSSS, &nb_bits))
					errx(1, "no DC data");
				if(SSSS)
				{
					uint16_t bits_DC=bitstream_get_bits(pic, SSSS);
					bitstream_remove_bits(pic, SSSS);
					
					bool msb_DC=!!(bits_DC&(1<<(SSSS-1)));
					
					if(msb_DC)
						DC=precedent_DC[component]+bits_DC;
					else
						DC=precedent_DC[component]+convert_to_neg(bits_DC,SSSS);
					
				}
				else
					DC=precedent_DC[component]+0;
				
				matrix[0][0]=DC;
				precedent_DC[component]=DC;

				int16_t AC;
				for(ac_count=0; ac_count<63; )
				{
					uint8_t RRRRSSSS;
					if(!bitstream_get_next_decoded_element(pic, 1, pic->components_data[component].Ta, &RRRRSSSS, &nb_bits))
						errx(1, "no AC data");
					
					uint8_t RRRR=(RRRRSSSS>>4); //number of preceding 0 samples
					uint8_t SSSS=RRRRSSSS&0x0f; //category
					
					if(RRRR==0 && SSSS==0)
					{

						break;
					}
					else if(RRRR==0x0F && SSSS==0)
					{
						ac_count+=16;

					}
					else
					{
						ac_count+=RRRR;
						
						uint16_t bits_AC=bitstream_get_bits(pic, SSSS);
						bitstream_remove_bits(pic, SSSS);
						
						bool msb_AC=!!(bits_AC&(1<<(SSSS-1)));
						
						if(msb_AC)
							AC=bits_AC;
						else
							AC=convert_to_neg(bits_AC,SSSS);
						
						u=(ac_count+1)/8;
						v=(ac_count+1)%8;
						matrix[u][v]=AC;
						ac_count++;

					}
				}

				matrix8x8_t matrix_dequant;

				reverse_ZZ_and_dequant(pic, pic->components_data[component].Tq, matrix, matrix_dequant);
				matrix8x8_t matrix_decoded;

				data_unit_do_idct(matrix_dequant, matrix_decoded);
				store_data_unit_YCbCr(pic, nb_MCU, component, data_unit, matrix_decoded);
			}
		}
	}
	printf("parsed %lu MCU\n", nb_MCU);
}


void open_new_picture(char const * const name, picture_t * const picture)
{
	FILE *f=fopen(name, "rb");
	if(!f)
		err(1, "fopen %s failed", name);
	
	fseek(f, 0, SEEK_END);
	picture->filesize=ftell(f);
	fseek(f, 0, SEEK_SET);
	
	picture->data=malloc(picture->filesize*sizeof(uint8_t));
	if(!picture->data)
		err(1, "malloc for %s failed", name);
		
	if(fread(picture->data, picture->filesize, 1, f)!=1)
		err(1, "fread for %s failed", name);
		
	fclose(f);
	
	printf("%lu bytes read from %s\n\n", picture->filesize, name);
	
	picture->pos_in_file=0;
	
	picture->nb_components=0;
	
	picture->huff_tables[0][0].nb_entries=0;
	picture->huff_tables[0][1].nb_entries=0;
	picture->huff_tables[1][0].nb_entries=0;
	picture->huff_tables[1][1].nb_entries=0;
}

void parse_picture(picture_t * const picture)
{
	while(picture->pos_in_file<=picture->filesize-2)
	{
		uint16_t marker;
		
		marker=get_marker(picture->data, &(picture->pos_in_file));
		printf("marker: %d\n",marker);
		
		switch(marker)
		{
			case 0xFFD8:	printf("SOI found\n"); break;
			
			case 0xFFE1:	skip_EXIF(picture); break;
			
			case 0xFFE0:	parse_APP0(picture); break;
			case 0xFFDB:	parse_DQT(picture); break;
			case 0xFFC0:	parse_SOF0(picture); break;
			case 0xFFC4:	parse_DHT(picture); break;
			case 0xFFDA:	parse_SOS(picture);
							copy_bitmap_data_remove_stuffing(picture);
							parse_bitmap_data(picture);
							break;
			
			case 0xFFD9:	printf("EOI found\n"); break;
			
			default: errx(1, "unknown marker 0x%04x pos %lu", marker, picture->pos_in_file); break;
		}
		printf("\n");
	}
}

uint8_t clamp(const double v)
{
	if(v<0)
		return 0;
	if(v>255)
		return 255;
	
	return (uint8_t)v;
}

void write_ppm(picture_t const * const pic, char const * const filename)
{
	uint_fast16_t x,y;
	
	double Y,Cb,Cr;
	double r,g,b;
	
	FILE *out=fopen(filename, "w");
	
	printf("writing file %s\n", filename);
	
	fprintf(out, "P3\n%lu %lu\n255\n", pic->size_X, pic->size_Y);
		
	for(y=0; y<pic->size_Y; y++)
	{
		for(x=0; x<pic->size_X; x++)
		{
			Y=pic->pixels_YCbCr[x][y].Y;
			Cb=pic->pixels_YCbCr[x][y].Cb;
			Cr=pic->pixels_YCbCr[x][y].Cr;
			
			r=Y+1.402*(Cr-128);
			g=Y-(0.114*1.772*(Cb-128)+0.299*1.402*(Cr-128))/0.587;
			b=Y+1.772*(Cb-128);
			
			fprintf(out, "%u %u %u ", clamp(round(r)),clamp(round(g)),clamp(round(b)));
		}
		fprintf(out, "\n");
	}
	fclose(out);
	printf("output file written\n\n");
}


int main(int argc, char *argv[])
{

	if (argc != 2) {
        printf("Usage: %s <filename.jpg>\n", argv[0]);
        return 1;
    }

	clock_t start_time, end_time, write_time;
    double cpu_time_used_algo, cpu_time_used_write;
	start_time = clock();
	picture_t pic;
	open_new_picture(argv[1], &pic);
	parse_picture(&pic);
	end_time = clock();
	write_ppm(&pic, "decodedimage.ppm");
	write_time = clock();
    cpu_time_used_algo = ((double) (end_time - start_time)) / CLOCKS_PER_SEC;
	cpu_time_used_write = ((double) (write_time - end_time)) / CLOCKS_PER_SEC;
    printf("Time taken by the Jpeg decoder algorithm: %f seconds\n", cpu_time_used_algo);
	printf("Time taken for writing the image: %f seconds\n", cpu_time_used_write);
}