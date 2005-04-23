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
#include "ral_read.h"
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

#else

int 
ral_setdebug(dbg)
	int dbg
	CODE:
	{
		RETVAL = 1;
	}
  OUTPUT:
    RETVAL

#endif

#ifdef USE_PROGRESS_BAR

int 
ral_sethashmarks(h)
	int h

#else 

int 
ral_sethashmarks(h)
	int h
	CODE:
	{
		RETVAL = 1;
	}
  OUTPUT:
    RETVAL

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

void
ral_gddestroy(gd)
	grid *gd

grid *
ral_gdnew(datatype, M, N)
	int datatype
	int M
	int N

grid *
ral_gdnewlike(gd, datatype)
	grid *gd
	int datatype

grid *
ral_gdnewcopy(gd, datatype)
	grid *gd
	int datatype

int 
ral_gdread(gd, filename, el_type, byteorder)
	grid *gd
	char *filename
	int el_type
	int byteorder

int 
ral_gdwrite(gd, filename)
	grid *gd
	char *filename

int
ral_gdget_height(gd)
	grid *gd

int
ral_gdget_width(gd)
	grid *gd

int
ral_gdget_datatype(gd)
	grid *gd

SV * 
_ral_gdget_nodata_value(gd)
	grid *gd
	CODE:
	{
		SV *sv;
		switch (gd->datatype) {
		case INTEGER_GRID:
			sv = newSViv(IGD_NODATA_VALUE(gd));
			break;
		case REAL_GRID:
			sv = newSVnv(RGD_NODATA_VALUE(gd));
		}
		RETVAL = sv;
	}
  OUTPUT:
    RETVAL

void 
ral_gdset_integer_nodata_value(gd, nodata_value)
	grid *gd
	INTEGER nodata_value

int
ral_gdset_real_nodata_value(gd, nodata_value)
	grid *gd
	REAL nodata_value

double
ral_gdget_unit_length(gd)
	grid *gd

AV *
_ral_gdget_world(gd)
	grid *gd
	CODE:
	{
		rectangle xy = ral_gdget_world(gd);
		AV *av = newAV();
		if (av) {
			SV *sv = newSVnv(xy.min.x);
			av_push(av, sv);
			sv = newSVnv(xy.min.y);
			av_push(av, sv);
			sv = newSVnv(xy.max.x);
			av_push(av, sv);
			sv = newSVnv(xy.max.y);
			av_push(av, sv);
		}
		RETVAL = av;
	}
  OUTPUT:
    RETVAL

void
ral_gdset_bounds_unn(gd, unit_length, minX, minY)
	grid *gd
	double unit_length
	double minX
	double minY

void
ral_gdset_bounds_unx(gd, unit_length, minX, maxY)
	grid *gd
	double unit_length
	double minX
	double maxY

void
ral_gdset_bounds_uxn(gd, unit_length, maxX, minY)
	grid *gd
	double unit_length
	double maxX
	double minY

void
ral_gdset_bounds_uxx(gd, unit_length, maxX, maxY)
	grid *gd
	double unit_length
	double maxX
	double maxY

void
ral_gdset_bounds_nxn(gd, minX, maxX, minY)
	grid *gd
	double minX
	double maxX
	double minY

void
ral_gdset_bounds_nxx(gd, minX, maxX, maxY)
	grid *gd
	double minX
	double maxX
	double maxY

void
ral_gdset_bounds_nnx(gd, minX, minY, maxY)
	grid *gd
	double minX
	double minY
	double maxY

void
ral_gdset_bounds_xnx(gd, maxX, minY, maxY)
	grid *gd
	double maxX
	double minY
	double maxY

void
ral_gdcopy_bounds(from, to)
	grid *from
	grid *to

AV *
_ral_gdpoint2cell(gd, px, py)
	grid *gd
	double px
	double py
	CODE:
	{
		point p = {px,py};
		cell c = ral_gdpoint2cell(gd, p);
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
_ral_gdcell2point(gd, ci, cj)
	grid *gd
	int ci
	int cj
	CODE:
	{
		cell c = {ci,cj};
		point p = ral_gdcell2point(gd, c);
		AV *av = newAV();
		if (av) {
			SV *sv = newSVnv(p.x);
			av_push(av, sv);
			sv = newSVnv(p.y);
			av_push(av, sv);
		}
		RETVAL = av;
	}
  OUTPUT:
    RETVAL


SV *
_ral_gdget(gd, ci, cj)
	grid *gd
	int ci
	int cj
	CODE:
	{
		cell c = {ci,cj};
		SV *sv;
		if (GD_CELL_IN(gd, c)) {
			if (gd->datatype == REAL_GRID) {
				REAL x = RGD_CELL(gd, c);
				if (x == RGD_NODATA_VALUE(gd)) 
					sv = newSVpv("nodata",6);
				else
					sv = newSVnv(x);
			} else {
				INTEGER x = IGD_CELL(gd, c);
				if (x == IGD_NODATA_VALUE(gd)) 
					sv = newSVpv("nodata",6);
				else
					sv = newSViv(x);
			}
		} else {
			sv = newSV(0);
		}
		RETVAL = sv;
	}
  OUTPUT:
    RETVAL

int 
_ral_gdset_real(gd, ci, cj, x)
	grid *gd
	int ci
	int cj
	REAL x
	CODE:
	{
		cell c = {ci,cj};
		int ret = ral_gdset_real(gd, c, x);
		RETVAL = ret;
	}
  OUTPUT:
    RETVAL

int 
_ral_gdset_integer(gd, ci, cj, x)
	grid *gd
	int ci
	int cj
	INTEGER x
	CODE:
	{
		cell c = {ci,cj};
		int ret = ral_gdset_integer(gd, c, x);
		RETVAL = ret;
	}
  OUTPUT:
    RETVAL

int 
_ral_gdset_nodata(gd, ci, cj)
	grid *gd
	int ci
	int cj
	CODE:
	{
		cell c = {ci,cj};
		int ret = ral_gdset_nodata(gd, c);
		RETVAL = ret;
	}
  OUTPUT:
    RETVAL


void 
ral_gdset_minmax(gd)
	grid *gd

AV *
_ral_gdget_minmax(gd)
	grid *gd
	CODE:
	{
		AV *av = newAV();
		switch (gd->datatype) {
		case INTEGER_GRID: {
			SV *sv = newSViv(IGD_VALUE_RANGE(gd)->min);
			av_push(av, sv);
			sv = newSViv(IGD_VALUE_RANGE(gd)->max);
			av_push(av, sv);
		}
		break;
		case REAL_GRID: {
			SV *sv = newSVnv(RGD_VALUE_RANGE(gd)->min);
			av_push(av, sv);
			sv = newSVnv(RGD_VALUE_RANGE(gd)->max);
			av_push(av, sv);
		}
		}
		RETVAL = av;
	}
  OUTPUT:
    RETVAL

void 
ral_gdset_all_integer(gd, x)
	grid *gd
	INTEGER x

int 
ral_gdset_all_real(gd, x)
	grid *gd
	REAL x

void 
ral_gdset_all_nodata(gd)
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
ral_gdaddreal(gd, x)
	grid *gd
	REAL x

void
ral_gdaddinteger(gd, x)
	grid *gd
	INTEGER x

int 
ral_gdaddgd(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gdsubgd(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gdmultreal(gd, x)
	grid *gd
	REAL x

void
ral_gdmultinteger(gd, x)
	grid *gd
	INTEGER x

int 
ral_gdmultgd(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gddivreal(gd, x)
	grid *gd
	REAL x

int 
ral_gddivinteger(gd, x)
	grid *gd
	INTEGER x

int
ral_realdivgd(x, gd)
	REAL x
	grid *gd

int
ral_integerdivgd(x, gd)
	INTEGER x
	grid *gd

int 
ral_gddivgd(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gdmodulussv(gd, x)
	grid *gd
	REAL x

int
ral_svmodulusgd(x, gd)
	INTEGER x
	grid *gd

int 
ral_gdmodulusgd(gd1, gd2)
	grid *gd1
	grid *gd2

int 
ral_gdpowerreal(gd, x)
	grid *gd
	REAL x

int
ral_realpowergd(x, gd)
	REAL x
	grid *gd

int 
ral_gdpowergd(gd1, gd2)
	grid *gd1
	grid *gd2

void
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
ral_gdltreal(gd, x)
	grid *gd
	REAL x

int
ral_gdgtreal(gd, x)
	grid *gd
	REAL x

int
ral_gdlereal(gd, x)
	grid *gd
	REAL x

int
ral_gdgereal(gd, x)
	grid *gd
	REAL x

int
ral_gdeqreal(gd, x)
	grid *gd
	REAL x

int
ral_gdnereal(gd, x)
	grid *gd
	REAL x

int
ral_gdcmpreal(gd, x)
	grid *gd
	REAL x

int
ral_gdltinteger(gd, x)
	grid *gd
	REAL x

int
ral_gdgtinteger(gd, x)
	grid *gd
	REAL x

int
ral_gdleinteger(gd, x)
	grid *gd
	INTEGER x

int
ral_gdgeinteger(gd, x)
	grid *gd
	INTEGER x

int
ral_gdeqinteger(gd, x)
	grid *gd
	INTEGER x

int
ral_gdneinteger(gd, x)
	grid *gd
	INTEGER x

int
ral_gdcmpinteger(gd, x)
	grid *gd
	INTEGER x

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
ral_gdminreal(gd, x)
	grid *gd
	REAL x

void
ral_gdmininteger(gd, x)
	grid *gd
	INTEGER x

int
ral_gdmaxreal(gd, x)
	grid *gd
	REAL x

int
ral_gdmaxinteger(gd, x)
	grid *gd
	INTEGER x

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
ral_gdif_then_real(a, b, c)
	grid *a
	grid *b
	REAL c

int 
ral_gdif_then_integer(a, b, c)
	grid *a
	grid *b
	INTEGER c

int 
ral_gdif_then_else_real(a, b, c, d)
	grid *a
	grid *b
	REAL c
	REAL d

int 
ral_gdif_then_else_integer(a, b, c, d)
	grid *a
	grid *b
	INTEGER c
	INTEGER d

int 
ral_gdif_then_gd(a, b, c)
	grid *a
	grid *b
	grid *c

int 
ral_gdzonal_if_then_real(a, b, k, v, n)
	grid *a
	grid *b
	INTEGER *k
	REAL *v
	int n

int 
ral_gdzonal_if_then_integer(a, b, k, v, n)
	grid *a
	grid *b
	INTEGER *k
	INTEGER *v
	int n

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

REAL 
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
ral_gdborders_recursive(gd)
	grid *gd

grid *
ral_gdareas(gd, k)
	grid *gd
	int k

int 
ral_gdconnect(gd) 
	grid *gd

int
ral_gdnumber_of_areas(gd,connectivity)
	grid *gd
	int connectivity

grid *
_ral_gdclip(gd, i1, j1, i2, j2)
	grid *gd
	int i1
	int j1
	int i2
	int j2
	CODE:
	{
		window w;
		w.up_left.i = i1;
		w.up_left.j = j1;
		w.down_right.i = i2;
		w.down_right.j = j2;
		RETVAL = ral_gdclip(gd, w);
	}
  OUTPUT:
    RETVAL

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
_ral_gdline(gd, i1, j1, i2, j2, pen_integer, pen_real)
	grid *gd
	int i1
	int j1
	int i2
	int j2
	INTEGER pen_integer
	REAL pen_real
	CODE:
	{	
		cell c1 = {i1, j1};
		cell c2 = {i2, j2};
		ral_gdline(gd, c1, c2, pen_integer, pen_real);
		RETVAL = 1;
  	}
  OUTPUT:
    RETVAL

int 
_ral_gdfilledrect(gd, i1, j1, i2, j2, pen_integer, pen_real)
	grid *gd
	int i1
	int j1
	int i2
	int j2
	INTEGER pen_integer
	REAL pen_real
	CODE:
	{	
		cell c1 = {i1, j1};
		cell c2 = {i2, j2};
		ral_gdfilledrect(gd, c1, c2, pen_integer, pen_real);
		RETVAL = 1;
  	}
  OUTPUT:
    RETVAL

int 
_ral_gdfilledcircle(gd, i, j, r, r2, pen_integer, pen_real)
	grid *gd
	int i
	int j
	int r
	int r2
	INTEGER pen_integer
	REAL pen_real
	CODE:
	{	
		cell c = {i, j};
		ral_gdfilledcircle(gd, c, r, r2, pen_integer, pen_real);
		RETVAL = 1;
  	}
  OUTPUT:
    RETVAL

AV *
ral_gdget_line(gd, i1, j1, i2, j2)
	grid *gd
	int i1
	int j1
	int i2
	int j2
	CODE:
	{
		static char *fct = "Raster.xs";
		AV *av;
		cell *cells = NULL;
		INTEGER *ivalue = NULL;
		REAL *rvalue = NULL;
		cell c1 = {i1, j1};
		cell c2 = {i2, j2};
		ASSERTM(av = newAV(), ERRSTR_OOM);
		switch (gd->datatype) {
		case INTEGER_GRID: {
			int size;
			if (ral_igdget_line(gd, c1, c2, &cells, &ivalue, &size)) {
				int i;
				for (i=0; i<size; i++) {
					SV *sv;
					ASSERTM(sv = newSViv(cells[i].i),ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSViv(cells[i].j),ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSViv(ivalue[i]),ERRSTR_OOM);
					av_push(av, sv);
				}
			}
		}
		break;
		case REAL_GRID: {			
			int size;
			if (ral_rgdget_line(gd, c1, c2, &cells, &rvalue, &size)) {
				int i;
				for (i=0; i<size; i++) {
					SV *sv;
					ASSERTM(sv = newSViv(cells[i].i),ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSViv(cells[i].j),ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSVnv(rvalue[i]),ERRSTR_OOM);
					av_push(av, sv);
				}
			}
		}
		}
	fail:
		if (cells) free(cells);
		if (ivalue) free(ivalue);
		if (rvalue) free(rvalue);
		RETVAL = av;
  	}
  OUTPUT:
    RETVAL

AV *
ral_gdget_rect(gd, i1, j1, i2, j2)
	grid *gd
	int i1
	int j1
	int i2
	int j2
	CODE:
	{
		static char *fct = "Raster.xs";
		AV *av;
		cell *cells = NULL;
		INTEGER *ivalue = NULL;
		REAL *rvalue = NULL;
		cell c1 = {i1, j1};
		cell c2 = {i2, j2};
		ASSERTM(av = newAV(), ERRSTR_OOM);
		switch (gd->datatype) {
		case INTEGER_GRID: {
			int size;
			if (ral_igdget_rect(gd, c1, c2, &cells, &ivalue, &size)) {
				int i;
				for (i=0; i<size; i++) {
					SV *sv;
					ASSERTM(sv = newSViv(cells[i].i),ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSViv(cells[i].j),ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSViv(ivalue[i]),ERRSTR_OOM);
					av_push(av, sv);
				}
			}
		}
		break;
		case REAL_GRID: {			
			int size;
			if (ral_rgdget_rect(gd, c1, c2, &cells, &rvalue, &size)) {
				int i;
				for (i=0; i<size; i++) {
					SV *sv;
					ASSERTM(sv = newSViv(cells[i].i),ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSViv(cells[i].j),ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSVnv(rvalue[i]),ERRSTR_OOM);
					av_push(av, sv);
				}
			}
		}
		}
	fail:
		if (cells) free(cells);
		if (ivalue) free(ivalue);
		if (rvalue) free(rvalue);
		RETVAL = av;
  	}
  OUTPUT:
    RETVAL

AV *
ral_gdget_circle(gd, i, j, r, r2)
	grid *gd
	int i
	int j
	int r
	int r2
	CODE:
	{
		static char *fct = "Raster.xs";
		AV *av;
		cell *cells = NULL;
		INTEGER *ivalue = NULL;
		REAL *rvalue = NULL;
		cell c;
		c.i = i;
		c.j = j;
		ASSERTM(av = newAV(), ERRSTR_OOM);
		switch (gd->datatype) {
		case INTEGER_GRID: {
			int size;
			if (ral_igdget_circle(gd, c, r, r2, &cells, &ivalue, &size)) {
				int i;
				for (i=0; i<size; i++) {
					SV *sv;
					ASSERTM(sv = newSViv(cells[i].i),ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSViv(cells[i].j),ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSViv(ivalue[i]),ERRSTR_OOM);
					av_push(av, sv);
				}
			}
		}
		break;
		case REAL_GRID: {			
			int size;
			if (ral_rgdget_circle(gd, c, r, r2, &cells, &rvalue, &size)) {
				int i;
				for (i=0; i<size; i++) {
					SV *sv;
					ASSERTM(sv = newSViv(cells[i].i),ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSViv(cells[i].j),ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSVnv(rvalue[i]),ERRSTR_OOM);
					av_push(av, sv);
				}
			}
		}
		}
	fail:
		if (cells) free(cells);
		if (ivalue) free(ivalue);
		if (rvalue) free(rvalue);
		RETVAL = av;
  	}
  OUTPUT:
    RETVAL

int 
_ral_gdfloodfill(gd, i, j, pen_integer, pen_real, connectivity)
	grid *gd
	int i
	int j
	INTEGER pen_integer
	REAL pen_real
	int connectivity
	CODE:
	{	
		cell c = {i, j};
		ral_gdfloodfill(gd, c, pen_integer, pen_real, connectivity);
		RETVAL = 1;
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

color_table *
ral_ctcopy(ct)
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


int 
ral_RGBAgd2png(R, G, B, A, outfile)
	grid *R
	grid *G
	grid *B
	grid *A
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

int 
ral_RGBAgd2png(R, G, B, A, outfile)
	grid *R
	grid *G
	grid *B
	grid *A
	char *outfile

#endif

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
ral_gdplot(gd, device, window, ct, draw, default_width, pap, close)
	grid *gd
	char *device
	int window
	color_table *ct
	int draw
	int default_width
	int pap
	int close
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
ral_gdplot(gd, device, window, ct, draw, default_width, pap, close)
	grid *gd
	char *device
	int window
	color_table *ct
	int draw
	int default_width
	int pap
	int close

#endif

int
ral_gdprint(gd)
	grid *gd

AV *
_ral_gd2list(gd)
	grid *gd
	CODE:
	{
		static char *fct = "Raster.xs";
		AV *av;
		cell *c = NULL;
		INTEGER *ivalue = NULL;
		REAL *rvalue = NULL;
		ASSERTM(av = newAV(), ERRSTR_OOM);
		switch (gd->datatype) {
		case INTEGER_GRID: {
			int size;
			if (ral_igd2list(gd, &c, &ivalue, &size)) {
				int i;
				for (i=0; i<size; i++) {
					SV *sv;
					ASSERTM(sv = newSViv(c[i].i), ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSViv(c[i].j), ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSViv(ivalue[i]), ERRSTR_OOM);
					av_push(av, sv);
				}
				
			}
		}
		break;
		case REAL_GRID: {
			int size;
			if (ral_rgd2list(gd, &c, &rvalue, &size)) {
				int i;
				for (i=0; i<size; i++) {
					SV *sv;
					ASSERTM(sv = newSViv(c[i].i), ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSViv(c[i].j), ERRSTR_OOM);
					av_push(av, sv);
					ASSERTM(sv = newSVnv(rvalue[i]), ERRSTR_OOM);
					av_push(av, sv);
				}
			}
		}
		}
	fail:
		if (c) free(c);
		if (ivalue) free(ivalue);
		if (rvalue) free(rvalue);
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
		static char *fct = "Raster.xs";
		int i, *c = NULL;
		AV *counts;
		ASSERTM(counts = newAV(), ERRSTR_OOM);
		ASSERTM(c = (int *)calloc(n+1,sizeof(int)), ERRSTR_OOM);
		ral_gdhistogram(gd, bin, c, n);
		for (i=0; i<n+1; i++) {
			SV *sv;
			ASSERTM(sv = newSViv(c[i]), ERRSTR_OOM);
			av_push(counts, sv);
		}
	fail:
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
		static char *fct = "Raster.xs";
		hash table = {0, NULL};
		int i;
		HV* h;
		ASSERTM(h = newHV(), ERRSTR_OOM);
		ASSERT(ral_hash_create(&table, 200));
		if (ral_gdcontents(gd, &table))
		for (i = 0; i < table.size; i++) {
			hash_int_item *a = (hash_int_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv;
				ASSERTM(sv = newSViv(a->value), ERRSTR_OOM);
				snprintf(key, 10, "%i", a->key);
				klen = strlen(key);
				hv_store(h, key, klen, sv, 0);
				a = a->next;
			}
		}
	fail:
		ral_hash_destroy(&table);
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
		int i;
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
		int i;
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
		int i;
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
		int i;
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
		int i;
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
		int i;
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
		int *c, i, n;
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
_ral_dijkstra(w, ci, cj)
	grid *w
	int ci
	int cj
	CODE:
	{
		cell c = {ci, cj};
		RETVAL = ral_dijkstra(w, c);
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

