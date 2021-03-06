/*
 * Basic window sizes.  These probably belong somewhere more globally
 * useful.
 */

#define GC0329_ID  0xc0

#define VGA_WIDTH	640
#define VGA_HEIGHT	480
#define QVGA_WIDTH	320
#define QVGA_HEIGHT	240
#define QCIF_WIDTH	176
#define	QCIF_HEIGHT	144

/*
 * Our nominal (default) frame rate.
 */

#define GC0329_FRAME_RATE 7	//15

/* Registers */
#define GC0329_I2C_ADDR 0x62
#define COM7_FMT_VGA 0x00
#define REG_COM7	0xfe	/* Reset related */
#define COM7_RESET	  0x80	/* Register reset */
#define REG_PID		0x00	/* Product ID */
#define REG_BRIGHT	0x13	/* Brightness */

/* Information we maintain about a known sensor.*/

struct gc0329_format_struct;	/* coming later */
struct gc0329_info {
	struct gc0329_format_struct *fmt;	/* Current format */
	unsigned char sat;	/* Saturation value */
	int hue;		/* Hue value */
};

struct regval_list {
	unsigned char reg_num;
	unsigned char value;
};

/*The default register settings, as obtained from Micron.*/

static struct regval_list gc0329_init_regs[] = {
	{0xfe, 0x80},
	{0xfe, 0x80},
	{0xfc, 0x16},
	{0xfc, 0x16},
	{0xfc, 0x16},
	{0xfc, 0x16},
	{0xfe, 0x00},
	{0xf0, 0x07},
	{0xf1, 0x01},

	{0x73, 0x90},
	{0x74, 0x80},
	{0x75, 0x80},
	{0x76, 0x94},

	{0x42, 0x00},
	{0x77, 0x57},
	{0x78, 0x4d},
	{0x79, 0x45},
	//{0x42, 0xfc},

	////////////////////analog////////////////////
	{0x0a, 0x02},
	{0x0c, 0x02},
	{0x17, 0x14},		//++++++++++++++++++++++++++++++++++++++++++++++++++++
	{0x19, 0x05},
	{0x1b, 0x24},
	{0x1c, 0x04},
	{0x1e, 0x08},
	{0x1f, 0xc0},		//Analog_mode2//[7:6] comv_r
	{0x20, 0x00},
	{0x21, 0x48},
	{0x22, 0xba},
	{0x23, 0x22},
	{0x24, 0x17},

	////////////////////blk////////////////////
	{0x26, 0xf7},
	{0x29, 0x80},
	{0x32, 0x04},
	{0x33, 0x20},
	{0x34, 0x20},
	{0x35, 0x20},
	{0x36, 0x20},

	////////////////////ISP BLOCK ENABL////////////////////
	{0x40, 0xff},
	{0x41, 0x44},
	{0x42, 0x7e},
	{0x44, 0xa2},
	{0x46, 0x02},
	{0x4b, 0xca},
	{0x4d, 0x01},
	{0x4f, 0x01},
	{0x70, 0x48},

	//{0xb0, 0x00},
	//{0xbc, 0x00},
	//{0xbd, 0x00},
	//{0xbe, 0x00},
	////////////////////DNDD////////////////////
	{0x80, 0xe7},
	{0x82, 0x55},
	{0x83, 0x03},
	{0x87, 0x4a},

	////////////////////INTPEE////////////////////
	{0x95, 0x45},

	////////////////////ASDE////////////////////
	//{0xfe, 0x01},
	//{0x18, 0x22},
	//{0xfe, 0x00);
	//{0x9c, 0x0a},
	//{0xa0, 0xaf},
	//{0xa2, 0xff},
	//{0xa4, 0x50},
	//{0xa5, 0x21},
	//{0xa7, 0x35},

	////////////////////RGB gamma////////////////////
	//RGB gamma m4'
	/*{0xbf, 0x06},
	   {0xc0, 0x14},
	   {0xc1, 0x27},
	   {0xc2, 0x3b},
	   {0xc3, 0x4f},
	   {0xc4, 0x62},
	   {0xc5, 0x72},
	   {0xc6, 0x8d},
	   {0xc7, 0xa4},
	   {0xc8, 0xb8},
	   {0xc9, 0xc9},
	   {0xcA, 0xd6},
	   {0xcB, 0xe0},
	   {0xcC, 0xe8},
	   {0xcD, 0xf4},
	   {0xcE, 0xFc},
	   {0xcF, 0xFF},
	 */

	{0xBF, 0x0E},		//case GC0329_RGB_Gamma_m4:
	{0xc0, 0x1C},
	{0xc1, 0x34},
	{0xc2, 0x48},
	{0xc3, 0x5A},
	{0xc4, 0x6B},
	{0xc5, 0x7B},
	{0xc6, 0x95},
	{0xc7, 0xAB},
	{0xc8, 0xBF},
	{0xc9, 0xCE},
	{0xcA, 0xD9},
	{0xcB, 0xE4},
	{0xcC, 0xEC},
	{0xcD, 0xF7},
	{0xcE, 0xFD},
	{0xcF, 0xFF},

	/*{0xBF, 0x10},//case GC0329_RGB_Gamma_m5:
	   {0xc0, 0x20},
	   {0xc1, 0x38},
	   {0xc2, 0x4E},
	   {0xc3, 0x63},
	   {0xc4, 0x76},
	   {0xc5, 0x87},
	   {0xc6, 0xA2},
	   {0xc7, 0xB8},
	   {0xc8, 0xCA},
	   {0xc9, 0xD8},
	   {0xcA, 0xE3},
	   {0xcB, 0xEB},
	   {0xcC, 0xF0},
	   {0xcD, 0xF8},
	   {0xcE, 0xFD},
	   {0xcF, 0xFF},
	 */
	//////////////////CC///////////////////
	{0xfe, 0x00},

	{0xb3, 0x44},
	{0xb4, 0xfd},
	{0xb5, 0x02},
	{0xb6, 0xfa},
	{0xb7, 0x48},
	{0xb8, 0xf0},

	// crop
	{0x50, 0x01},

	////////////////////YCP////////////////////
	{0xfe, 0x00},
	{0xd1, 0x38},
	{0xd2, 0x38},
	{0xdd, 0x54},

	////////////////////AEC////////////////////
	{0xfe, 0x01},
	{0x10, 0x40},
	{0x11, 0x21},		//a1
	{0x12, 0x07},
	{0x13, 0x50},		//Y target
	{0x17, 0x88},
	{0x21, 0xb0},
	{0x22, 0x48},
	{0x3c, 0x95},
	{0x3d, 0x50},
	{0x3e, 0x48},

	////////////////////AWB////////////////////
	{0xfe, 0x01},
	{0x06, 0x16},
	{0x07, 0x06},
	{0x08, 0x98},
	{0x09, 0xee},
	{0x50, 0xfc},
	{0x51, 0x20},
	{0x52, 0x0b},
	{0x53, 0x20},
	{0x54, 0x40},
	{0x55, 0x10},
	{0x56, 0x20},
	//{0x57, 0x40},
	{0x58, 0xa0},
	{0x59, 0x28},
	{0x5a, 0x02},
	{0x5b, 0x63},
	{0x5c, 0x34},
	{0x5d, 0x73},
	{0x5e, 0x11},
	{0x5f, 0x40},
	{0x60, 0x40},
	{0x61, 0xc8},
	{0x62, 0xa0},
	{0x63, 0x40},
	{0x64, 0x50},
	{0x65, 0x98},
	{0x66, 0xfa},
	{0x67, 0x70},
	{0x68, 0x58},
	{0x69, 0x85},
	{0x6a, 0x40},
	{0x6b, 0x39},
	{0x6c, 0x18},
	{0x6d, 0x28},
	{0x6e, 0x41},
	{0x70, 0x02},
	{0x71, 0x00},
	{0x72, 0x10},
	{0x73, 0x40},

	//{0x74, 0x32},
	//{0x75, 0x40},
	//{0x76, 0x30},
	//{0x77, 0x48},
	//{0x7a, 0x50},
	//{0x7b, 0x20},

	{0x80, 0x60},
	{0x81, 0x50},
	{0x82, 0x42},
	{0x83, 0x40},
	{0x84, 0x40},
	{0x85, 0x40},

	{0x74, 0x40},
	{0x75, 0x58},
	{0x76, 0x24},
	{0x77, 0x40},
	{0x78, 0x20},
	{0x79, 0x60},
	{0x7a, 0x58},
	{0x7b, 0x20},
	{0x7c, 0x30},
	{0x7d, 0x35},
	{0x7e, 0x10},
	{0x7f, 0x08},

	////////////////////ABS////////////////////
	{0x9c, 0x02},
	{0x9d, 0x20},
	//{0x9f, 0x40},

	////////////////////CC-AWB////////////////////
	{0xd0, 0x00},
	{0xd2, 0x2c},
	{0xd3, 0x80},

	////////////////////LSC///////////////////
	//// for xuye062d lens setting
	{0xfe, 0x01},
	{0xa0, 0x00},
	{0xa1, 0x3c},
	{0xa2, 0x50},
	{0xa3, 0x00},
	{0xa8, 0x0f},
	{0xa9, 0x08},
	{0xaa, 0x00},
	{0xab, 0x04},
	{0xac, 0x00},
	{0xad, 0x07},
	{0xae, 0x0e},
	{0xaf, 0x00},
	{0xb0, 0x00},
	{0xb1, 0x09},
	{0xb2, 0x00},
	{0xb3, 0x00},
	{0xb4, 0x31},
	{0xb5, 0x19},
	{0xb6, 0x24},
	{0xba, 0x3a},
	{0xbb, 0x24},
	{0xbc, 0x2a},
	{0xc0, 0x17},
	{0xc1, 0x13},
	{0xc2, 0x17},
	{0xc6, 0x21},
	{0xc7, 0x1c},
	{0xc8, 0x1c},
	{0xb7, 0x00},
	{0xb8, 0x00},
	{0xb9, 0x00},
	{0xbd, 0x00},
	{0xbe, 0x00},
	{0xbf, 0x00},
	{0xc3, 0x00},
	{0xc4, 0x00},
	{0xc5, 0x00},
	{0xc9, 0x00},
	{0xca, 0x00},
	{0xcb, 0x00},
	{0xa4, 0x00},
	{0xa5, 0x00},
	{0xa6, 0x00},
	{0xa7, 0x00},

	{0xfe, 0x00},
	{0x05, 0x00},
	{0x06, 0x6a},
	{0x07, 0x00},
	{0x08, 0x70},

	{0xfe, 0x01},
	{0x29, 0x00},
	{0x2a, 0x96},

	{0x2b, 0x02},
	{0x2c, 0x58},		//12 fps
	{0x2d, 0x07},
	{0x2e, 0x08},
	{0x2f, 0x07},		//10 fps
	{0x30, 0x08},
	{0x31, 0x09},
	{0x32, 0x60},

/////20120427////
	{0xfe, 0x01},
	{0x18, 0x22},
	{0x21, 0xc0},
	{0x06, 0x12},
	{0x08, 0x9c},
	{0x51, 0x28},
	{0x52, 0x10},
	{0x53, 0x20},
	{0x54, 0x40},
	{0x55, 0x16},
	{0x56, 0x30},
	{0x58, 0x60},
	{0x59, 0x08},
	{0x5c, 0x35},
	{0x5d, 0x72},
	{0x67, 0x80},
	{0x68, 0x60},
	{0x69, 0x90},
	{0x6c, 0x30},
	{0x6d, 0x60},
	{0x70, 0x10},

	{0xfe, 0x00},
	{0x9c, 0x0a},
	{0xa0, 0xaf},
	{0xa2, 0xff},
	{0xa4, 0x60},
	{0xa5, 0x31},
	{0xa7, 0x35},
	{0x42, 0xfe},
	{0xd1, 0x34},
	{0xd2, 0x34},
	{0xfe, 0x00},

	{0xfe, 0x00},
	////////////////////asde ///////////////////
	{0xa0, 0xaf},
	{0xa2, 0xff},

	{0xd5, 0x00},
	{0x7a, 0x80},
	{0x7b, 0x80},
	{0x7c, 0x86},

	{0x44, 0xa2},		// YUV  order
	{0xff, 0xff},

};

static struct regval_list gc0329_fmt_yuv422_vga[] = {

	{0xfe, 0x00},

	{0x59, 0x11},

	{0xff, 0xff},

};

static struct regval_list gc0329_fmt_yuv422_qvga[] = {

	{0xfe, 0x00},

	{0x59, 0x22},

	{0xff, 0xff},

};

static struct regval_list gc0329_fmt_yuv422_qcif[] = {

//    { 0xfe, 0x00 },
//    { 0x4b, 0xca },
//    { 0x50, 0x01 },
//    { 0x51, 0x00 },
//    { 0x52, 0x00 },
//    { 0x53, 0x00 },
//    { 0x54, 0x00 },
//    { 0x55, 0x00 },
//    { 0x56, 0x90 },  
//    { 0x57, 0x00 },
//    { 0x58, 0xb0 },
//    
//    { 0x59, 0xaa },  
//    { 0x5a, 0x03 },
//    { 0x5b, 0x04 },
//    { 0x5c, 0x08 },
//    { 0x5d, 0x00 },
//    { 0x5e, 0x00 },
//    { 0x5f, 0x04 },
//    { 0x60, 0x08 },
//    { 0x61, 0x00 },
//    { 0x62, 0x00 },
//    
	{0xff, 0xff},

};
