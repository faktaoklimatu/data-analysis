# Test převodu JSON-stat na tabulku na uložené odpovědi API Eurostatu (nama_10_a64, 2 obory × 2 země × 2 roky)
options(fok.no_download = TRUE)  # jen načíst funkce, nestahovat
source("R/01_download_eurostat.R")
d <- parse_jsonstat(jsonlite::fromJSON("tests/fixtures/sample_nama_10_a64.json", simplifyVector = FALSE))
exp <- c(CZ_C20_2015 = 1484.3, SK_C20_2016 = 401.3, CZ_C24_2016 = 1454.8, SK_C24_2015 = 863.7)
got <- with(d, setNames(values, paste(geo, nace_r2, time, sep = "_")))[names(exp)]
stopifnot(isTRUE(all.equal(unname(got), unname(exp))))
cat("parse_jsonstat: OK (", nrow(d), "hodnot )\n")
