DROP TABLE alt_data_10hz;
CREATE TABLE alt_data_10hz
(
  id_sat char(3),
  lon float4 NOT NULL,
  lat float4 NOT NULL,
  alt float4 NOT NULL,
  iono_cor float4,
  iono_dor float4,
  dry_cor float4,
  wet_cor float4,
  wet1_cor float4,
  wet2_cor float4,
  wet_h float4,
  h_geo float4,
  h_sat float4,
  h_pol float4,
  inv_bar float4,
  date_time timestamp NOT NULL,
  alt_point geometry NOT NULL,
  id_cycle int4 NOT NULL,
  id_track int4 NOT NULL,
  CONSTRAINT enforce_dims_alt_point CHECK (ndims(alt_point) = 2),
  CONSTRAINT enforce_geotype_alt_point CHECK (geometrytype(alt_point) = 'POINT'::text OR alt_point IS NULL),
  CONSTRAINT enforce_srid_alt_point CHECK (srid(alt_point) = 32652)
) 
WITHOUT OIDS;
ALTER TABLE alt_data_10hz OWNER TO postgres;
COMMENT ON TABLE alt_data_10hz IS 'Ёта таблица содержит временные данные, сбрасываемые сюда программой.
ѕосле исползовани€ - очистить таблицу "delete from alt_data"';

DROP TABLE alt_data_1hz;
CREATE TABLE alt_data_1hz
(
  id_sat char(3),
  lon float4 NOT NULL,
  lat float4 NOT NULL,
  alt float4 NOT NULL,
  iono_cor float4,
  iono_dor float4,
  dry_cor float4,
  wet_cor float4,
  wet1_cor float4,
  wet2_cor float4,
  wet_h float4,
  h_geo float4,
  h_sat float4,
  h_pol float4,
  inv_bar float4,
  date_time timestamp NOT NULL,
  alt_point geometry NOT NULL,
  id_cycle int4 NOT NULL,
  id_track int4 NOT NULL,
  CONSTRAINT enforce_dims_alt_point CHECK (ndims(alt_point) = 2),
  CONSTRAINT enforce_geotype_alt_point CHECK (geometrytype(alt_point) = 'POINT'::text OR alt_point IS NULL),
  CONSTRAINT enforce_srid_alt_point CHECK (srid(alt_point) = 32652)
) 
WITHOUT OIDS;
ALTER TABLE alt_data_1hz OWNER TO postgres;
COMMENT ON TABLE alt_data_1hz IS 'Ёта таблица содержит временные данные, сбрасываемые сюда программой.
ѕосле исползовани€ - очистить таблицу "delete from alt_data';

DROP TABLE points_in_regions_10hz;
CREATE TABLE points_in_regions_10hz
(
  id_sat char(3),
  reg_numb int4 NOT NULL,
  alt float4 NOT NULL,
  lon float4 NOT NULL,
  lat float4 NOT NULL,
  date_time timestamp NOT NULL,
  id_cycle int4 NOT NULL,
  id_track int4 NOT NULL,
  alt_point geometry NOT NULL,
  CONSTRAINT enforce_dims_alt_point CHECK (ndims(alt_point) = 2),
  CONSTRAINT enforce_geotype_alt_point CHECK (geometrytype(alt_point) = 'POINT'::text OR alt_point IS NULL),
  CONSTRAINT enforce_srid_alt_point CHECK (srid(alt_point) = 32652)
) 
WITHOUT OIDS;
ALTER TABLE points_in_regions_10hz OWNER TO postgres;
COMMENT ON TABLE points_in_regions_10hz IS 'Ёта таблица содержит данные по регионам с частотой 10√ц';

DROP TABLE points_in_regions_1hz;
CREATE TABLE points_in_regions_1hz
(
  id_sat char(3),
  reg_numb int4 NOT NULL,
  alt float4 NOT NULL,
  lon float4 NOT NULL,
  lat float4 NOT NULL,
  date_time timestamp NOT NULL,
  id_cycle int4 NOT NULL,
  id_track int4 NOT NULL,
  alt_point geometry NOT NULL,
  CONSTRAINT enforce_dims_alt_point CHECK (ndims(alt_point) = 2),
  CONSTRAINT enforce_geotype_alt_point CHECK (geometrytype(alt_point) = 'POINT'::text OR alt_point IS NULL),
  CONSTRAINT enforce_srid_alt_point CHECK (srid(alt_point) = 32652)
) 
WITHOUT OIDS;
ALTER TABLE points_in_regions_1hz OWNER TO postgres;
COMMENT ON TABLE points_in_regions_1hz IS 'Ёта таблица содержит данные по регионам с частотой 1√ц';

DROP TABLE average_data;
CREATE TABLE average_data
(
  id_sat char(3),
  reg_numb int4 NOT NULL,
  alt float4,
  alt_m float4,
  lon float4 NOT NULL,
  lat float4 NOT NULL,
  date_time timestamp,
  id_cycle int4 NOT NULL,
  id_track int4 NOT NULL,
  alt_1hz float4,
  deviation float4,
  alt_point geometry NOT NULL,
  CONSTRAINT enforce_dims_alt_point CHECK (ndims(alt_point) = 2),
  CONSTRAINT enforce_geotype_alt_point CHECK (geometrytype(alt_point) = 'POINT'::text OR alt_point IS NULL),
  CONSTRAINT enforce_srid_alt_point CHECK (srid(alt_point) = -1)
) 
WITHOUT OIDS;
ALTER TABLE average_data OWNER TO postgres;
COMMENT ON TABLE average_data IS 'Ёта таблица содержит усредненные обработанные данные по регионам';

DROP TABLE filter_data;
CREATE TABLE filter_data
(
  id_sat char(3),
  reg_numb int4 NOT NULL,
  alt float4,
  alt_m float4,
  lon float4 NOT NULL,
  lat float4 NOT NULL,
  date_time timestamp,
  id_cycle int4 NOT NULL,
  id_track int4 NOT NULL,
  alt_point geometry NOT NULL,
  CONSTRAINT enforce_dims_alt_point CHECK (ndims(alt_point) = 2),
  CONSTRAINT enforce_geotype_alt_point CHECK (geometrytype(alt_point) = 'POINT'::text OR alt_point IS NULL),
  CONSTRAINT enforce_srid_alt_point CHECK (srid(alt_point) = -1)
) 
WITHOUT OIDS;
ALTER TABLE filter_data OWNER TO postgres;
COMMENT ON TABLE filter_data IS 'Ёта таблица содержит итоговые данные по регионам';
