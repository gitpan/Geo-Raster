#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include "ral_config.h"
#include "ral_hash.h"
#include "ral_vd.h"
#include "ral_grid.h"
#include "ral_grid_rw.h"
#include "ral_ct.h"
#include "ral_plot.h"
#include "ral_catchment.h"
#include "arrays.h"   /* Pack functions decs */
#include "arrays.c"   /* Pack functions defs */



MODULE = Geo::Raster		PACKAGE = Geo::Raster


#ifdef DEBUG

int 
ral_setdebug(dbg)
	int dbg

#endif

#ifdef USE_PROGRESS_BAR

int 
ral_sethashmarks(h)
	int h

#endif

int 
ral_gdsigint(s)
	int s

cell *
ral_cellnew()

int 
ral_celldestroy(c)
	cell *c

int 
ral_gdsetmask(gd)
	grid *gd

grid *
ral_gdgetmask()

int 
ral_gdremovemask()
	CODE:
	{
		ral_gdsetmask(NULL);
		RETVAL = 1;
	}
  OUTPUT:
    RETVAL

int 
ral_gddestroy(gd)
	grid *gd

grid *
ral_gdnew(datatype, M, N)
	int datatype
	int M
	int N

int
ral_gdcopy(to, from)
	grid *to
	grid *from

grid *
ral_gdcreatecopy(gd, datatype)
	grid *gd
	int datatype

grid *
ral_gdopen(basename)
	char *basename

int 
ral_gdread(gd, basename, ext, el_size, byteorder)
	grid *gd
	char *basename
	char *ext
	int el_size
	int byteorder

int 
ral_gdsave(gd, basename)
	grid *gd
	char *basename

int 
ral_gdwrite(gd, basename, ext)
	grid *gd
	char *basename
	char *ext

int
ral_gdgetM(gd)
	grid *gd

int
ral_gdgetN(gd)
	grid *gd

int
ral_gddatatype(gd)
	grid *gd

int 
ral_gdget_nodata_value_int(gd)
	grid *gd

double 
ral_gdget_nodata_value_real(gd)
	grid *gd

int 
ral_gdset_nodata_value_int(gd, nodata)
	grid *gd
	int nodata

int 
ral_gdset_nodata_value_real(gd, nodata)
	grid *gd
	double nodata

double
ral_gdunitdist(gd)
	grid *gd

double 
ral_gdminX(gd)
	grid *gd

double 
ral_gdmaxX(gd)
	grid *gd

double 
ral_gdminY(gd)
	grid *gd

double 
ral_gdmaxY(gd)
	grid *gd

int
ral_gdsetbounds(gd, unitdist, minX, minY)
	grid *gd
	double unitdist
	double minX
	double minY

int
ral_gdsetbounds2(gd, unitdist, minX, maxY)
	grid *gd
	double unitdist
	double minX
	double maxY

int
ral_gdsetbounds3(gd, unitdist, maxX, minY)
	grid *gd
	double unitdist
	double maxX
	double minY

int
ral_gdsetbounds4(gd, minX, maxX, minY)
	grid *gd
	double minX
	double maxX
	double minY

int
ral_gdsetbounds5(gd, minX, maxX, maxY)
	grid *gd
	double minX
	double maxX
	double maxY

int
ral_gdsetbounds6(gd, minX, minY, maxY)
	grid *gd
	double minX
	double minY
	double maxY

int
ral_gdsetbounds7(gd, maxX, minY, maxY)
	grid *gd
	double maxX
	double minY
	double maxY

int 
ral_gdcopybounds(from, to)
	grid *from
	grid *to

int 
ral_gdx2j(gd, x)
	grid *gd
	double x

int 
ral_gdy2i(gd, y)
	grid *gd
	double y

double 
ral_gdj2x(gd, j)
	grid *gd
	int j

double 
ral_gdi2y(gd, i)
	grid *gd
	int i

int 
ral_gdset(gd, i, j, x)
	grid *gd
	int i
	int j
	double x

int 
ral_gdset2(gd, i, j, x)
	grid *gd
	int i
	int j
	int x

int 
ral_gdsetnodata(gd, i, j)
	grid *gd
	int i
	int j

double 
ral_gdget(gd, i, j)
	grid *gd
	int i
	int j

int 
ral_gdget2(gd, i, j)
	grid *gd
	int i
	int j

int 
ral_gdsetminmax(gd)
	grid *gd

double 
ral_gdgetminval(gd)
	grid *gd

double 
ral_gdgetmaxval(gd)
	grid *gd

AV *
_gdgetmin(gd)
	grid *gd
	CODE:
	{
		cell c = ral_gdgetmin(gd);
		AV *av = newAV();
		if (av) {
			SV *sv = newSViv(c.i);
			av_push(av, sv);
			sv = newSViv(c.j);
			av_push(av, sv);
		}
		RETVAL = av;
	}
  OUTPUT:
    RETVAL

AV * 
_gdgetmax(gd)
	grid *gd
	CODE:
	{
		cell c = ral_gdgetmax(gd);
		AV *av = newAV();
		if (av) {
			SV *sv = newSViv(c.i);
			av_push(av, sv);
			sv = newSViv(c.j);
			av_push(av, sv);
		}
		RETVAL = av;
	}
  OUTPUT:
    RETVAL

int 
ral_gdsetall_int(gd, x)
	grid *gd
	int x

int 
ral_gdsetall(gd, x)
	grid *gd
	double x

int 
ral_gdsetallnodata(gd)
	grid *gd

int 
ral_gddata(gd)
	grid *gd

int 
ral_gdnot(gd)
	grid *gd

int 
ral_gdandgd(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gdorgd(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gdaddsv(gd, x)
	grid *gd
	double x

int 
ral_gdaddgd(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gdsubgd(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gdmultsv(gd, x)
	grid *gd
	double x

int 
ral_gdmultgd(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gddivsv(gd, x)
	grid *gd
	double x

int
ral_svdivgd(x, gd)
	double x
	grid *gd

int 
ral_gddivgd(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gdmodulussv(gd, x)
	grid *gd
	double x

int
ral_svmodulusgd(x, gd)
	double x
	grid *gd

int 
ral_gdmodulusgd(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gdpowersv(gd, x)
	grid *gd
	double x

int
ral_svpowergd(x, gd)
	double x
	grid *gd

int 
ral_gdpowergd(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gdabs(gd)
	grid *gd

int 
ral_gdacos(gd)
	grid *gd

int 
ral_gdatan(gd)
	grid *gd

int 
ral_gdatan2(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gdceil(gd)
	grid *gd

int 
ral_gdcos(gd)
	grid *gd

int 
ral_gdcosh(gd)
	grid *gd

int 
ral_gdexp(gd)
	grid *gd

int 
ral_gdfloor(gd)
	grid *gd

int 
ral_gdlog(gd)
	grid *gd

int 
ral_gdlog10(gd)
	grid *gd

int 
ral_gdpow(gd, b)
	grid *gd
	double b

int 
ral_gdsin(gd)
	grid *gd

int 
ral_gdsinh(gd)
	grid *gd

int 
ral_gdsqrt(gd)
	grid *gd

int 
ral_gdtan(gd)
	grid *gd

int 
ral_gdtanh(gd)
	grid *gd

grid *
ral_gdround(gd)
	grid *gd

int
ral_gdltsv(gd, x)
	grid *gd
	double x

int
ral_gdgtsv(gd, x)
	grid *gd
	double x

int
ral_gdlesv(gd, x)
	grid *gd
	double x

int
ral_gdgesv(gd, x)
	grid *gd
	double x

int
ral_gdeqsv(gd, x)
	grid *gd
	double x

int
ral_gdnesv(gd, x)
	grid *gd
	double x

int
ral_gdcmpsv(gd, x)
	grid *gd
	double x

int
ral_gdltgd(gd1, gd2)
	grid *gd1
	grid *gd2

int
ral_gdgtgd(gd1, gd2)
	grid *gd1
	grid *gd2

int
ral_gdlegd(gd1, gd2)
	grid *gd1
	grid *gd2

int
ral_gdgegd(gd1, gd2)
	grid *gd1
	grid *gd2

int
ral_gdeqgd(gd1, gd2)
	grid *gd1
	grid *gd2

int
ral_gdnegd(gd1, gd2)
	grid *gd1
	grid *gd2

int
ral_gdcmpgd(gd1, gd2)
	grid *gd1
	grid *gd2

int
ral_gdminsv(gd, x)
	grid *gd
	double x

int
ral_gdmaxsv(gd, x)
	grid *gd
	double x

int
ral_gdmingd(gd1, gd2)
	grid *gd1
	grid *gd2

int
ral_gdmaxgd(gd1, gd2)
	grid *gd1
	grid *gd2

grid *
ral_gdcross(a, b)
	grid *a
	grid *b

int 
ral_gdif_thensv(a, b, c)
	grid *a
	grid *b
	double c

int 
ral_gdif_thenelsesv(a, b, c, d)
	grid *a
	grid *b
	double c
	double d

int 
ral_gdif_thengd(a, b, c)
	grid *a
	grid *b
	grid *c

int 
ral_gdzonal_if_then(a, b, k, v, n)
	grid *a
	grid *b
	int *k
	double *v
	int n

int 
ral_gdbinary(gd)
	grid *gd

int 
ral_gdapplytempl(gd, templ, new_val)
	grid *gd
	int *templ
	int new_val

int
ral_gdmap(gd, s, d, n)
	grid *gd
	int *s
	int *d
	int n

double 
_gdzonesize(gd, i, j)
	grid *gd
	int i
	int j
	CODE:
	{	
		cell c = {i, j};
		RETVAL = ral_gdzonesize(gd, c);
  	}
  OUTPUT:
    RETVAL

grid *
ral_gdborders(gd)
	grid *gd

grid *
ral_gdborders2(gd)
	grid *gd

grid *
ral_gdareas(gd, k)
	grid *gd
	int k

int 
ral_gdconnect(gd) 
	grid *gd

int
ral_gdnrareas(gd,connectivity)
	grid *gd
	int connectivity

grid *
ral_gdclip(gd, i1, j1, i2, j2)
	grid *gd
	int i1
	int j1
	int i2
	int j2

grid *
ral_gdjoin(g1, g2)
	grid *g1
	grid *g2

grid *
ral_gdtransform(gd, tr, M, N, pick, value)
	grid *gd
	double *tr
	int M
	int N
	int pick
	int value

grid *
ral_a2gd(datatype, M, N, infile, mode)
	int datatype
	int M
	int N
	char *infile
	int mode

int
ral_gd2a(gd, outfile)
	grid *gd
	char *outfile

int 
ral_gdline(gd, i1, j1, i2, j2, pen)
	grid *gd
	int i1
	int j1
	int i2
	int j2
	double pen

int 
ral_gdfilledrect(gd, i1, j1, i2, j2, pen)
	grid *gd
	int i1
	int j1
	int i2
	int j2
	double pen

void
ral_gdfilledcircle(gd, i, j, r, r2, pen)
	grid *gd
	int i
	int j
	int r
	int r2
	double pen

int 
_gdfloodfill(gd, i, j, icolor, rcolor, connectivity)
	grid *gd
	int i
	int j
	int icolor
	double rcolor
	int connectivity
	CODE:
	{	
		cell c = {i, j};
		RETVAL = ral_gdfloodfill(gd, c, icolor, rcolor, connectivity);
  	}
  OUTPUT:
    RETVAL

color_table *
ral_ctcreate(nc, contra, bright)
	int nc
	double contra
	double bright

int 
ral_ctdestroy(ct)
	color_table *ct

int 
ral_ctset(ct, i, l, r, g, b)
	color_table *ct
	int i
	double l
	double r
	double g
	double b

int 
ral_ctsize(ct)
	color_table *ct

double 
ral_ctget_contrast(ct)
	color_table *ct

double 
ral_ctget_brightness(ct)
	color_table *ct

double 
ral_ctgetl(ct, i)
	color_table *ct
	int i

double 
ral_ctgetr(ct, i)
	color_table *ct
	int i

double 
ral_ctgetg(ct, i)
	color_table *ct
	int i

double 
ral_ctgetb(ct, i)
	color_table *ct
	int i

#ifndef HAVE_NETPBM

int
have_netpbm()
	CODE:
	{	
		RETVAL = 0;
  	}
  OUTPUT:
    RETVAL

grid *
ral_ppm2gd(datatype, infile, channel)
	int datatype
	char *infile
	int channel
	CODE:
	{	
		fprintf(stderr,"ERROR: Netpbm is not available!\n");
		RETVAL = NULL;
  	}
  OUTPUT:
    RETVAL

int
ral_gd2ppm(gd, outfile, ct)
	grid *gd
	char *outfile
	color_table *ct
	CODE:
	{	
		fprintf(stderr,"ERROR: Netpbm is not available!\n");
		RETVAL = 0;
  	}
  OUTPUT:
    RETVAL

int 
ral_RGBgd2ppm(R, G, B, outfile)
	grid *R
	grid *G
	grid *B
	char *outfile
	CODE:
	{	
		fprintf(stderr,"ERROR: Netpbm is not available!\n");
		RETVAL = 0;
  	}
  OUTPUT:
    RETVAL

int 
ral_HSVgd2ppm(H, S, V, outfile)
	grid *H
	grid *S
	grid *V
	char *outfile
	CODE:
	{	
		fprintf(stderr,"ERROR: Netpbm is not available!\n");
		RETVAL = 0;
  	}
  OUTPUT:
    RETVAL


#else

int
have_netpbm()
	CODE:
	{	
		RETVAL = 1;
  	}
  OUTPUT:
    RETVAL

grid *
ral_ppm2gd(datatype, infile, channel)
	int datatype
	char *infile
	int channel

int
ral_gd2ppm(gd, outfile, ct)
	grid *gd
	char *outfile
	color_table *ct

int 
ral_RGBgd2ppm(R, G, B, outfile)
	grid *R
	grid *G
	grid *B
	char *outfile

int 
ral_HSVgd2ppm(H, S, V, outfile)
	grid *H
	grid *S
	grid *V
	char *outfile

#endif

point_data *
ral_pointcreate(x, y, color, line_width, symbol, symbol_height, symbol_font, label, label_placement)
	double x
	double y
	int color
	int line_width
	int symbol
	double symbol_height
	int symbol_font
	char *label
	int label_placement

int 
ral_pointdestroy(p)
	point_data *p

lseg_data *
ral_lsegcreate(x1, y1, x2, y2, color, style, width, arrow, arrow_angle, arrow_barb, label,  label_placement)
	double x1
	double y1
	double x2
	double y2
	int color
	int style
	int width
	int arrow
	double arrow_angle
	double arrow_barb
	char *label
	int label_placement

int 
ral_lsegdestroy(lseg)
	lseg_data *lseg

polygon_data *
ral_polygoncreate(n, x, y, color, line_style, line_width, fill_style, fill_line_angle, fill_line_sepn, fill_line_phase, label, label_placement)
	int n
	double *x
	double *y
	int color
	int line_style
	int line_width
	int fill_style
	double fill_line_angle
	double fill_line_sepn
	double fill_line_phase
	char *label
	int label_placement

int 
ral_polygondestroy(polygon)
	polygon_data *polygon

vector_data *
ral_vdnull()

vector_data *
ral_vdcreate(name, id, label_color, label_line_width, label_font, label_height)
	char *name
	int id
	int label_color
	int label_line_width
	int label_font
	int label_height

int 
ral_vddestroy(vd)
	vector_data *vd

int 
ral_vdget_id(vd)
	vector_data *vd

vector_data *
ral_vdnext(vd)
	vector_data *vd

int 
ral_vdbreaklist(vd)
	vector_data *vd

int 
ral_vdaddvd(root, vd)
	vector_data *root
	vector_data *vd

int 
ral_vdaddpoint(vd, point)
	vector_data *vd
	point_data *point

int 
ral_vdaddlseg(vd, lseg)
	vector_data *vd
	lseg_data *lseg

int 
ral_vdaddpolygon(vd, polygon)
	vector_data *vd
	polygon_data *polygon

#ifndef HAVE_PGPLOT

int
have_pgplot()
	CODE:
	{	
		RETVAL = 0;
  	}
  OUTPUT:
    RETVAL

int 
ral_gdwindow_open()
	CODE:
	{	
		fprintf(stderr,"ERROR: PGPLOT is not available!\n");
		RETVAL = 0;
  	}
  OUTPUT:
    RETVAL

int 
ral_gdwindow_close(window)
	int window
	CODE:
	{	
		fprintf(stderr,"ERROR: PGPLOT is not available!\n");
		RETVAL = 0;
  	}
  OUTPUT:
    RETVAL

grid *
ral_gdplot(gd, vd, device, window, ct, draw, options, default_width)
	grid *gd
	vector_data *vd
	char *device
	int window
	color_table *ct
	int draw
	int options
	int default_width
	CODE:
	{	
		fprintf(stderr,"ERROR: PGPLOT is not available!\n");
		RETVAL = NULL;
  	}
  OUTPUT:
    RETVAL


#else

int
have_pgplot()
	CODE:
	{	
		RETVAL = 1;
  	}
  OUTPUT:
    RETVAL

int 
ral_gdwindow_open()

int 
ral_gdwindow_close(window)
	int window

grid *
ral_gdplot(gd, vd, device, window, ct, draw, options, default_width)
	grid *gd
	vector_data *vd
	char *device
	int window
	color_table *ct
	int draw
	int options
	int default_width

#endif

int
ral_gdprint(gd)
	grid *gd

AV *
_gdprint1(gd, quiet, wc)
	grid *gd
	int quiet
	int wc
	CODE:
	{	
		double *p = NULL;
		int i, psize = 0;
		AV *av = newAV();
		if (!av) goto fail;
		if (ral_gdprint1(gd, &p, &psize, quiet, wc)) 
		for (i=0; i<psize; i++) {
			SV *sv = newSVnv(p[i]);
			if (!sv) goto fail;
			av_push(av, sv);
		}
		goto ok;
	fail:
		fprintf(stderr,"Out of memory!\n");
	ok:
		if (p) free(p);
		RETVAL = av;
  	}
  OUTPUT:
    RETVAL

AV *
_gdhistogram(gd, bin, n)
	grid *gd
	double *bin
	int n
	CODE:
	{
		int i, *c = NULL;
		AV *counts = newAV();
		if (!counts) goto fail;
		c = (int *)calloc(n+1,sizeof(int));
		if (!c) goto fail;
		if (ral_gdhistogram(gd, bin, c, n))
		for (i=0; i<n+1; i++) {
			SV *sv = newSViv(c[i]);
			if (!sv) goto fail;
			av_push(counts, sv);
		}
		goto ok;
	fail:
		fprintf(stderr,"Out of memory!\n");
	ok:
		if (c) free(c);
		RETVAL = counts;
	}
  OUTPUT:
    RETVAL

HV *
_gdcontents(gd)
	grid *gd
	CODE:
	{
		hash table;
		int i;
		HV* h = newHV();
		if (!h) goto fail;
		if (!ral_hash_create(&table, 200)) goto ok;
		if (ral_gdcontents(gd, &table))
		for (i = 0; i < table.size; i++) {
			hash_int_item *a = (hash_int_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSViv(a->value);
				if (!sv) goto fail;
				snprintf(key, 10, "%i", a->key);
				klen = strlen(key);
				hv_store(h, key, klen, sv, 0);
				a = a->next;
			}
		}
		ral_hash_destroy(&table);
		goto ok;
	fail:
		fprintf(stderr,"Out of memory!\n");
	ok:
		RETVAL = h;
	}
  OUTPUT:
    RETVAL

HV *
_gdzonalcount(gd, zones)
	grid *gd
	grid *zones
	CODE:
	{
		hash table;
		int i, n = 0;
		HV* h = newHV();
		if (!h) goto fail;
		if (!ral_hash_create(&table, 200)) goto ok;
		if (ral_gdzonalcount(gd, zones, &table))
		for (i = 0; i < table.size; i++) {
			hash_int_item *a = (hash_int_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSViv(a->value);
				if (!sv) goto fail;
				snprintf(key, 10, "%i", a->key);
				klen = strlen(key);
				hv_store(h, key, klen, sv, 0);
				a = a->next;
			}
		}
		ral_hash_destroy(&table);
		goto ok;
	fail:
		fprintf(stderr,"Out of memory!\n");
	ok:
		RETVAL = h;
	}
  OUTPUT:
    RETVAL

HV *
_gdzonalsum(gd, zones)
	grid *gd
	grid *zones
	CODE:
	{
		hash table;
		int i, n = 0;
		HV* h = newHV();
		if (!h) goto fail;
		if (!ral_hash_create(&table, 200)) goto ok;
		if (ral_gdzonalsum(gd, zones, &table))
		for (i = 0; i < table.size; i++) {
			hash_double_item *a = (hash_double_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSVnv(a->value);
				if (!sv) goto fail;
				snprintf(key, 10, "%i", a->key);
				klen = strlen(key);
				hv_store(h, key, klen, sv, 0);
				a = a->next;
			}
		}
		ral_hash_destroy(&table);
		goto ok;
	fail:
		fprintf(stderr,"Out of memory!\n");
	ok:
		RETVAL = h;
	}
  OUTPUT:
    RETVAL

HV *
_gdzonalmin(gd, zones)
	grid *gd
	grid *zones
	CODE:
	{
		hash table;
		int i, n = 0;
		HV* h = newHV();
		if (!h) goto fail;
		if (!ral_hash_create(&table, 200)) goto ok;
		if (ral_gdzonalmin(gd, zones, &table))
		for (i = 0; i < table.size; i++) {
			hash_double_item *a = (hash_double_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSVnv(a->value);
				if (!sv) goto fail;
				snprintf(key, 10, "%i", a->key);
				klen = strlen(key);
				hv_store(h, key, klen, sv, 0);
				a = a->next;
			}
		}
		ral_hash_destroy(&table);
		goto ok;
	fail:
		fprintf(stderr,"Out of memory!\n");
	ok:
		RETVAL = h;
	}
  OUTPUT:
    RETVAL

HV *
_gdzonalmax(gd, zones)
	grid *gd
	grid *zones
	CODE:
	{
		hash table;
		int i, n = 0;
		HV* h = newHV();
		if (!h) goto fail;
		if (!ral_hash_create(&table, 200)) goto ok;
		if (ral_gdzonalmax(gd, zones, &table))
		for (i = 0; i < table.size; i++) {
			hash_double_item *a = (hash_double_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSVnv(a->value);
				if (!sv) goto fail;
				snprintf(key, 10, "%i", a->key);
				klen = strlen(key);
				hv_store(h, key, klen, sv, 0);
				a = a->next;
			}
		}
		ral_hash_destroy(&table);
		goto ok;
	fail:
		fprintf(stderr,"Out of memory!\n");
	ok:
		RETVAL = h;
	}
  OUTPUT:
    RETVAL

HV *
_gdzonalmean(gd, zones)
	grid *gd
	grid *zones
	CODE:
	{
		hash table;
		int i, n = 0;
		HV* h = newHV();
		if (!h) goto fail;
		if (!ral_hash_create(&table, 200)) goto ok;
		if (ral_gdzonalmean(gd, zones, &table))
		for (i = 0; i < table.size; i++) {
			hash_double_item *a = (hash_double_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSVnv(a->value);
				if (!sv) goto fail;
				snprintf(key, 10, "%i", a->key);
				klen = strlen(key);
				hv_store(h, key, klen, sv, 0);
				a = a->next;
			}
		}
		ral_hash_destroy(&table);
		goto ok;
	fail:
		fprintf(stderr,"Out of memory!\n");
	ok:
		RETVAL = h;
	}
  OUTPUT:
    RETVAL

HV *
_gdzonalvariance(gd, zones)
	grid *gd
	grid *zones
	CODE:
	{
		hash table;
		int i, n = 0;
		HV* h = newHV();
		if (!h) goto fail;
		if (!ral_hash_create(&table, 200)) goto ok;
		if (ral_gdzonalvariance(gd, zones, &table))
		for (i = 0; i < table.size; i++) {
			hash_double_item *a = (hash_double_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSVnv(a->value);
				if (!sv) goto fail;
				snprintf(key, 10, "%i", a->key);
				klen = strlen(key);
				hv_store(h, key, klen, sv, 0);
				a = a->next;
			}
		}
		ral_hash_destroy(&table);
		goto ok;
	fail:
		fprintf(stderr,"Out of memory!\n");
	ok:
		RETVAL = h;
	}
  OUTPUT:
    RETVAL

int 
ral_gdgrowzones(zones, grow, connectivity)
	grid *zones
	grid *grow
	int connectivity

HV *
_gdneighbors(gd)
	grid *gd
	CODE:
	{
		hash **b;
		int *c, i, j, n;
		HV* h = newHV();
		if (!h) goto fail;
		if (!ral_gdneighbors(gd, &b, &c, &n)) goto fail;
		for (i = 0; i < n; i++) {
			char key[10];
			AV*  av = newAV();
			U32 klen;
			int j;
			if (!av) goto fail;
			snprintf(key, 10, "%i", c[i]);
			klen = strlen(key);
			for (j = 0; j < b[i]->size; j++) {
				hash_int_item *a = (hash_int_item *)b[i]->table[j];
				while (a) {
					SV *sv = newSViv(a->key);
					if (!sv) goto fail;
					av_push(av, sv);
					a = a->next;
				}				
			}
			hv_store(h, key, klen, newRV_inc((SV*) av), 0);
		}
		goto ok;
	fail:
		fprintf(stderr,"Out of memory!\n");
	ok:
		if (b) {
			for (i = 0; i < n; i++) {
				if (b[i]) {
					ral_hash_destroy(b[i]);
					free(b[i]);
				}
			}
			free(b);
		}
		if (c) free(c);
		RETVAL = h;
	}
  OUTPUT:
    RETVAL

grid *
ral_gdbufferzone(gd, z, w)
	grid *gd
	int z
	double w

int
ral_gdcount(gd)
	grid *gd

double 
ral_gdsum(gd)
	grid *gd

double 
ral_gdmean(gd)
	grid *gd

double 
ral_gdvariance(gd)
	grid *gd

grid *
ral_gddistances(gd)
	grid *gd

grid *
ral_gddirections(gd)
	grid *gd

grid *
ral_gdnn(gd)
	grid *gd

HV *
_gdzones(gd, z)
	grid *gd
	grid *z
	CODE:
	{
		double **tot = NULL;
		int *c = NULL;
		int *k = NULL;
		int i, n;
		HV* hv = newHV();
		if (!hv) goto fail;
		if (ral_gdzones(gd, z, &tot, &c, &k, &n)) {
			for (i = 0; i < n; i++) if (k[i]) {
				int j;
				char key[10];
				U32 klen;
				AV *av;
				SV **sv = (SV **)calloc(k[i], sizeof(SV *));
				if (!sv) goto fail;
				for (j = 0; j < k[i]; j++) {
					sv[j] = newSVnv(tot[i][j]);
					if (!sv[j]) goto fail;
				}
				av = av_make(k[i], sv);
				snprintf(key, 10, "%i", c[i]);
				klen = strlen(key);
				hv_store(hv, key, klen, newRV_inc((SV*)av), 0);
			}
		}
		goto ok;
	fail:
		fprintf(stderr,"Out of memory!\n");
	ok:
		if (tot) {
			for (i = 0; i < n; i++)
				if (tot[i]) free(tot[i]);
			free(tot);
		}
		if (c) free(c);
		if (k) free(k);
		RETVAL = hv;
	}
  OUTPUT:
    RETVAL

grid *
ral_dem2aspect(dem)
	grid *dem

grid *
ral_dem2slope(dem, z_factor)
	grid *dem
	double z_factor

grid *
ral_dem2fdg(dem, method)
	grid *dem
	int method

AV *
_find_outlet(fdg, i, j)
	grid *fdg
	int i
	int j
	CODE:
	{
		cell c = {i,j};
		c = ral_find_outlet(fdg, c);
		AV *av = newAV();
		if (av) {
			SV *sv = newSViv(c.i);
			av_push(av, sv);
			sv = newSViv(c.j);
			av_push(av, sv);
		}
		RETVAL = av;
	}
  OUTPUT:
    RETVAL

grid *
ral_dem2ucg(dem) 
	grid *dem

int
ral_fdg_fixflats1(fdg, dem)
	grid *fdg
	grid *dem

int
ral_fdg_fixflats2(fdg, dem)
	grid *fdg
	grid *dem

int 
ral_dem_fillpits(dem, z_limit)
	grid *dem
	double z_limit

int 
ral_dem_cutpeaks(dem, z_limit)
	grid *dem
	double z_limit

grid *
ral_dem_depressions(dem, fdg, inc_m)
	grid *dem
	grid *fdg
	int inc_m

int 
ral_dem_filldepressions(dem, fdg)
	grid *dem
	grid *fdg

int 
ral_dem_breach(dem, fdg, limit)
	grid *dem
	grid *fdg
	int limit

int 
ral_fdg_fixpits(fdg, dem)
	grid *fdg
	grid *dem

int 
ral_water_route(water, dem, fdg, flow, k, d, f, r)
	grid *water
	grid *dem
	grid *fdg
	grid *flow
	grid *k
	grid *d
	int f
	double r

grid *
_fdg2uag_a(fdg)
	grid *fdg
	CODE:
	{
		RETVAL = ral_fdg2uag(fdg, NULL);
	}
  OUTPUT:	
	RETVAL

grid *
_fdg2uag_b(fdg, load)
	grid *fdg
	grid *load
	CODE:
	{
		RETVAL = ral_fdg2uag(fdg, load);
	}
  OUTPUT:	
	RETVAL

grid *
ral_fdg_distance_to_pit(fdg, steps)
	grid *fdg
	int steps
	CODE:
	{
		RETVAL = ral_fdg_distance_to_channel(fdg, NULL, steps);
	}
  OUTPUT:	
	RETVAL

grid *
ral_fdg_distance_to_channel(fdg, streams, int steps)
	grid *fdg
	grid *streams

grid *
ral_dem2uag(dem, fdg, recursion) 
	grid *dem
	grid *fdg
	int recursion

grid *
ral_dem2dag(dem, fdg)
	grid *dem
	grid *fdg

int 
ral_fdg_catchment(fdg, mark, i, j, m)
	grid *fdg
	grid *mark
	int i
	int j
	int m
	CODE:
	{	
		pour_point_struct pp;
		if (!ral_init_pour_point_struct(&pp, fdg, NULL, mark)) 
			RETVAL = 0;
		else {
			cell c = {i, j};
			if (!GD_CELL_IN(fdg, c)) {
	    			fprintf(stderr,"fdg_catchment: the cell %i,%i is not within FDG\n",i,j);
	    			RETVAL = 0;
			} else {
				RETVAL = ral_mark_upslope_pixels(&pp, c, m);
			}
		}
  	}
  OUTPUT:
    RETVAL

grid *
ral_streams_subcatchments(streams, fdg, i, j)
	grid *streams
	grid *fdg
	int i
	int j

int
ral_streams_number(streams, fdg, i, j, sid0)
	grid *streams
	grid *fdg
	int i
	int j
	int sid0

int 
ral_fdg_killoutlets(fdg, lakes, uag)
	grid *fdg
	grid *lakes
	grid *uag

int 
ral_streams_prune(streams, fdg, lakes, i, j, min_l)
	grid *streams
	grid *fdg
	grid *lakes
	int i
	int j
	double min_l

int 
_streams_prune(streams, fdg, i, j, min_l)
	grid *streams
	grid *fdg
	int i
	int j
	double min_l
	CODE:
	{
		RETVAL = ral_streams_prune(streams, fdg, NULL, i, j, min_l);
	}
  OUTPUT:
    RETVAL



int 
ral_streams_break(streams, fdg, lakes, nsid)
	grid *streams
	grid *fdg
	grid *lakes
	int nsid

HV *
_subcatchments(sheds, streams, fdg, lakes, i, j, headwaters)
	grid *sheds
	grid *streams
	grid *fdg
	grid *lakes
	int i
	int j
	int headwaters
	CODE:
	{
		ws w;
		HV *h = newHV();
		if (!h) goto fail;
		if (ral_ws_subcatchments(&w, sheds, streams, fdg, lakes, i, j, headwaters))
		for (i = 0; i < w.n; i++) {
			char key[20];
			SV *sv;
			U32 klen;
			snprintf(key, 20, "%i,%i", w.down[i].i, w.down[i].j);
			klen = strlen(key);
			sv = newSVpv(key, klen);
			if (!sv) goto fail;
			snprintf(key, 20, "%i,%i", w.outlet[i].i, w.outlet[i].j);
			klen = strlen(key);
			hv_store(h, key, klen, sv, 0);
		}
		ral_wsempty(&w);
		goto ok;
	fail:
		fprintf(stderr,"Out of memory!\n");
	ok:
		RETVAL = h;
	}
  OUTPUT:
    RETVAL

