This builds off of

https://willschenk.com/howto/2024/making_a_json_api_from_a_csv_file_using_fly/

It uses Puppeteer to download a csv from

https://afdc.energy.gov/fuels/electricity_locations.html#/analyze?fuel=ELEC

and then turns it into a sqlite3 database and then serves it up.