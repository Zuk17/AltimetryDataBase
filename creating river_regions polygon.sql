DROP TABLE river_regions;
CREATE TABLE river_regions
(
  reg_numb int4 NOT NULL,
  reg_coord geometry NOT NULL,
  riv_name char(20) NOT NULL,
  sity char(40),
  sigma float4,
  avg float4,
  CONSTRAINT enforce_dims_reg_coord CHECK (ndims(reg_coord) = 2),
  CONSTRAINT enforce_geotype_reg_coord CHECK (geometrytype(reg_coord) = 'POLYGON'::text OR reg_coord IS NULL),
  CONSTRAINT enforce_srid_reg_coord CHECK (srid(reg_coord) = 32652)
) 
WITHOUT OIDS;
ALTER TABLE river_regions OWNER TO postgres;
COMMENT ON TABLE river_regions IS 'Эта таблица содержит усредненные обработанные данные по регионам';

delete from river_regions;
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (0,GeomFromText('POLYGON((120.8210 53.2760,120.8420 53.2790,120.8428 53.2727,120.8236 53.2694,120.8210 53.2760))',32652),'Амур','Покровка');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (1,GeomFromText('POLYGON((123.25 53.56,123.26 53.56,123.27 53.56,123.25 53.55,123.25 53.56))',32652),'Амур','Джалинда,Покровка');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (2,GeomFromText('POLYGON((123.34 53.55,123.35 53.54,123.34 53.54,123.33 53.55,123.34 53.55))',32652),'Амур','Джалинда,Покровка');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (3,GeomFromText('POLYGON((125.50 53.07,125.50 53.06,125.59 53.06,125.49 53.07,125.50 53.07))',32652),'Амур','Черняево,Джалинда');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (4,GeomFromText('POLYGON((126.5949 51.7973,126.6089 51.8041,126.6199 51.7871,126.6055 51.7787,126.5949 51.7973))',32652),'Амур','Кумара');

insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (5,GeomFromText('POLYGON((127.2965 50.4989,127.3082 50.4935,127.2913 50.4721,127.2802 50.4830,127.2965 50.4989))',32652),'Амур','Благовещенск');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (6,GeomFromText('POLYGON((127.34 50.45,127.35 50.45,127.37 50.43,127.36 50.43,127.34 50.45))',32652),'Амур','Благовещенск');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (7,GeomFromText('POLYGON((127.53 50.255,127.56 50.25,127.56 50.245,127.53 50.245,127.53 50.255))',32652),'Амур','Благовещенск');

insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (8,GeomFromText('POLYGON((127.62 50.32,127.64 50.32,127.63 50.32,127.61 50.31,127.62 50.32))',32652),'Зея','Благовещенск');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (9,GeomFromText('POLYGON((127.58 50.29,127.59 50.28,127.57 50.28,127.57 50.29,127.58 50.29))',32652),'Зея','Благовещенск');

insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (10,GeomFromText('POLYGON((127.58 50.25,127.59 50.24,127.62 50.22,127.61 50.22,127.58 50.25))',32652),'Амур','Благовещенск,Гродеково');

insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (11,GeomFromText('POLYGON((128.3438 49.5737,128.3609 49.5843,128.3818 49.5543,128.3558 49.5426,128.3438 49.5737))',32652),'Амур','Поярково,Константиновка');

insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (12,GeomFromText('POLYGON((129.3311 49.3584,129.3760 49.3876,129.3812 49.3567,129.3293 49.3464,129.3311 49.3584))',32652),'Амур','Пашково,Поярково');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (14,GeomFromText('POLYGON((129.44 49.44,129.45 49.44,129.45 49.43,129.43 49.44,129.44 49.44))',32652),'Амур','Пашково,Поярково');

insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (15,GeomFromText('POLYGON((130.73 48.02,130.74 48.03,130.75 48.00,130.74 48.00,130.73 48.02))',32652),'Амур','Поярково, Екат-Ник.');

insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (16,GeomFromText('POLYGON((132.86 48.00,132.89 48.02,132.90 48.00,132.87 47.99,132.86 48.00))',32652),'Амур','Ленинское');


insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (17,GeomFromText('POLYGON((133.7278 48.1780,133.7791 48.2135,133.7911 48.1996,133.7383 48.1569,133.7278 48.1780))',32652),'Амур','Ленинское,Хабаровск');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (18,GeomFromText('POLYGON((133.7278 48.1780,133.8482 48.2879,133.9020 48.2984,133.7383 48.1569,133.7278 48.1780))',32652),'Амур','Ленинское,Хабаровск');

insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (19,GeomFromText('POLYGON((135.0242 48.6571,135.0430 48.6635,135.0782 48.6264,135.0524 48.6180,135.0242 48.6571))',32652),'Амур','Хабаровск');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (20,GeomFromText('POLYGON((135.0435 48.6336,135.6677 48.6427,135.0782 48.6264,135.0524 48.6180,135.0435 48.6336))',32652),'Амур','Хабаровск');


insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (21,GeomFromText('POLYGON((136.8212 49.5825,136.8399 49.6271,136.8728 49.5948,136.8541 49.5580,136.8212 49.5825))',32652),'Амур','Троицкое,Иннокентьевка');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (22,GeomFromText('POLYGON((136.7475 49.5954,136.8179 49.6762,136.9077 49.5922,136.8347 49.5237,136.7475 49.5954))',32652),'Амур','Троицкое,Иннокентьевка');

insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (24,GeomFromText('POLYGON((138.1262 50.8884,138.1599 50.9290,138.1730 50.8939,138.1351 50.8642,138.1262 50.8884))',32652),'Амур','Комсомольск,Мариинск');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (26,GeomFromText('POLYGON((139.8061 53.1791,139.9148 53.2555,139.9280 53.2107,139.8245 53.1344,139.8061 53.1791))',32652),'Амур','Николаевск');


insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (27,GeomFromText('POLYGON((65.70 66.16,65.81 66.16,65.81 66.12,65.65 66.12,65.70 66.16))',32652),'Обь','Салехард');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (28,GeomFromText('POLYGON((65.70 66.15,65.73 66.15,65.72 66.13,65.67 66.13,65.70 66.15))',32652),'Обь','Салехард(low part)');

insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (30,GeomFromText('POLYGON((127.53 50.255,127.56 50.25,127.56 50.245,127.53 50.245,127.53 50.255),
								(127.58 50.25,127.59 50.24,127.62 50.22,127.61 50.22,127.58 50.25))',32652),'Амур','Благовещенск');
insert into river_regions (reg_numb,reg_coord,riv_name,sity) values (31,GeomFromText('POLYGON((127.62 50.32,127.64 50.32,127.63 50.32,127.61 50.31,127.62 50.32),
								(127.58 50.29,127.59 50.28,127.57 50.28,127.57 50.29,127.58 50.29))',32652),'Зея','Благовещенск');
