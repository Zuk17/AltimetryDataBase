drop table contact_data;
CREATE TABLE contact_data
(
  "object" char(15) NOT NULL,
  view_point char(30) NOT NULL,
  indeks float4 NOT NULL,
  data date,
  "level" float4
) 
WITHOUT OIDS;
ALTER TABLE contact_data OWNER TO postgres;



COPY contact_data ("object",view_point,indeks,data,"level") from 'D:\\contact.txt' using delimiters '\t';
delete from contact_data where "level" IS NULL