CREATE OR REPLACE FUNCTION __calcall() RETURNS void AS $$
BEGIN
	delete from points_in_regions_10hz;
	insert into points_in_regions_10hz select id_sat,reg_numb,(alt-(iono_dor+dry_cor)-h_sat),lon,lat,date_time,id_cycle,id_track,alt_point 
							from alt_data_10hz, river_regions where alt_point && reg_coord;
	delete from points_in_regions_1hz;
	insert into points_in_regions_1hz select id_sat,reg_numb,(alt-(iono_dor+dry_cor)-h_sat),lon,lat,date_time,id_cycle,id_track,alt_point 
							from alt_data_1hz, river_regions where alt_point && reg_coord;

	delete from points_in_regions_10hz where date_part('month',date_time)<=4 or
						 date_part('month',date_time)>=10;

	delete from points_in_regions_1hz where date_part('month',date_time)<=4 or
						date_part('month',date_time)>=10;

	/* Ограничения на значение альтиметрии по manual of TOPEX/POSEIDON */
	EXECUTE 'delete from points_in_regions_10hz where  alt>500000 or alt<-500000';
	EXECUTE 'delete from points_in_regions_1hz where  alt>500000 or alt<-500000';

	PERFORM __calc();

	RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION __calc() RETURNS void AS $$
BEGIN
	delete from average_data;
	PERFORM __calc_average();
	delete from average_data where alt IS NULL or date_time IS NULL;

	PERFORM __filtering();

	RETURN;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __median(int4,int4,int4) RETURNS float4 AS $$
DECLARE
	numb_t int4;
	result float4;
BEGIN
	result:=0;
	select into numb_t COUNT(*) from points_in_regions_10hz where reg_numb=$1 and id_cycle=$2 and id_track=$3;
	select into result AVG(alt) from points_in_regions_10hz where reg_numb=$1 and id_cycle=$2 and id_track=$3 group by alt order by alt limit 2 offset int4(numb_t/2);
	RETURN result;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __calc_average() RETURNS void AS $$
DECLARE
	reg_n RECORD;
	sat_n RECORD;
	id_c RECORD;
	id_tr RECORD;
	variance_t float4;
	avg_t float4;
	lon_t float4;
	lat_t float4;
BEGIN
	FOR reg_n IN select reg_numb from river_regions order by reg_numb LOOP
	    BEGIN
	    select into lon_t AVG(lon) from points_in_regions_10hz where reg_numb=reg_n.reg_numb;
	    select into lat_t AVG(lat) from points_in_regions_10hz where reg_numb=reg_n.reg_numb;

	    FOR sat_n IN select id_sat from points_in_regions_10hz group by id_sat order by id_sat LOOP
		BEGIN
		FOR id_c IN select id_cycle from points_in_regions_10hz group by id_cycle order by id_cycle LOOP
		   BEGIN
		   FOR id_tr IN select id_track from points_in_regions_10hz group by id_track order by id_track LOOP
			select into variance_t sqrt(VARIANCE(alt)) from points_in_regions_10hz where id_sat=sat_n.id_sat and reg_numb=reg_n.reg_numb and id_cycle=id_c.id_cycle and id_track=id_tr.id_track;
			select into avg_t AVG(alt) from points_in_regions_10hz where id_sat=sat_n.id_sat and reg_numb=reg_n.reg_numb and id_cycle=id_c.id_cycle and id_track=id_tr.id_track;
			IF variance_t>0 THEN
				EXECUTE 'delete from points_in_regions_10hz where id_sat='''
					||sat_n.id_sat 
					||''' and reg_numb='
					||reg_n.reg_numb 
					||' and id_cycle='
					||id_c.id_cycle
					||' and id_track='
					||id_tr.id_track
					||' and abs(alt+' 
					||avg_t
					||'*(-1))>' || variance_t;
			END IF;
			IF (variance_t IS NULL) THEN variance_t=0;END IF;
			select into avg_t AVG(alt) from points_in_regions_10hz where id_sat=sat_n.id_sat and reg_numb=reg_n.reg_numb and id_cycle=id_c.id_cycle and id_track=id_tr.id_track;

			IF (lon_t IS NOT NULL) AND (lat_t IS NOT NULL) AND (avg_t IS NOT NULL) THEN
			EXECUTE 'insert into average_data values ('''
				|| sat_n.id_sat
				||''',' || reg_n.reg_numb
				||',' || avg_t
				||',(select __median('||reg_n.reg_numb||','||id_c.id_cycle||','||id_tr.id_track||')),'
				|| lon_t || ',' || lat_t
				||',(select MIN(date_time) from points_in_regions_10hz where reg_numb='
				|| reg_n.reg_numb
				||' and id_cycle='
				|| id_c.id_cycle
				||' and id_track='
				|| id_tr.id_track
				||'),'||id_c.id_cycle
				||',' || id_tr.id_track
				||',(select AVG(alt) from points_in_regions_1hz where reg_numb='
				|| reg_n.reg_numb
				||' and id_cycle='
				|| id_c.id_cycle
				||' and id_track='
				|| id_tr.id_track
				||'),'|| variance_t
				||',GeomFromText(''POINT ('
				|| lon_t ||' '||lat_t
				||')'',-1))';
  			END IF;
		  END LOOP;
		  END;
	      END LOOP;
	      END;
	  END LOOP;
		
		select into variance_t sqrt(VARIANCE(alt)) from average_data where reg_numb=reg_n.reg_numb;
		select into avg_t AVG(alt) from average_data where reg_numb=reg_n.reg_numb;
		IF variance_t Is NULL THEN variance_t=0; END IF;
		IF avg_t Is NULL THEN avg_t=0; END IF;
		EXECUTE 'UPDATE river_regions SET sigma='
			|| variance_t
			|| ' where reg_numb='
			|| reg_n.reg_numb;
		EXECUTE 'UPDATE river_regions SET avg='
			|| avg_t
			|| ' where reg_numb='
			|| reg_n.reg_numb;
	END;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __filtering() RETURNS void AS $$
DECLARE
	reg_n RECORD;
	year_t RECORD;
	time_t RECORD;
	count_t int8;

	avg_t float4;
	variance_t float4;

	i int8;
	k int8;
BEGIN
	CREATE TABLE a_tmp_table_1 AS select * from average_data;

	delete from filter_data;
	FOR reg_n IN select reg_numb from river_regions order by reg_numb LOOP
	BEGIN
		select into variance_t sqrt(VARIANCE(alt)) from a_tmp_table_1 where reg_numb=reg_n.reg_numb;
		FOR year_t IN select date_part('year',date_time) as year from a_tmp_table_1 group by date_part('year',date_time) order by date_part('year',date_time) LOOP
		BEGIN
			select into count_t count(*) from a_tmp_table_1 where reg_numb=reg_n.reg_numb and date_part('year',date_time)=year_t.year;
			i=0;
			FOR time_t IN select id_sat,reg_numb,alt,alt_m,date_time from a_tmp_table_1 where reg_numb=reg_n.reg_numb and date_part('year',date_time)=year_t.year LOOP
				IF (i>1) AND (i<count_t-3) THEN 
					k=i-2;
					select into avg_t avg(alt) from (select alt from a_tmp_table_1 where reg_numb=reg_n.reg_numb and date_part('year',date_time)=year_t.year order by date_time limit 5 offset k) as tmp_query1;
				ELSE
					select into avg_t avg(alt) from a_tmp_table_1 where reg_numb=reg_n.reg_numb and date_part('year',date_time)=year_t.year;
				END IF;

				IF (abs(time_t.alt-avg_t)>variance_t/1.3) THEN
				EXECUTE 'DELETE from a_tmp_table_1 where reg_numb='
					|| time_t.reg_numb
					||' AND date_time=(CAST (\''|| time_t.date_time
					||'\' as timestamp))';
				END IF;
			i=i+1;
			END LOOP;
		END;
		END LOOP;
		select into avg_t avg(alt) from a_tmp_table_1 where reg_numb=reg_n.reg_numb;
		EXECUTE 'UPDATE river_regions SET avg='
			|| avg_t
			|| ' where reg_numb='
			|| reg_n.reg_numb;

	END;
	END LOOP;
	FOR reg_n IN select reg_numb from river_regions order by reg_numb LOOP
	BEGIN

		FOR year_t IN select date_part('year',date_time) as year from a_tmp_table_1 group by date_part('year',date_time) order by date_part('year',date_time) LOOP
		BEGIN

		   select into count_t count(*) from a_tmp_table_1 where reg_numb=reg_n.reg_numb and date_part('year',date_time)=year_t.year;
			
		   i=0;
		   FOR time_t IN select id_sat,reg_numb,alt,alt_m,lon,lat,date_time,id_cycle,id_track from a_tmp_table_1 where reg_numb=reg_n.reg_numb and date_part('year',date_time)=year_t.year LOOP
			IF (i>1) AND (i<=count_t-3) THEN k=i-2;
			ELSEIF (i<=1) THEN k=i;
			ELSEIF (i>=count_t-2) THEN k=i-4;
			END IF;
			EXECUTE 'insert into filter_data values ('''
				|| time_t.id_sat
				||''','|| time_t.reg_numb 
				||','||'(select avg(alt) from (select alt from a_tmp_table_1 where reg_numb='||reg_n.reg_numb||' and date_part(\'year\',date_time)='||year_t.year||' order by date_time limit 5 offset '||k||' ) as tmp_query)'
				||','||'(select avg(alt_m) from (select alt_m from a_tmp_table_1 where reg_numb='||reg_n.reg_numb||' and date_part(\'year\',date_time)='||year_t.year||' order by date_time limit 5 offset '||k||' ) as tmp_query)'
				||','|| time_t.lon 
				||','|| time_t.lat
				||', (CAST (\''|| time_t.date_time
				||'\' as timestamp)),'|| time_t.id_cycle
				||','|| time_t.id_track
				||',GeomFromText(''POINT ('
				|| time_t.lon ||' '||time_t.lat
				||')'',-1))';
			i=i+1;
		   END LOOP;
		END;
		END LOOP;
	END;
	END LOOP;
	DROP table a_tmp_table_1;
	RETURN;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __export() RETURNS void AS $$
BEGIN

/*0 Покровка*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=0 AND contact_data.indeks=6001;
COPY a_tmp_table TO '/mnt/Export/00.txt';
DROP TABLE a_tmp_table;

/*1 Джалинда Покровка*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=1 AND contact_data.indeks=6001;
COPY a_tmp_table TO '/mnt/Export/01 Pokrovka.txt';
DROP TABLE a_tmp_table;
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=1 AND contact_data.indeks=6005;
COPY a_tmp_table TO '/mnt/Export/01 Dzhalinda.txt';
DROP TABLE a_tmp_table;

/*2 Джалинда Покровка*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=2 AND contact_data.indeks=6001;
COPY a_tmp_table TO '/mnt/Export/02 Pokrovka.txt';
DROP TABLE a_tmp_table;
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=2 AND contact_data.indeks=6005;
COPY a_tmp_table TO '/mnt/Export/02 Dzhalinda.txt';
DROP TABLE a_tmp_table;

/*3 Черняево Джалинда*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=3 AND contact_data.indeks=6010;
COPY a_tmp_table TO '/mnt/Export/03 chernyaevo.txt';
DROP TABLE a_tmp_table;
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=3 AND contact_data.indeks=6005;
COPY a_tmp_table TO '/mnt/Export/03 Dzhalinda.txt';
DROP TABLE a_tmp_table;

/*4 Кумара*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=4 AND contact_data.indeks=6016;
COPY a_tmp_table TO '/mnt/Export/04.txt';
DROP TABLE a_tmp_table;

/*5 Благовещенск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=5 AND contact_data.indeks=6022;
COPY a_tmp_table TO '/mnt/Export/05.txt';
DROP TABLE a_tmp_table;

/*6 Благовещенск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=6 AND contact_data.indeks=6022;
COPY a_tmp_table TO '/mnt/Export/06.txt';
DROP TABLE a_tmp_table;

/*7 Благовещенск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=7 AND contact_data.indeks=6022;
COPY a_tmp_table TO '/mnt/Export/07.txt';
DROP TABLE a_tmp_table;

/*8 Благовещенск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=8 AND contact_data.indeks=6022;
COPY a_tmp_table TO '/mnt/Export/08 Zeya.txt';
DROP TABLE a_tmp_table;

/*9 Благовещенск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=9 AND contact_data.indeks=6022;
COPY a_tmp_table TO '/mnt/Export/09 Zeya.txt';
DROP TABLE a_tmp_table;

/*10 Благовещенск Гродеково*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=10 AND contact_data.indeks=6022;
COPY a_tmp_table TO '/mnt/Export/10 blagovew.txt';
DROP TABLE a_tmp_table;
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=10 AND contact_data.indeks=6023;
COPY a_tmp_table TO '/mnt/Export/10 grodekovo.txt';
DROP TABLE a_tmp_table;

/*11 Поярково Константиновка*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=11 AND contact_data.indeks=6024;
COPY a_tmp_table TO '/mnt/Export/11 konstantinovka.txt';
DROP TABLE a_tmp_table;
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=11 AND contact_data.indeks=6026;
COPY a_tmp_table TO '/mnt/Export/11 poyarkovo.txt';
DROP TABLE a_tmp_table;

/*12 Пашково Поярково*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=12 AND contact_data.indeks=6030;
COPY a_tmp_table TO '/mnt/Export/12 pawkovo.txt';
DROP TABLE a_tmp_table;
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=12 AND contact_data.indeks=6026;
COPY a_tmp_table TO '/mnt/Export/12 poyarkovo.txt';
DROP TABLE a_tmp_table;

/*14 Пашково Поярково*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=14 AND contact_data.indeks=6030;
COPY a_tmp_table TO '/mnt/Export/14 pawkovo.txt';
DROP TABLE a_tmp_table;
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=14 AND contact_data.indeks=6026;
COPY a_tmp_table TO '/mnt/Export/14 poyarkovo.txt';
DROP TABLE a_tmp_table;

/*15 Пашково Екат-Ник*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=15 AND contact_data.indeks=6030;
COPY a_tmp_table TO '/mnt/Export/15 pawkovo.txt';
DROP TABLE a_tmp_table;
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=15 AND contact_data.indeks=5001;
COPY a_tmp_table TO '/mnt/Export/15 ekatNik.txt';
DROP TABLE a_tmp_table;

/*16 Ленинское*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=16 AND contact_data.indeks=5004;
COPY a_tmp_table TO '/mnt/Export/16 leninskoe.txt';
DROP TABLE a_tmp_table;

/*17 Ленинское Хабаровск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=17 AND contact_data.indeks=5004;
COPY a_tmp_table TO '/mnt/Export/17 leninskoe.txt';
DROP TABLE a_tmp_table;
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=17 AND contact_data.indeks=5012;
COPY a_tmp_table TO '/mnt/Export/17 xabarovsk.txt';
DROP TABLE a_tmp_table;

/*18 Ленинское Хабаровск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=18 AND contact_data.indeks=5004;
COPY a_tmp_table TO '/mnt/Export/18 leninskoe.txt';
DROP TABLE a_tmp_table;
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=18 AND contact_data.indeks=5012;
COPY a_tmp_table TO '/mnt/Export/18 xabarovsk.txt';
DROP TABLE a_tmp_table;

/*19 Хабаровск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=19 AND contact_data.indeks=5012;
COPY a_tmp_table TO '/mnt/Export/19 xabarovsk.txt';
DROP TABLE a_tmp_table;

/*20 Хабаровск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=20 AND contact_data.indeks=5012;
COPY a_tmp_table TO '/mnt/Export/20 xabarovsk.txt';
DROP TABLE a_tmp_table;

/*21 Троицкое Иннокентьевка*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=21 AND contact_data.indeks=5019;
COPY a_tmp_table TO '/mnt/Export/21 troiskoe.txt';
DROP TABLE a_tmp_table;
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=21 AND contact_data.indeks=6027;
COPY a_tmp_table TO '/mnt/Export/21 innkent.txt';
DROP TABLE a_tmp_table;

/*22 Троицкое Иннокентьевка*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=22 AND contact_data.indeks=5019;
COPY a_tmp_table TO '/mnt/Export/22 troiskoe.txt';
DROP TABLE a_tmp_table;
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=22 AND contact_data.indeks=6027;
COPY a_tmp_table TO '/mnt/Export/22 innkent.txt';
DROP TABLE a_tmp_table;

/*24 Комсомольск Мариинск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=24 AND contact_data.indeks=5024;
COPY a_tmp_table TO '/mnt/Export/24 komsomolsk.txt';
DROP TABLE a_tmp_table;
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=24 AND contact_data.indeks=5031;
COPY a_tmp_table TO '/mnt/Export/24 mariinsk.txt';
DROP TABLE a_tmp_table;

/*25 Мариинск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=25 AND contact_data.indeks=5031;
COPY a_tmp_table TO '/mnt/Export/25 mariinsk.txt';
DROP TABLE a_tmp_table;

/*26 Николаевск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=26 AND contact_data.indeks=5805;
COPY a_tmp_table TO '/mnt/Export/26 nikolaevsk.txt';
DROP TABLE a_tmp_table;

/*27 Салехард*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=27 AND contact_data.indeks=11801;
COPY a_tmp_table TO '/mnt/Export/27 salexard.txt';
DROP TABLE a_tmp_table;

/*28 Салехард*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=28 AND contact_data.indeks=11801;
COPY a_tmp_table TO '/mnt/Export/28 salexard.txt';
DROP TABLE a_tmp_table;

/*30 Благовещенск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=30 AND contact_data.indeks=6022 ; 
COPY a_tmp_table TO '/mnt/Export/30 Amur.txt';
DROP TABLE a_tmp_table;

/*31 Благовещенск*/
CREATE TEMP TABLE a_tmp_table AS
	select date(average_data.date_time) as date, int4(average_data.alt) as alt, int4(average_data.alt_1hz) as alt_1hz, int4(filter_data.alt) as alt_avg, contact_data.level as contact
                            from average_data,contact_data,filter_data
                                 where date(average_data.date_time)=contact_data.data
				 AND date(filter_data.date_time)=contact_data.data AND date(average_data.date_time)=date(filter_data.date_time)  AND filter_data.reg_numb=average_data.reg_numb
                                 AND average_data.reg_numb=31 AND contact_data.indeks=6022;
COPY a_tmp_table TO '/mnt/Export/31 Zeya.txt';
DROP TABLE a_tmp_table;

END
$$ LANGUAGE plpgsql;
