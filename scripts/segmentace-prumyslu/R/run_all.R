# Spustí celý výpočet: stažení dat -> registr -> náklady ETS -> … -> HPH, PEFA, SUT (ČSÚ), FIGARO
# Data Eurostatu se stahují jen tehdy, když ve složce data/eurostat chybí.
# Celý výpis včetně chyb se ukládá do out/run_log.txt (Claude ho čte při ladění).
# Skript se musí spouštět ze složky R_ETS (tam, kde je podsložka R/)
if (!file.exists("R/00_setup.R")) {
  stop("Pracovní složka není R_ETS (je: ", getwd(), "). V Positronu otevřete složku R_ETS ",
       "(File → Open Folder) nebo nastavte setwd() na cestu k R_ETS a spusťte znovu.", call. = FALSE)
}
# skripty jsou v UTF-8; v prostředí s locale "C" by se čeština nenačetla
invisible(Sys.setlocale("LC_CTYPE", "en_US.UTF-8"))
dir.create("out", showWarnings = FALSE)
log_file <- "out/run_log.txt"
con <- file(log_file, open = "wt", encoding = "UTF-8")
sink(con, split = TRUE); sink(con, type = "message")
cat("=== run_all.R", format(Sys.time()), "===\n")
cat("Pracovní složka:", getwd(), "\n")
ok <- TRUE
step <- function(f) {
  cat("\n== ", f, " ==\n", sep = "")
  tryCatch(withCallingHandlers(source(f, encoding = "UTF-8", echo = FALSE),
                               warning = function(w) cat("VAROVÁNÍ:", conditionMessage(w), "\n")),
           error = function(e) { cat("CHYBA v", f, ":", conditionMessage(e), "\n"); ok <<- FALSE })
}
step("R/00_setup.R")
if (!ok) { sink(type = "message"); sink(); close(con)
  stop("Nepodařilo se načíst R/00_setup.R – viz out/run_log.txt", call. = FALSE) }
if (!file.exists(file.path(DIR_ES, "sbs_ovw_act.csv"))) step("R/01_download_eurostat.R")
for (f in c("R/02_registry.R", "R/03_ets_costs.R", "R/08_production_annual.R", "R/11_hph_zamestnanost.R",
            "R/12_energie_pefa.R", "R/13_sut_csu.R", "R/14_figaro.R", "R/15_export_web.R")) if (ok) step(f)
cat("\n=== Stav:", if (ok) "HOTOVO" else "SKONČILO CHYBOU", "===\n")
cat("\nSoubory v data/eurostat:\n"); print(list.files(DIR_ES))
cat("\n"); print(sessionInfo())
sink(type = "message"); sink(); close(con)
message(if (ok) "Hotovo. Výpis: out/run_log.txt" else "Chyba – výpis v out/run_log.txt")
