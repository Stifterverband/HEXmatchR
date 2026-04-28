## HEXmatch <a href="http://srv-data01:30080/hex/hexmatch"><img src="assets/hex_match_logo.png" align="right" height="200" style="float:right; height:200px;" alt="HEXmatch website" /></a>

## Installation

`HEXmatch` kann folgendermaßen installiert werde:

```r
remotes::install_git("http://srv-data01:30080/hex/hex-gerit/hexmatch")
```

## Was macht HEXmatch?

HEXmatch spielt über die Variable `Organisation` GERIT-Daten an den HEX. Diese erlauben es wiederum, HEX-Daten mit DESTATIS-Daten (z.B. Personal und Studierendenzahlen) anzureichern.

## Wie funktioniert HEXmatch

## In an Nutshell

todo!

![hex_match_short](assets/hex_match_short.png)

## Detaillierter Ablauf

todo!

![hex_match_detail](assets/hex_match_detail.png)

## Dependencies

Damit HEXmatch funktioniert, bedarf es einerseits der Daten von [GERIT](https://www.gerit.org/de/) als auch der von [DESTATIS](https://erhebungsportal.estatistik.de/Erhebungsportal/informationen/statistik-des-hochschulpersonals-670).

Die GERIT Daten werden derzeit [gescrapet](http://srv-data01:30080/hex/hex-gerit/hex-scraping-gerit), die DESTATIS-Daten werden einfach geladen (siehe link oben). Das Scraping wird zeitnah in das Paket überführt.

Die GERIT- und die DESTATIS-Daten werden durch `merge_gerit_with_DESTATIS_system.R` zusammengeführt. Dies geschieht folgendermaßen:

![GERIT DESTATIS Match](assets/gerit_destatis_match.png)