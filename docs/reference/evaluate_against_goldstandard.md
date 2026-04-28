# Matching-Ergebnisse mit einem Goldstandard vergleichen

Diese Funktion prüft, ob die im Matching vorhergesagten `LUF_IDs` aus
den gematchten GERIT-Einrichtungen mit dem Goldstandard aus
`gold_data$luf_code` übereinstimmen.

## Usage

``` r
evaluate_against_goldstandard(
  organisation_matches,
  gold_data,
  organisation_col = "organisation"
)
```

## Arguments

- organisation_matches:

  Eine Match-Tabelle auf Ebene der gescrapten `organisation`, zum
  Beispiel die Ausgabe von
  [`match_scraped_organisations()`](https://github.com/Stifterverband/HEXmatchR/reference/match_scraped_organisations.md).
  Erwartet werden die aus GERIT übernommenen Spalten
  `gerit_organisation`, `Faechergruppen` und `LUF_IDs`.

- gold_data:

  Ein Data Frame oder ein Pfad zu einer `.rds`-Datei mit den manuellen
  Referenzdaten. Erwartet werden eine Organisationsspalte,
  `matchingart`, `luf_code` und `faechergruppe`. Groß-/Kleinschreibung
  der Spaltennamen ist egal.

- organisation_col:

  Name der Organisationsspalte in `gold_data`.

## Value

Eine Liste mit drei Elementen:

- `comparison`:

  Vergleichstabelle mit Vorhersage, Goldstandard und
  Korrektheitsindikatoren pro Organisation.

- `metrics`:

  Tibble mit den wichtigsten Gesamtmetriken. Enthält die Spalten
  `metric` und `value`. `value` ist jeweils wie folgt berechnet:
  `n_organisations = nrow(comparison)`;
  `n_with_gold_luf = sum(has_gold_luf)`;
  `match_rate = mean(matched == "yes")`;
  `review_rate = mean(needs_review)`;
  `luf_accuracy = mean(luf_correct[has_gold_luf])`.

- `by_gold_matchingart`:

  Zusammenfassung der Metriken getrennt nach `matchingart` aus dem
  Goldstandard. Für jede Gruppe werden `n`, `match_rate`, `review_rate`
  und `luf_accuracy` mit derselben Logik wie oben innerhalb der
  jeweiligen Teilmenge berechnet.

## Details

Dafür werden die gematchten GERIT-Einrichtungen über `organisation` mit
dem Goldstandard verknüpft und drei Ergebnisse zurückgegeben:

- eine Vergleichstabelle auf Zeilenebene

- einige Gesamtmetriken

- eine Auswertung nach `matchingart` aus dem Goldstandard

Die zurückgegebenen Gesamtmetriken sind:

- `n_organisations`: Anzahl der Organisationen in `organisation_matches`

- `n_with_gold_luf`: Anzahl der Organisationen, für die im Goldstandard
  ein `luf_code` vorliegt

- `match_rate`: Anteil der Organisationen mit `matched == "yes"`

- `review_rate`: Anteil der Organisationen mit `needs_review == TRUE`

- `luf_accuracy`: Anteil der Organisationen, bei denen die
  vorhergesagten `LUF_IDs` exakt mit dem Goldstandard-Wert in `luf_code`
  übereinstimmen. Die Reihenfolge der Codes wird dabei ignoriert,
  sodass z. B. `231|771` und `771|231` als identisch gelten. Diese
  Metrik wird nur für Organisationen berechnet, für die im Goldstandard
  überhaupt ein Vergleichswert vorliegt.
