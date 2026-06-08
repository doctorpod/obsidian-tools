# Retire Datview

- structure changes for log hist, log summ, year summ
    - path
    - date
    - text
- structure for daily
    - path
    - text

- for each log file in date and time order
    - get date, headline, synopsis
    - find corresponding daily or create
    - for each outlinked file
        - if log history append to changes file, date, shortened synopsis linked to daily
        - if log summary ???
        - if year summary append to changes file, date, headline linked to daily
    - append changes daily, synopsis + body
    - delete log file

- for each row in changes
    - replace dataview block with formatted change