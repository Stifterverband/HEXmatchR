# Manuelles Helfer-Skript fuer die Paketentwicklung.
# Nicht per source() komplett durchlaufen, sondern die passenden Bloecke
# markieren und ausfuehren.

# Einmalig installieren, falls devtools fehlt:
# install.packages("devtools")
# install.packages("usethis")

# Version aktualisieren:
# - patch: kleine Bugfixes oder Doku-Aenderungen, z. B. 0.5.3 -> 0.5.4
# - minor: neue Funktionen ohne harte Brueche, z. B. 0.5.3 -> 0.6.0
# - major: groessere/brechende Aenderungen, z. B. 0.5.3 -> 1.0.0
usethis::use_version("patch")
# usethis::use_version("minor")
# usethis::use_version("major")

# Paket im aktuellen Arbeitsstand laden.
devtools::load_all()
devtools::install()

# Roxygen-Dokumentation aktualisieren:
# - erzeugt/aktualisiert man/*.Rd
# - aktualisiert NAMESPACE
devtools::document()

# Schneller lokaler Check ohne erneutes Dokumentieren und ohne Vignetten/Manual.
# Vorher devtools::document() ausfuehren, wenn Roxygen-Kommentare geaendert wurden.
devtools::check()
pkgdown::build_site()
# # Source-Package bauen.
# # Ergebnis ist z. B. HEXmatch_0.5.3.tar.gz im Projektordner.
# devtools::build()

# # Paket lokal installieren.
# devtools::install()

# # Optional: temporaere Check-/Build-Artefakte aufraeumen.
# unlink("HEXmatch.Rcheck", recursive = TRUE, force = TRUE)
# unlink(list.files(pattern = "^HEXmatch_.*[.]tar[.]gz$"), force = TRUE)
