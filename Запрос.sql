select date(average_data.date_time) as date, int4(average_data.alt-13000), int4(average_data.alt_1hz-13000), contact_data.level
                            from average_data,contact_data
                                 where date(average_data.date_time)=contact_data.data
                                 AND average_data.reg_numb=30 AND contact_data.indeks=6022