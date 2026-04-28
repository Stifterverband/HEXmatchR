# Shiny-Review-App starten

Startet eine interaktive Shiny-Anwendung, die jeden Review-Fall einzeln
präsentiert. Der Reviewer kann einen GERIT-Kandidaten wählen, den Fall
als kein Match markieren oder überspringen. Die App schließt sich, wenn
der Reviewer auf "Fertig" klickt, und gibt die ausgefüllte
Entscheidungstabelle zurück. Benötigt die Pakete `shiny` und `DT`.

## Usage

``` r
run_review_app(review_cases, df_gerit, reviewed_by = current_username())
```

## Arguments

- review_cases:

  Ausgabe von
  [`prepare_review_cases()`](https://github.com/Stifterverband/HEXmatchR/reference/prepare_review_cases.md).

- df_gerit:

  Vorbereitete GERIT-Daten aus
  [`prepare_gerit_data()`](https://github.com/Stifterverband/HEXmatchR/reference/prepare_gerit_data.md).

- reviewed_by:

  Optionaler Reviewer-Name, der in der Spalte `reviewed_by` der
  zurückgegebenen Entscheidungstabelle gespeichert wird.

## Value

Eine Liste mit dem Element `decisions`: ein Tibble mit je einer Zeile
pro reviewtem Fall und den Spalten `scraped_ID`, `organisation`,
`review_decision`, `selected_gerit_id`, `review_comment`, `reviewed_at`
und `reviewed_by`.
