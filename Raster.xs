#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include "gdal.h"

#include "ral_grid.h"
#include "ral_grid_rw.h"
#include "ral_catchment.h"
#include "ral_pixbuf.h"

#include "arrays.h"   /* Pack functions decs */
#include "arrays.c"   /* Pack functions defs */

#define RAL_GRIDPTR "ral_gridPtr"

IV SV2Handle(SV *sv)
{
	if (SvGMAGICAL(sv))
		mg_get(sv);
	if (!sv_isobject(sv)) {
		croak("parameter is not an object");
		return 0;
	}
	SV *tsv = (SV*)SvRV(sv);
	if ((SvTYPE(tsv) != SVt_PVHV)) {
		croak("parameter is not a hashref");
		return 0;
	}
	if (!SvMAGICAL(tsv)) {
		croak("parameter does not have magic");
		return 0;
	}
	MAGIC *mg = mg_find(tsv,'P');
	if (!mg) {
		croak("parameter does not have right kind of magic");
		return 0;
	}
	sv = mg->mg_obj;
	if (!sv_isobject(sv)) {
		croak("parameter does not have really right kind of magic");
		return 0;
	}
	return SvIV((SV*)SvRV(sv));
}

IV SV2Object(SV *sv, char *stash)
{
	if (!sv_isobject(sv)) {
		croak("parameter is not an object");
		return 0;
	}
	sv = (SV*)SvRV(sv);
	if (strcmp(stash,HvNAME((HV*)SvSTASH(sv)))!=0) {
		croak("parameter is not a %s",stash);
		return 0;
	}
	return SvIV(sv);
}


MODULE = Geo::Raster		PACKAGE = Geo::Raster


void
call_g_type_init()
	CODE:
	g_type_init();

int
ral_has_msg()

char *
ral_get_error_msg()

ral_pixbuf *
ral_pixbuf_new(width, height, minX, maxY, pixel_size, bgc1, bgc2, bgc3, bgc4)
	int width
	int height
	double minX
	double maxY
	double pixel_size
	int bgc1
	int bgc2
	int bgc3
	int bgc4
	CODE:
		GDALColorEntry background = {bgc1, bgc2, bgc3, bgc4};
		ral_pixbuf *pb = ral_pixbuf_new(width, height, minX, maxY, pixel_size, background);
		RETVAL = pb;
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_pixbuf *
ral_pixbuf_new_from_grid(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

void 
ral_pixbuf_delete(pb)
	ral_pixbuf *pb

void
ral_pixbuf_save(pb, filename, type, option_keys, option_values)
	ral_pixbuf *pb
	const char *filename
	const char *type
	AV* option_keys
	AV* option_values
	CODE:
		GdkPixbuf *gpb;
		GError *error = NULL;
		int i;
		char **ok;
		char **ov;
		int size = av_len(option_keys)+1;
		gpb = ral_gdk_pixbuf(pb);
		RAL_CHECKM(ok = (char **)calloc(size, sizeof(char *)), ERRSTR_OOM);
		RAL_CHECKM(ov = (char **)calloc(size, sizeof(char *)), ERRSTR_OOM);
		for (i = 0; i < size; i++) {
			STRLEN len;
			SV **s = av_fetch(option_keys, i, 0);
			ok[i] = SvPV(*s, len);
			s = av_fetch(option_values, i, 0);
			ov[i] = SvPV(*s, len);
		}
		gdk_pixbuf_savev(gpb, filename, type, ok, ov, &error);
		fail:
		if (ok) {
			for (i = 0; i < size; i++) {
				if (ok[i]) free (ok[i]);
			}
			free(ok);
		}
		if (ov) {
			for (i = 0; i < size; i++) {
				if (ov[i]) free (ov[i]);
			}
			free(ov);
		}
		if (error) {
			croak(error->message);
			g_error_free(error);
		}
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

AV *
ral_pixbuf_get_world(pb)
	ral_pixbuf *pb
	CODE:
		AV *av = (AV *)sv_2mortal((SV*)newAV());
		av_push(av, newSVnv(pb->world.min.x));
		av_push(av, newSVnv(pb->world.min.y));
		av_push(av, newSVnv(pb->world.max.x));
		av_push(av, newSVnv(pb->world.max.y));
		av_push(av, newSVnv(pb->pixel_size));
		av_push(av, newSViv(pb->width));
		av_push(av, newSViv(pb->height));
		RETVAL = av;
  OUTPUT:
    RETVAL

ral_cell *
ral_cellnew()
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_celldestroy(c)
	ral_cell *c
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

void
ral_gdsetmask(gd, mask)
	ral_grid *gd
	ral_grid *mask

void
ral_gdclearmask(gd)
	ral_grid *gd

ral_grid *
ral_gdgetmask(gd)
	ral_grid *gd

ral_grid *
ral_gdinit(datatype)
	int datatype
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

void
ral_gddestroy(gd)
	ral_grid *gd

ral_grid *
ral_gdnew(datatype, M, N)
	int datatype
	int M
	int N
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_gdnewlike(gd, datatype)
	ral_grid *gd
	int datatype
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

ral_grid *
ral_gdnewcopy(gd, datatype)
	ral_grid *gd
	int datatype
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_gdread_using_GDAL(dataset, band, clip_xmin, clip_ymin, clip_xmax, clip_ymax, cell_size)
	SV *dataset
	int band
	double clip_xmin
	double clip_ymin
	double clip_xmax
	double clip_ymax
	double cell_size
	CODE:
		GDALDatasetH h;
		RAL_CHECK(h = (GDALDatasetH)SV2Handle(dataset));
		ral_rectangle clip_region = {clip_xmin,clip_ymin,clip_xmax,clip_ymax};
		RETVAL = ral_gdread_using_GDAL(h, band, clip_region, cell_size);
		fail:
	OUTPUT:
		RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdwrite(gd, filename)
	ral_grid *gd
	char *filename
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

int
ral_gd_has_data(gd)
	ral_grid *gd

int
ral_gdget_height(gd)
	ral_grid *gd

int
ral_gdget_width(gd)
	ral_grid *gd

int
ral_gdget_datatype(gd)
	ral_grid *gd

SV * 
ral_gdget_nodata_value(gd)
	ral_grid *gd
	CODE:
	{
		SV *sv;
		if (gd->nodata_value) {
			switch (gd->datatype) {
			case RAL_INTEGER_GRID:
				sv = newSViv(RAL_IGD_NODATA_VALUE(gd));
				break;
			case RAL_REAL_GRID:
				sv = newSVnv(RAL_RGD_NODATA_VALUE(gd));
			}
		} else {
			sv = &PL_sv_undef;
		}
		RETVAL = sv;
	}
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdset_integer_nodata_value(gd, nodata_value)
	ral_grid *gd
	RAL_INTEGER nodata_value
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdset_real_nodata_value(gd, nodata_value)
	ral_grid *gd
	RAL_REAL nodata_value
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

double
ral_gdget_cell_size(gd)
	ral_grid *gd

AV *
ral_gdget_world(gd)
	ral_grid *gd
	CODE:
	{
		ral_rectangle xy = ral_gdget_world(gd);
		AV *av = newAV();
		sv_2mortal((SV*)av);
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
ral_gdset_bounds_csnn(gd, cell_size, minX, minY)
	ral_grid *gd
	double cell_size
	double minX
	double minY

void
ral_gdset_bounds_csnx(gd, cell_size, minX, maxY)
	ral_grid *gd
	double cell_size
	double minX
	double maxY

void
ral_gdset_bounds_csxn(gd, cell_size, maxX, minY)
	ral_grid *gd
	double cell_size
	double maxX
	double minY

void
ral_gdset_bounds_csxx(gd, cell_size, maxX, maxY)
	ral_grid *gd
	double cell_size
	double maxX
	double maxY

void
ral_gdset_bounds_nxn(gd, minX, maxX, minY)
	ral_grid *gd
	double minX
	double maxX
	double minY

void
ral_gdset_bounds_nxx(gd, minX, maxX, maxY)
	ral_grid *gd
	double minX
	double maxX
	double maxY

void
ral_gdset_bounds_nnx(gd, minX, minY, maxY)
	ral_grid *gd
	double minX
	double minY
	double maxY

void
ral_gdset_bounds_xnx(gd, maxX, minY, maxY)
	ral_grid *gd
	double maxX
	double minY
	double maxY

void
ral_gdcopy_bounds(from, to)
	ral_grid *from
	ral_grid *to

AV *
ral_gdpoint2cell(gd, px, py)
	ral_grid *gd
	double px
	double py
	CODE:
	{
		ral_point p = {px,py};
		ral_cell c = ral_gdpoint2cell(gd, p);
		AV *av = newAV();
		sv_2mortal((SV*)av);
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
ral_gdcell2point(gd, ci, cj)
	ral_grid *gd
	int ci
	int cj
	CODE:
	{
		ral_cell c = {ci,cj};
		ral_point p = ral_gdcell2point(gd, c);
		AV *av = newAV();
		sv_2mortal((SV*)av);
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
ral_gdget(gd, ci, cj)
	ral_grid *gd
	int ci
	int cj
	CODE:
	{
		ral_cell c = {ci,cj};
		SV *sv;		
		if (gd->data AND RAL_GD_CELL_IN(gd, c)) {
			if (gd->datatype == RAL_REAL_GRID) {
				RAL_REAL x = RAL_RGD_CELL(gd, c);
				if ((gd->nodata_value) AND (x == RAL_RGD_NODATA_VALUE(gd)))
					sv = &PL_sv_undef;
				else
					sv = newSVnv(x);
			} else {
				RAL_INTEGER x = RAL_IGD_CELL(gd, c);
				if ((gd->nodata_value) AND (x == RAL_IGD_NODATA_VALUE(gd)))
					sv = &PL_sv_undef;
				else
					sv = newSViv(x);
			}
		} else {
			sv = &PL_sv_undef;
		}
		RETVAL = sv;
	}
  OUTPUT:
    RETVAL

void
ral_gdset_real(gd, ci, cj, x)
	ral_grid *gd
	int ci
	int cj
	RAL_REAL x
	CODE:
	{
		ral_cell c = {ci,cj};
		ral_gdset_real(gd, c, x);
	}
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

void
ral_gdset_integer(gd, ci, cj, x)
	ral_grid *gd
	int ci
	int cj
	RAL_INTEGER x
	CODE:
	{
		ral_cell c = {ci,cj};
		ral_gdset_integer(gd, c, x);
	}
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

void
ral_gdset_nodata(gd, ci, cj)
	ral_grid *gd
	int ci
	int cj
	CODE:
	{
		ral_cell c = {ci,cj};
		ral_gdset_nodata(gd, c);
	}
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());


NO_OUTPUT int
ral_gdset_minmax(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

AV *
ral_gdget_minmax(gd)
	ral_grid *gd
	CODE:
	{
		AV *av = newAV();
		sv_2mortal((SV*)av);
		switch (gd->datatype) {
		case RAL_INTEGER_GRID: {
			av_push(av, newSViv(RAL_IGD_VALUE_RANGE(gd)->min));
			av_push(av, newSViv(RAL_IGD_VALUE_RANGE(gd)->max));
		}
		break;
		case RAL_REAL_GRID: {
			av_push(av, newSVnv(RAL_RGD_VALUE_RANGE(gd)->min));
			av_push(av, newSVnv(RAL_RGD_VALUE_RANGE(gd)->max));
		}
		}
		RETVAL = av;
	}
  OUTPUT:
    RETVAL

NO_OUTPUT int
ral_gdset_all_integer(gd, x)
	ral_grid *gd
	RAL_INTEGER x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdset_all_real(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdset_all_nodata(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gddata(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdnot(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdandgd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdorgd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdaddreal(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdaddinteger(gd, x)
	ral_grid *gd
	RAL_INTEGER x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdaddgd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdsubgd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdmultreal(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdmultinteger(gd, x)
	ral_grid *gd
	RAL_INTEGER x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdmultgd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gddivreal(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gddivinteger(gd, x)
	ral_grid *gd
	RAL_INTEGER x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_realdivgd(x, gd)
	RAL_REAL x
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_integerdivgd(x, gd)
	RAL_INTEGER x
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gddivgd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdmodulussv(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_svmodulusgd(x, gd)
	RAL_INTEGER x
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdmodulusgd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdpowerreal(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_realpowergd(x, gd)
	RAL_REAL x
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdpowergd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdabs(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdacos(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdatan(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdatan2(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdceil(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdcos(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdcosh(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdexp(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdfloor(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdlog(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdlog10(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdsin(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdsinh(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdsqrt(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdtan(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdtanh(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_gdround(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

NO_OUTPUT int
ral_gdltreal(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdgtreal(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdlereal(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdgereal(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdeqreal(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdnereal(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdcmpreal(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdltinteger(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdgtinteger(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdleinteger(gd, x)
	ral_grid *gd
	RAL_INTEGER x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdgeinteger(gd, x)
	ral_grid *gd
	RAL_INTEGER x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdeqinteger(gd, x)
	ral_grid *gd
	RAL_INTEGER x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdneinteger(gd, x)
	ral_grid *gd
	RAL_INTEGER x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdcmpinteger(gd, x)
	ral_grid *gd
	RAL_INTEGER x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdltgd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdgtgd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdlegd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdgegd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdeqgd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdnegd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdcmpgd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdminreal(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdmininteger(gd, x)
	ral_grid *gd
	RAL_INTEGER x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdmaxreal(gd, x)
	ral_grid *gd
	RAL_REAL x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdmaxinteger(gd, x)
	ral_grid *gd
	RAL_INTEGER x
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdmingd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdmaxgd(gd1, gd2)
	ral_grid *gd1
	ral_grid *gd2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_gdcross(a, b)
	ral_grid *a
	ral_grid *b
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

NO_OUTPUT int
ral_gdif_then_real(a, b, c)
	ral_grid *a
	ral_grid *b
	RAL_REAL c
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdif_then_integer(a, b, c)
	ral_grid *a
	ral_grid *b
	RAL_INTEGER c
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdif_then_else_real(a, b, c, d)
	ral_grid *a
	ral_grid *b
	RAL_REAL c
	RAL_REAL d
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdif_then_else_integer(a, b, c, d)
	ral_grid *a
	ral_grid *b
	RAL_INTEGER c
	RAL_INTEGER d
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdif_then_gd(a, b, c)
	ral_grid *a
	ral_grid *b
	ral_grid *c
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdzonal_if_then_real(a, b, k, v, n)
	ral_grid *a
	ral_grid *b
	RAL_INTEGER *k
	RAL_REAL *v
	int n
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdzonal_if_then_integer(a, b, k, v, n)
	ral_grid *a
	ral_grid *b
	RAL_INTEGER *k
	RAL_INTEGER *v
	int n
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdapplytempl(gd, templ, new_val)
	ral_grid *gd
	int *templ
	int new_val
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdmap(gd, s, d, n)
	ral_grid *gd
	int *s
	int *d
	int n
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

double
gdzonesize(gd, i, j)
	ral_grid *gd
	int i
	int j
	CODE:
	{	
		ral_cell c = {i, j};
		RETVAL = ral_gdzonesize(gd, c);
  	}
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_gdborders(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

ral_grid *
ral_gdborders_recursive(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

ral_grid *
ral_gdareas(gd, k)
	ral_grid *gd
	int k
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

NO_OUTPUT int
ral_gdconnect(gd) 
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdnumber_of_areas(gd,connectivity)
	ral_grid *gd
	int connectivity
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_gdclip(gd, i1, j1, i2, j2)
	ral_grid *gd
	int i1
	int j1
	int i2
	int j2
	CODE:
	{
		ral_window w;
		ral_grid *g;
		w.up_left.i = i1;
		w.up_left.j = j1;
		w.down_right.i = i2;
		w.down_right.j = j2;
		RETVAL = ral_gdclip(gd, w);
			
	}
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_gdjoin(g1, g2)
	ral_grid *g1
	ral_grid *g2
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

ral_grid *
ral_gdtransform(gd, tr, M, N, pick, value)
	ral_grid *gd
	double *tr
	int M
	int N
	int pick
	int value
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());


void
ral_gdline(gd, i1, j1, i2, j2, pen_integer, pen_real)
	ral_grid *gd
	int i1
	int j1
	int i2
	int j2
	RAL_INTEGER pen_integer
	RAL_REAL pen_real
	CODE:
	{	
		ral_cell c1 = {i1, j1};
		ral_cell c2 = {i2, j2};
		ral_gdline(gd, c1, c2, pen_integer, pen_real);
  	}
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

void
ral_gdfilledrect(gd, i1, j1, i2, j2, pen_integer, pen_real)
	ral_grid *gd
	int i1
	int j1
	int i2
	int j2
	RAL_INTEGER pen_integer
	RAL_REAL pen_real
	CODE:
	{	
		ral_cell c1 = {i1, j1};
		ral_cell c2 = {i2, j2};
		ral_gdfilledrect(gd, c1, c2, pen_integer, pen_real);
  	}
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

void
ral_gdfilledcircle(gd, i, j, r, r2, pen_integer, pen_real)
	ral_grid *gd
	int i
	int j
	int r
	int r2
	RAL_INTEGER pen_integer
	RAL_REAL pen_real
	CODE:
	{	
		ral_cell c = {i, j};
		ral_gdfilledcircle(gd, c, r, r2, pen_integer, pen_real);
  	}
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

void 
ral_gdfilledpolygon(gd, g, pen_integer, pen_real)
	ral_grid *gd
	ral_geometry *g
	RAL_INTEGER pen_integer
	RAL_REAL pen_real
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

AV *
ral_gdget_line(gd, i1, j1, i2, j2)
	ral_grid *gd
	int i1
	int j1
	int i2
	int j2
	CODE:
	{
		AV *av;
		ral_cell *cells = NULL;
		RAL_INTEGER *ivalue = NULL;
		RAL_REAL *rvalue = NULL;
		ral_cell c1 = {i1, j1};
		ral_cell c2 = {i2, j2};
		av = newAV();
		sv_2mortal((SV*)av);
		switch (gd->datatype) {
		case RAL_INTEGER_GRID: {
			int size;
			RAL_CHECK(ral_igdget_line(gd, c1, c2, &cells, &ivalue, &size));
			int i;
			for (i=0; i<size; i++) {
				av_push(av, newSViv(cells[i].i));
				av_push(av, newSViv(cells[i].j));
				av_push(av, newSViv(ivalue[i]));
			}
		}
		break;
		case RAL_REAL_GRID: {			
			int size;
			RAL_CHECK(ral_rgdget_line(gd, c1, c2, &cells, &rvalue, &size));
			int i;
			for (i=0; i<size; i++) {
				av_push(av, newSViv(cells[i].i));
				av_push(av, newSViv(cells[i].j));
				av_push(av, newSVnv(rvalue[i]));
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

AV *
ral_gdget_rect(gd, i1, j1, i2, j2)
	ral_grid *gd
	int i1
	int j1
	int i2
	int j2
	CODE:
	{
		AV *av;
		ral_cell *cells = NULL;
		RAL_INTEGER *ivalue = NULL;
		RAL_REAL *rvalue = NULL;
		ral_cell c1 = {i1, j1};
		ral_cell c2 = {i2, j2};
		av = newAV();
		sv_2mortal((SV*)av);
		switch (gd->datatype) {
		case RAL_INTEGER_GRID: {
			int size;
			RAL_CHECK(ral_igdget_rect(gd, c1, c2, &cells, &ivalue, &size));
			int i;
			for (i=0; i<size; i++) {
				av_push(av, newSViv(cells[i].i));
				av_push(av, newSViv(cells[i].j));
				av_push(av, newSViv(ivalue[i]));
			}
		}
		break;
		case RAL_REAL_GRID: {			
			int size;
			RAL_CHECK(ral_rgdget_rect(gd, c1, c2, &cells, &rvalue, &size));
			int i;
			for (i=0; i<size; i++) {
				av_push(av, newSViv(cells[i].i));
				av_push(av, newSViv(cells[i].j));
				av_push(av, newSVnv(rvalue[i]));
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

AV *
ral_gdget_circle(gd, i, j, r, r2)
	ral_grid *gd
	int i
	int j
	int r
	int r2
	CODE:
	{
		AV *av;
		ral_cell *cells = NULL;
		RAL_INTEGER *ivalue = NULL;
		RAL_REAL *rvalue = NULL;
		ral_cell c;
		c.i = i;
		c.j = j;
		av = newAV();
		sv_2mortal((SV*)av);
		switch (gd->datatype) {
		case RAL_INTEGER_GRID: {
			int size;
			RAL_CHECK(ral_igdget_circle(gd, c, r, r2, &cells, &ivalue, &size));
			int i;
			for (i=0; i<size; i++) {
				av_push(av, newSViv(cells[i].i));
				av_push(av, newSViv(cells[i].j));
				av_push(av, newSViv(ivalue[i]));
			}
		}
		break;
		case RAL_REAL_GRID: {			
			int size;
			RAL_CHECK(ral_rgdget_circle(gd, c, r, r2, &cells, &rvalue, &size));
			int i;
			for (i=0; i<size; i++) {
				av_push(av, newSViv(cells[i].i));
				av_push(av, newSViv(cells[i].j));
				av_push(av, newSVnv(rvalue[i]));
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

void
ral_gdfloodfill(gd, i, j, pen_integer, pen_real, connectivity)
	ral_grid *gd
	int i
	int j
	RAL_INTEGER pen_integer
	RAL_REAL pen_real
	int connectivity
	CODE:
	{	
		ral_cell c = {i, j};
		ral_gdfloodfill(gd, c, pen_integer, pen_real, connectivity);
  	}
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_RGBAgd2png(R, G, B, A, outfile)
	ral_grid *R
	ral_grid *G
	ral_grid *B
	ral_grid *A
	char *outfile
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdprint(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

AV *
ral_gd2list(gd)
	ral_grid *gd
	CODE:
	{
		AV *av;
		ral_cell *c = NULL;
		RAL_INTEGER *ivalue = NULL;
		RAL_REAL *rvalue = NULL;
		av = newAV();
		sv_2mortal((SV*)av);
		switch (gd->datatype) {
		case RAL_INTEGER_GRID: {
			size_t size;
			if (ral_igd2list(gd, &c, &ivalue, &size)) {
				int i;
				for (i=0; i<size; i++) {
					SV *sv;
					sv = newSViv(c[i].i);
					av_push(av, sv);
					sv = newSViv(c[i].j);
					av_push(av, sv);
					sv = newSViv(ivalue[i]);
					av_push(av, sv);
				}
				
			}
		}
		break;
		case RAL_REAL_GRID: {
			size_t size;
			if (ral_rgd2list(gd, &c, &rvalue, &size)) {
				int i;
				for (i=0; i<size; i++) {
					SV *sv;
					sv = newSViv(c[i].i);
					av_push(av, sv);
					sv = newSViv(c[i].j);
					av_push(av, sv);
					sv = newSVnv(rvalue[i]);
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

AV *
gdhistogram(gd, bin, n)
	ral_grid *gd
	double *bin
	int n
	CODE:
	{
		int i, *c = NULL;
		AV *counts = newAV();
		sv_2mortal((SV*)counts);
		RAL_CHECKM(c = (int *)calloc(n+1,sizeof(int)), ERRSTR_OOM);		
		ral_gdhistogram(gd, bin, c, n);
		for (i=0; i<n+1; i++) {
			av_push(counts, newSViv(c[i]));
		}
	fail:
		if (c) free(c);
		RETVAL = counts;
	}
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

HV *
gdcontents(gd)
	ral_grid *gd
	CODE:
	{
		ral_hash table = {0, NULL};
		int i;
		HV *h = newHV();
		sv_2mortal((SV*)h);
		RAL_CHECK(ral_hash_create(&table, 200));
		if (ral_gdcontents(gd, &table))
		for (i = 0; i < table.size; i++) {
			ral_hash_int_item *a = (ral_hash_int_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSViv(a->value);
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

HV *
gdzonalcount(gd, zones)
	ral_grid *gd
	ral_grid *zones
	CODE:
	{
		ral_hash table = {0, NULL};
		int i;
		HV* h = newHV();
		sv_2mortal((SV*)h);
		RAL_CHECK(ral_hash_create(&table, 200));
		RAL_CHECK(ral_gdzonalcount(gd, zones, &table));
		for (i = 0; i < table.size; i++) {
			ral_hash_int_item *a = (ral_hash_int_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSViv(a->value);
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

HV *
gdzonalsum(gd, zones)
	ral_grid *gd
	ral_grid *zones
	CODE:
	{
		ral_hash table = {0, NULL};
		int i;
		HV* h = newHV();
		sv_2mortal((SV*)h);
		RAL_CHECK(ral_hash_create(&table, 200));
		RAL_CHECK(ral_gdzonalsum(gd, zones, &table));
		for (i = 0; i < table.size; i++) {
			ral_hash_double_item *a = (ral_hash_double_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSVnv(a->value);
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

HV *
gdzonalmin(gd, zones)
	ral_grid *gd
	ral_grid *zones
	CODE:
	{
		ral_hash table = {0, NULL};
		int i;
		HV* h = newHV();		
		sv_2mortal((SV*)h);
		RAL_CHECK(ral_hash_create(&table, 200));
		RAL_CHECK(ral_gdzonalmin(gd, zones, &table));
		for (i = 0; i < table.size; i++) {
			ral_hash_double_item *a = (ral_hash_double_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSVnv(a->value);
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

HV *
gdzonalmax(gd, zones)
	ral_grid *gd
	ral_grid *zones
	CODE:
	{
		ral_hash table;
		int i;
		HV* h = newHV();
		sv_2mortal((SV*)h);
		RAL_CHECK(ral_hash_create(&table, 200));
		RAL_CHECK(ral_gdzonalmax(gd, zones, &table));
		for (i = 0; i < table.size; i++) {
			ral_hash_double_item *a = (ral_hash_double_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSVnv(a->value);
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

HV *
gdzonalmean(gd, zones)
	ral_grid *gd
	ral_grid *zones
	CODE:
	{
		ral_hash table;
		int i;
		HV* h = newHV();	
		sv_2mortal((SV*)h);
		RAL_CHECK(ral_hash_create(&table, 200));
		RAL_CHECK(ral_gdzonalmean(gd, zones, &table));
		for (i = 0; i < table.size; i++) {
			ral_hash_double_item *a = (ral_hash_double_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSVnv(a->value);
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

HV *
gdzonalvariance(gd, zones)
	ral_grid *gd
	ral_grid *zones
	CODE:
	{
		ral_hash table;
		int i;
		HV* h = newHV();
		sv_2mortal((SV*)h);
		RAL_CHECK(ral_hash_create(&table, 200));
		RAL_CHECK(ral_gdzonalvariance(gd, zones, &table));
		for (i = 0; i < table.size; i++) {
			ral_hash_double_item *a = (ral_hash_double_item *)table.table[i];
			while (a) {
				U32 klen;
				char key[10];
				SV *sv = newSVnv(a->value);
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_gdgrowzones(zones, grow, connectivity)
	ral_grid *zones
	ral_grid *grow
	int connectivity
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

HV *
gdneighbors(gd)
	ral_grid *gd
	CODE:
	{
		ral_hash **b = NULL;
		int *c = NULL, i, n;
		HV* h = newHV();		
		sv_2mortal((SV*)h);
		RAL_CHECK(ral_gdneighbors(gd, &b, &c, &n));
		for (i = 0; i < n; i++) {
			char key[10];
			AV*  av = newAV();
			U32 klen;
			int j;
			snprintf(key, 10, "%i", c[i]);
			klen = strlen(key);
			for (j = 0; j < b[i]->size; j++) {
				ral_hash_int_item *a = (ral_hash_int_item *)b[i]->table[j];
				while (a) {
					SV *sv = newSViv(a->key);
					sv;
					av_push(av, sv);
					a = a->next;
				}				
			}
			hv_store(h, key, klen, newRV_inc((SV*) av), 0);
		}
	fail:
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_gdbufferzone(gd, z, w)
	ral_grid *gd
	int z
	double w
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

long
ral_gdcount(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

double 
ral_gdsum(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

double 
ral_gdmean(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

double 
ral_gdvariance(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_gddistances(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

ral_grid *
ral_gddirections(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

ral_grid *
ral_gdnn(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

HV *
gdzones(gd, z)
	ral_grid *gd
	ral_grid *z
	CODE:
	{
		double **tot = NULL;
		int *c = NULL;
		int *k = NULL;
		int i, n;
		HV* hv = newHV();
		sv_2mortal((SV*)hv);
		if (ral_gdzones(gd, z, &tot, &c, &k, &n)) {
			for (i = 0; i < n; i++) if (k[i]) {
				int j;
				char key[10];
				U32 klen;
				AV *av;
				SV **sv = (SV **)calloc(k[i], sizeof(SV *));
				sv;
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
	fail:
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_dijkstra(w, ci, cj)
	ral_grid *w
	int ci
	int cj
	CODE:
	{
		ral_cell c = {ci, cj};
		RETVAL = ral_dijkstra(w, c);			
	}
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());


void 
ral_render_igrid(pb, gd, alpha, palette_type, min, max, color_table)
	ral_pixbuf *pb
	ral_grid *gd
	SV *alpha
	int palette_type
	RAL_INTEGER min
	RAL_INTEGER max
	SV *color_table
	CODE:
		GDALColorTableH ctH;
		RAL_CHECK(ctH = (GDALColorTableH)SV2Handle(color_table));
		short a = 255;
		ral_grid *a_gd = NULL;
		if (SvIOK(alpha))
			a = SvIV(alpha);
		else if (sv_isobject(alpha)) {
			RAL_CHECK(a_gd = (ral_grid*)SV2Object(alpha, RAL_GRIDPTR));
		} else {
			croak("alpha is not integer nor a grid");
			goto fail;
		}
		ral_render_igrid(pb, gd, a, a_gd, palette_type, min, max, ctH);
		fail:
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());


void 
ral_render_rgrid(pb, gd, alpha, palette_type, min, max)
	ral_pixbuf *pb
	ral_grid *gd
	SV *alpha
	int palette_type
	RAL_REAL min
	RAL_REAL max
	CODE:
		short a = 255;
		ral_grid *a_gd = NULL;
		if (SvIOK(alpha))
			a = SvIV(alpha);
		else if (sv_isobject(alpha)) {
			RAL_CHECK(a_gd = (ral_grid*)SV2Object(alpha, RAL_GRIDPTR));
		} else {
			croak("alpha is not integer nor a grid");
			goto fail;
		}
		ral_render_rgrid(pb, gd, a, a_gd, palette_type, min, max);
		fail:
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

void 
ral_render_grids(pb, b1, b2, b3, alpha, color_interpretation)
	ral_pixbuf *pb
	ral_grid *b1
	ral_grid *b2
	ral_grid *b3
	SV *alpha
	int color_interpretation
	CODE:
		short a = 255;
		ral_grid *a_gd = NULL;
		if (SvIOK(alpha))
			a = SvIV(alpha);
		else if (sv_isobject(alpha)) {
			RAL_CHECK(a_gd = (ral_grid*)SV2Object(alpha, RAL_GRIDPTR));
		} else {
			croak("alpha is not integer nor a grid");
			goto fail;
		}
		ral_render_grids(pb, b1, b2, b3, a, a_gd, color_interpretation);
		fail:
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());


ral_grid *
ral_dem2aspect(dem)
	ral_grid *dem
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

ral_grid *
ral_dem2slope(dem, z_factor)
	ral_grid *dem
	double z_factor
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

ral_grid *
ral_dem2fdg(dem, method)
	ral_grid *dem
	int method
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

void 
ral_render_fdg(pb, fdg, c1, c2, c3, c4)
	ral_pixbuf *pb
	ral_grid *fdg
	int c1
	int c2
	int c3
	int c4
	CODE:
		GDALColorEntry clr = {c1,c2,c3,c4};
		ral_render_fdg(pb, fdg, clr);
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());			

AV *
find_outlet(fdg, i, j)
	ral_grid *fdg
	int i
	int j
	CODE:
	{
		ral_cell c = {i,j};
		c = ral_find_outlet(fdg, c);
		AV *av = newAV();
		sv_2mortal((SV*)av);
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
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_dem2ucg(dem) 
	ral_grid *dem
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

NO_OUTPUT int
ral_fdg_fixflats1(fdg, dem)
	ral_grid *fdg
	ral_grid *dem
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_fdg_fixflats2(fdg, dem)
	ral_grid *fdg
	ral_grid *dem
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_dem_fillpits(dem, z_limit)
	ral_grid *dem
	double z_limit
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_dem_cutpeaks(dem, z_limit)
	ral_grid *dem
	double z_limit
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_dem_depressions(dem, fdg, inc_m)
	ral_grid *dem
	ral_grid *fdg
	int inc_m
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

int
ral_dem_filldepressions(dem, fdg)
	ral_grid *dem
	ral_grid *fdg
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_dem_breach(dem, fdg, limit)
	ral_grid *dem
	ral_grid *fdg
	int limit
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

int
ral_fdg_fixpits(fdg, dem)
	ral_grid *fdg
	ral_grid *dem
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_water_route(water, dem, fdg, flow, k, d, f, r)
	ral_grid *water
	ral_grid *dem
	ral_grid *fdg
	ral_grid *flow
	ral_grid *k
	ral_grid *d
	int f
	double r
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
fdg2uag_a(fdg)
	ral_grid *fdg
	CODE:
		RETVAL = ral_fdg2uag(fdg, NULL);
  OUTPUT:	
	RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
fdg2uag_b(fdg, load)
	ral_grid *fdg
	ral_grid *load
	CODE:
		RETVAL = ral_fdg2uag(fdg, load);
  OUTPUT:	
	RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_fdg_distance_to_pit(fdg, steps)
	ral_grid *fdg
	int steps
	CODE:
		RETVAL = ral_fdg_distance_to_channel(fdg, NULL, steps);
  OUTPUT:	
	RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_fdg_distance_to_channel(fdg, streams, int steps)
	ral_grid *fdg
	ral_grid *streams
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

ral_grid *
ral_dem2uag(dem, fdg, recursion) 
	ral_grid *dem
	ral_grid *fdg
	int recursion
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

ral_grid *
ral_dem2dag(dem, fdg)
	ral_grid *dem
	ral_grid *fdg
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

long
ral_fdg_catchment(fdg, mark, i, j, m)
	ral_grid *fdg
	ral_grid *mark
	int i
	int j
	int m
	CODE:
		pour_point_struct pp;
		ral_cell c = {i, j};
		RAL_CHECK(ral_init_pour_point_struct(&pp, fdg, NULL, mark));
		if (!RAL_GD_CELL_IN(fdg, c)) {
			croak("fdg_catchment: the cell %i,%i is not within FDG\n",i,j);
		} else {
			RETVAL = ral_mark_upslope_cells(&pp, c, m);
		}
		fail:
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

ral_grid *
ral_streams_subcatchments(streams, fdg, i, j)
	ral_grid *streams
	ral_grid *fdg
	int i
	int j
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());
			

NO_OUTPUT int
ral_streams_number(streams, fdg, i, j, sid0)
	ral_grid *streams
	ral_grid *fdg
	int i
	int j
	int sid0
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_fdg_killoutlets(fdg, lakes, uag)
	ral_grid *fdg
	ral_grid *lakes
	ral_grid *uag
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
ral_streams_prune(streams, fdg, lakes, i, j, min_l)
	ral_grid *streams
	ral_grid *fdg
	ral_grid *lakes
	int i
	int j
	double min_l
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

NO_OUTPUT int
streams_prune(streams, fdg, i, j, min_l)
	ral_grid *streams
	ral_grid *fdg
	int i
	int j
	double min_l
	CODE:
	{
		ral_streams_prune(streams, fdg, NULL, i, j, min_l);
	}
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());



NO_OUTPUT int
ral_streams_break(streams, fdg, lakes, nsid)
	ral_grid *streams
	ral_grid *fdg
	ral_grid *lakes
	int nsid
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

HV *
ral_ws_subcatchments(sheds, streams, fdg, lakes, i, j, headwaters)
	ral_grid *sheds
	ral_grid *streams
	ral_grid *fdg
	ral_grid *lakes
	int i
	int j
	int headwaters
	CODE:
	{
		ws w;
		HV *h = newHV();
		sv_2mortal((SV*)h);
		RAL_CHECK(ral_ws_subcatchments(&w, sheds, streams, fdg, lakes, i, j, headwaters));
		for (i = 0; i < w.n; i++) {
			char key[21];
			U32 klen;
			snprintf(key, 20, "%i,%i", w.down[i].i, w.down[i].j);
			klen = strlen(key);
			SV *sv = newSVpv(key, klen);
			snprintf(key, 20, "%i,%i", w.outlet[i].i, w.outlet[i].j);
			klen = strlen(key);
			hv_store(h, key, klen, sv, 0);
		}
	fail:
		ral_wsempty(&w);
		RETVAL = h;
	}
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_error_msg());

